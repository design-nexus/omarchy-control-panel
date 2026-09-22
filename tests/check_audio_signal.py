"""Opt-in integration check: measure a silent, isolated PipeWire signal path."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import time
import uuid
import numpy as np

spec = importlib.util.spec_from_file_location('effects', Path(__file__).parents[1] / 'bin/audio-effects.py')
effects = importlib.util.module_from_spec(spec)
spec.loader.exec_module(effects)


def main():
    token = uuid.uuid4().hex[:8]
    sink = 'settings_test_' + token
    virtual = 'settings_test_eq_' + token
    module = effects.run('pactl', 'load-module', 'module-null-sink', 'sink_name=' + sink,
                         'rate=48000', 'channels=2').stdout.strip()
    process = None
    try:
        with tempfile.TemporaryDirectory(prefix='settings-audio-test-') as directory:
            directory = Path(directory)
            data = dict(preampDb=0, gains=[0] * 9, enabled=True, target=sink)
            config = directory / 'filter.conf'
            config.write_text(effects.graph(data).replace(effects.SINK, virtual))
            process = subprocess.Popen(['pipewire', '-c', str(config)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            node_id = None
            for _ in range(50):
                for item in json.loads(effects.run('pw-dump').stdout):
                    if item.get('info', {}).get('props', {}).get('node.name') == virtual:
                        node_id = item['id']
                sinks = json.loads(effects.run('pactl', '-f', 'json', 'list', 'sinks').stdout)
                if node_id and any(s['name'] == virtual for s in sinks):
                    break
                time.sleep(0.1)
            assert node_id, 'Test filter did not appear'
            samples = np.sin(2 * np.pi * 1000 * np.arange(96000) / 48000) * 0.001
            signal = directory / 'tone.raw'
            np.repeat(samples[:, None], 2, axis=1).astype('<f4').tofile(signal)

            def measure():
                recording = directory / 'capture.raw'
                with recording.open('wb') as output:
                    recorder = subprocess.Popen(['parec', '--device=' + sink + '.monitor', '--format=float32le',
                                                 '--rate=48000', '--channels=2'], stdout=output, stderr=subprocess.PIPE)
                    try:
                        time.sleep(0.2)
                        result = effects.run('paplay', '--raw', '--format=float32le', '--rate=48000', '--channels=2',
                                             '--device=' + virtual, str(signal), check=False)
                        if result.returncode:
                            raise RuntimeError(result.stderr)
                        time.sleep(0.2)
                    finally:
                        recorder.terminate()
                        _, errors = recorder.communicate(timeout=5)
                values = np.fromfile(recording, dtype='<f4')
                if values.size == 0:
                    raise RuntimeError('No recorded samples: ' + errors.decode())
                # The top quartile excludes start/stop silence and limiter latency.
                return float(np.quantile(np.abs(values), 0.75))

            baseline = measure()
            assert baseline > 0.0001, 'No signal reached the downstream output'
            effects.run('pw-cli', 'set-param', str(node_id), 'Props',
                        '{ params = [ "pre_l:Mult" 1.995262315 "pre_r:Mult" 1.995262315 ] }')
            boosted = measure()
            effects.run('pw-cli', 'set-param', str(node_id), 'Props',
                        '{ params = [ "pre_l:Mult" 1 "pre_r:Mult" 1 "eq5_l:Gain" 6 "eq5_r:Gain" 6 ] }')
            equalized = measure()
            preamp_db = 20 * np.log10(boosted / baseline)
            eq_db = 20 * np.log10(equalized / baseline)
            print(f'Measured preamp: {preamp_db:.2f} dB; 1 kHz EQ band: {eq_db:.2f} dB (both requested +6 dB)')
            assert abs(preamp_db - 6) < 0.5
            assert abs(eq_db - 6) < 0.5
    finally:
        if process:
            process.terminate()
            process.communicate(timeout=5)
        effects.run('pactl', 'unload-module', module, check=False)


if __name__ == '__main__':
    main()
