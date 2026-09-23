#!/usr/bin/python3
"""Persistent stereo preamp/EQ, independent of measured speaker correction."""
import contextlib
import fcntl
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config')))
SETTINGS = ROOT / 'omarchy/settings-audio-effects.json'
CONFIG = ROOT / 'pipewire/settings-audio-effects.conf'
UNIT = ROOT / 'systemd/user/settings-audio-effects.service'
SINK = 'settings_audio_effects'
FREQUENCIES = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000]
LIMITER = Path('/usr/lib/lv2/lsp-plugins.lv2/limiter_stereo.ttl')


def run(*args, check=True):
    return subprocess.run(args, text=True, capture_output=True, check=check, timeout=15)


def read_settings():
    data = {'preampDb': 0, 'gains': [0] * 9, 'enabled': True, 'target': ''}
    if SETTINGS.exists():
        data.update(json.loads(SETTINGS.read_text()))
    validate(data)
    return data


def validate(data):
    def number(value, low, high):
        return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and low <= value <= high
    if not number(data['preampDb'], -24, 36):
        raise ValueError('Preamp must be between -24 and +36 dB')
    if not isinstance(data['gains'], list) or len(data['gains']) != 9 or not all(number(v, -12, 12) for v in data['gains']):
        raise ValueError('Nine EQ gains between -12 and +12 dB are required')
    if type(data['enabled']) is not bool or not isinstance(data['target'], str) or data['target'] == SINK:
        raise ValueError('Invalid audio effects configuration')


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix=path.name + '.')
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(text)
        os.replace(name, path)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(name)


def controls(data):
    values = {}
    for side in ('l', 'r'):
        values[f'pre_{side}:Mult'] = 10 ** ((data['preampDb'] if data['enabled'] else 0) / 20)
        for i, gain in enumerate(data['gains']):
            values[f'eq{i}_{side}:Gain'] = gain if data['enabled'] else 0
    return values


def graph(data):
    validate(data)
    values = controls(data)
    nodes, links = [], []
    for side in ('l', 'r'):
        previous = f'pre_{side}'
        nodes.append({'type': 'builtin', 'name': previous, 'label': 'linear',
                      'control': {'Mult': values[f'{previous}:Mult'], 'Add': 0}})
        for i, frequency in enumerate(FREQUENCIES):
            name = f'eq{i}_{side}'
            nodes.append({'type': 'builtin', 'name': name, 'label': 'bq_peaking',
                          'control': {'Freq': frequency, 'Q': 1.4, 'Gain': values[f'{name}:Gain']}})
            links.append({'output': f'{previous}:Out', 'input': f'{name}:In'})
            previous = name
        links.append({'output': f'{previous}:Out', 'input': f'limiter:in_{side}'})
    nodes.append({'type': 'lv2', 'name': 'limiter',
                  'plugin': 'http://lsp-plug.in/plugins/lv2/limiter_stereo',
                  'control': {'alr': 0, 'boost': 0, 'g_in': 1, 'th': 0.891}})
    return json.dumps({
        'context.properties': {'log.level': 1},
        'context.spa-libs': {'audio.convert.*': 'audioconvert/libspa-audioconvert', 'support.*': 'support/libspa-support'},
        'context.modules': [
            {'name': 'libpipewire-module-rt', 'flags': ['ifexists', 'nofail']},
            {'name': 'libpipewire-module-protocol-native'},
            {'name': 'libpipewire-module-client-node'},
            {'name': 'libpipewire-module-adapter'},
            {'name': 'libpipewire-module-filter-chain', 'args': {
                'node.description': 'Settings Equalizer', 'media.name': 'Settings Equalizer',
                'audio.channels': 2, 'audio.position': ['FL', 'FR'],
                'filter.graph': {'nodes': nodes, 'links': links,
                                 'inputs': ['pre_l:In', 'pre_r:In'],
                                 'outputs': ['limiter:out_l', 'limiter:out_r']},
                'capture.props': {'node.name': SINK, 'node.description': 'Settings Equalizer',
                                  'media.class': 'Audio/Sink', 'priority.session': 0},
                'playback.props': {'node.name': SINK + '_output', 'node.passive': True,
                                   'target.object': data['target'], 'node.dont-fallback': True,
                                   'node.dont-move': True}
            }}]}, indent=2) + '\n'


def node():
    for item in json.loads(run('pw-dump').stdout):
        if item.get('type') == 'PipeWire:Interface:Node' and item.get('info', {}).get('props', {}).get('node.name') == SINK:
            return item
    return None


def live_controls(item):
    for props in item.get('info', {}).get('params', {}).get('Props', []):
        params = props.get('params', [])
        if 'pre_l:Mult' in params:
            return dict(zip(params[::2], params[1::2]))
    return {}


