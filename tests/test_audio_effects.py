import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('effects', Path(__file__).parents[1] / 'bin/audio-effects.py')
effects = importlib.util.module_from_spec(spec)
spec.loader.exec_module(effects)


class EffectsTests(unittest.TestCase):
    def settings(self):
        return dict(preampDb=0, gains=[0] * 9, enabled=True, target='test_sink')

    def test_preamp_is_absolute_and_independent_of_master_volume(self):
        data = self.settings()
        data['preampDb'] = 6
        self.assertAlmostEqual(effects.controls(data)['pre_l:Mult'], 1.9952623, places=6)
        self.assertEqual(effects.controls(data), effects.controls(data))
        data['preampDb'] = 0
        self.assertEqual(effects.controls(data)['pre_r:Mult'], 1)

    def test_stereo_eq_and_limiter_have_complete_connected_paths(self):
        config = json.loads(effects.graph(self.settings()))
        graph = config['context.modules'][-1]['args']['filter.graph']
        self.assertEqual(len(graph['nodes']), 21)
        links = {link['output']: link['input'] for link in graph['links']}
        for side in ('l', 'r'):
            self.assertEqual(links[f'pre_{side}:Out'], f'eq0_{side}:In')
            for i in range(8):
                self.assertEqual(links[f'eq{i}_{side}:Out'], f'eq{i+1}_{side}:In')
            self.assertEqual(links[f'eq8_{side}:Out'], f'limiter:in_{side}')

    def test_bypass_flattens_without_losing_saved_gains(self):
        data = self.settings()
        data.update(preampDb=9, gains=[3] * 9, enabled=False)
        self.assertEqual(effects.controls(data)['pre_l:Mult'], 1)
        self.assertEqual(effects.controls(data)['eq3_r:Gain'], 0)
        self.assertEqual(data['gains'], [3] * 9)

    def test_bad_values_and_feedback_target_are_rejected(self):
        for field, value in [('preampDb', float('nan')), ('preampDb', 37),
                             ('gains', [13] * 9), ('gains', [0] * 7), ('target', effects.SINK)]:
            with self.subTest(field=field, value=value):
                data = self.settings()
                data[field] = value
                with self.assertRaises(ValueError):
                    effects.validate(data)

    def test_rejects_controls_that_did_not_apply(self):
        with patch.object(effects, 'run'), patch.object(effects, 'node', return_value={}):
            with self.assertRaisesRegex(RuntimeError, 'did not retain'):
                effects.apply_live(self.settings(), {'id': 3})

    def test_never_routes_processing_streams_into_their_input(self):
        calls = []
        def command(*args, **kwargs):
            calls.append(args)
            if args[-1] == 'sinks':
                payload = [{'name': 'test_sink', 'index': 7}]
            elif args[-1] == 'sink-inputs':
                payload = [dict(index=i, sink=7, properties={'node.name': name}) for i, name in
                           [(1, 'music'), (2, effects.SINK + '_output'), (3, 'omarchy_speaker_tuning_output')]]
            else:
                payload = []
            return type('Result', (), {'stdout': json.dumps(payload)})()
        with patch.object(effects, 'run', side_effect=command):
            effects.select_output(self.settings())
        moved = [c for c in calls if 'move-sink-input' in c]
        self.assertEqual(moved, [('pactl', 'move-sink-input', '1', effects.SINK)])


if __name__ == '__main__':
    unittest.main()