def apply_live(data, item):
    wanted = controls(data)
    payload = ' '.join(json.dumps(k) + ' ' + str(v) for k, v in wanted.items())
    run('pw-cli', 'set-param', str(item['id']), 'Props', '{ params = [ ' + payload + ' ] }')
    after = live_controls(node() or {})
    if any(k not in after or not math.isclose(after[k], v, rel_tol=0.001, abs_tol=0.001) for k, v in wanted.items()):
        raise RuntimeError('PipeWire did not retain the requested preamp/EQ values')


def select_output(data):
    # Move only ordinary playback from the selected downstream sink. Never move
    # the EQ or calibration output streams into their own processing chain.
    sinks = json.loads(run('pactl', '-f', 'json', 'list', 'sinks').stdout)
    target = next((s['index'] for s in sinks if s['name'] == data['target']), None)
    if target is None:
        raise RuntimeError('The selected output is no longer connected')
    run('pactl', 'set-default-sink', SINK)
    for stream in json.loads(run('pactl', '-f', 'json', 'list', 'sink-inputs').stdout):
        props = stream.get('properties', {})
        name = props.get('node.name', '')
        if stream['sink'] == target and not name.startswith((SINK, 'omarchy_speaker_tuning')) and props.get('media.role') != 'DSP':
            run('pactl', 'move-sink-input', str(stream['index']), SINK)


def apply(data, old, *, route=True):
    if not LIMITER.exists():
        raise RuntimeError('The equalizer requires lsp-plugins-lv2')
    current = run('pactl', 'get-default-sink').stdout.strip()
    if current != SINK:
        data['target'] = current
    if not data['target'] or data['target'] == SINK:
        raise RuntimeError('Select a connected audio output first')
    validate(data)
    item = node()
    previous_config = CONFIG.read_text() if CONFIG.exists() else None
    try:
        atomic_write(CONFIG, graph(data))
        if item and old['target'] == data['target']:
            apply_live(data, item)
        else:
            atomic_write(UNIT, '''[Unit]
Description=Settings preamp and 9-band equalizer
After=pipewire.service wireplumber.service
Requires=pipewire.service
PartOf=pipewire.service

[Service]
ExecStart=/usr/bin/pipewire -c settings-audio-effects.conf
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
''')
            run('systemctl', '--user', 'daemon-reload')
            run('systemctl', '--user', 'enable', 'settings-audio-effects.service')
            run('systemctl', '--user', 'restart', 'settings-audio-effects.service')
            for _ in range(30):
                item = node()
                if item:
                    break
                time.sleep(0.1)
            if not item:
                raise RuntimeError('The equalizer could not start; see its user service log')
            apply_live(data, item)
        if route:
            select_output(data)
        atomic_write(SETTINGS, json.dumps(data, indent=2) + '\n')
    except Exception:
        if previous_config is not None:
            atomic_write(CONFIG, previous_config)
        else:
            CONFIG.unlink(missing_ok=True)
        with contextlib.suppress(Exception):
            if item and old['target'] == data['target']:
                apply_live(old, item)
            else:
                run('systemctl', '--user', 'stop', 'settings-audio-effects.service')
            run('pactl', 'set-default-sink', current if current != SINK else data['target'])
        raise


def state():
    data = read_settings()
    try:
        item = node()
        current = run('pactl', 'get-default-sink').stdout.strip()
        actual = live_controls(item or {})
        expected = controls(data)
        synced = bool(item) and all(k in actual and math.isclose(actual[k], v, abs_tol=0.001, rel_tol=0.001) for k, v in expected.items())
        active = current == SINK and synced
    except (OSError, subprocess.SubprocessError, ValueError):
        active = False
    return dict(data, available=LIMITER.exists(), active=active, frequencies=FREQUENCIES)


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else 'state'
    if action == 'state':
        print(json.dumps(state()))
        return
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    with (SETTINGS.parent / 'settings-audio-effects.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        old = read_settings()
        data = dict(old, gains=list(old['gains']))
        if action == 'preamp':
            data['preampDb'] = float(sys.argv[2])
        elif action == 'eq':
            index = int(sys.argv[2])
            if not 0 <= index < 9:
                raise ValueError('Invalid EQ band')
            data['gains'][index] = float(sys.argv[3])
        elif action == 'enabled':
            if sys.argv[2] not in ('true', 'false'):
                raise ValueError('Expected true or false')
            data['enabled'] = sys.argv[2] == 'true'
        elif action == 'flat':
            data['gains'] = [0] * 9
        elif action == 'reset':
            data['gains'] = [0] * 9
            data['preampDb'] = 0
        elif action != 'activate':
            raise ValueError('Unknown audio effects command')
        validate(data)
        apply(data, old)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError, IndexError) as error:
        print('Audio effects: ' + str(error), file=sys.stderr)
        sys.exit(1)
