import struct
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from scripts.test_game import extract, isolate_runtime, run


def archive(name, payload=b'test'):
    name = name.encode()
    header = struct.pack('<5IIQ', 0x43504447, 2, 4, 4, 1, 0, 0) + bytes(64) + struct.pack('<I', 1)
    offset = len(header) + 4 + len(name) + 16 + 20
    return header + struct.pack('<I', len(name)) + name + struct.pack('<QQ', offset, len(payload)) + bytes(20) + payload


class RunnerChecks(unittest.TestCase):
    def test_runtime_with_game_pack_is_rejected_before_launch(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            for runtime in [root / 'godot', root / 'Game.app/Contents/MacOS/Game']:
                runtime.parent.mkdir(parents=True, exist_ok=True)
                pack = runtime.with_suffix('.pck') if runtime.name == 'godot' else runtime.parent.parent / 'Resources/Game.pck'
                pack.parent.mkdir(parents=True, exist_ok=True)
                pack.write_bytes(b'pack')
                with patch('scripts.test_game.subprocess.run') as process:
                    with self.assertRaisesRegex(ValueError, 'adjacent game pack'):
                        run(runtime, '.', 'test.gd', [], root / 'log')
                    process.assert_not_called()

    def test_missing_extension_is_failure(self):
        with tempfile.TemporaryDirectory() as scratch:
            result = subprocess.CompletedProcess([], 0, b"Error loading extension: fullscreen\nSCENARIO PASS")
            with patch('scripts.test_game.subprocess.run', return_value=result):
                self.assertFalse(run('godot', '.', 'test.gd', [], Path(scratch) / 'log'))

    def test_extract_rejects_path_traversal(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            pck = root / 'source.pck'
            pck.write_bytes(archive('../escape'))
            with self.assertRaises(ValueError):
                extract(pck, root / 'out', True)
            self.assertFalse((root / 'escape').exists())

    def test_extract_rejects_truncated_data(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            pck = root / 'source.pck'
            pck.write_bytes(archive('file')[:-1])
            with self.assertRaises(ValueError):
                extract(pck, root / 'out', True)

    def test_success_marker_does_not_hide_script_error(self):
        with tempfile.TemporaryDirectory() as scratch:
            result = subprocess.CompletedProcess([], 0, b'SCRIPT ERROR: timer on null\nSCENARIO PASS')
            with patch('scripts.test_game.subprocess.run', return_value=result):
                self.assertFalse(run('godot', '.', 'test.gd', [], Path(scratch) / 'log'))

    def test_timeout_is_failure_and_keeps_log(self):
        with tempfile.TemporaryDirectory() as scratch:
            log = Path(scratch) / 'log'
            error = subprocess.TimeoutExpired([], 1, output=b'before timeout')
            with patch('scripts.test_game.subprocess.run', side_effect=error):
                self.assertFalse(run('godot', '.', 'test.gd', [], log))
            self.assertIn('before timeout', log.read_text())

    def test_success_marker_does_not_hide_translation_error(self):
        with tempfile.TemporaryDirectory() as scratch:
            result = subprocess.CompletedProcess([], 0, b'ERROR: not all arguments converted\nSCENARIO PASS')
            with patch('scripts.test_game.subprocess.run', return_value=result):
                self.assertFalse(run('godot', '.', 'test.gd', [], Path(scratch) / 'log'))

    def test_fixture_disables_sdk_but_keeps_other_methods(self):
        with tempfile.TemporaryDirectory() as scratch:
            project = Path(scratch)
            scripts = project / 'scripts'; scripts.mkdir()
            steam = scripts / 'Steam.gd'
            steam.write_text('extends Node\nfunc _ready():\n\tInitializeSteam()\n\nfunc _process(delta):\n\tSteam.run_callbacks()\n\nfunc helper():\n\treturn 1\n')
            (scripts / 'GlobalVariables.gd').write_text('var using_steam = true\n')
            isolate_runtime(project)
            self.assertNotIn('InitializeSteam()', steam.read_text())
            self.assertNotIn('Steam.run_callbacks()', steam.read_text())
            self.assertIn('func helper():\n\treturn 1', steam.read_text())
            self.assertEqual((scripts / 'GlobalVariables.gd').read_text(), 'var using_steam = false\n')

    def test_requested_audio_driver_is_passed_to_runtime(self):
        with tempfile.TemporaryDirectory() as scratch:
            result = subprocess.CompletedProcess([], 0, b'SCENARIO PASS')
            with patch('scripts.test_game.subprocess.run', return_value=result) as process:
                self.assertTrue(run('godot', '.', 'test.gd', [], Path(scratch) / 'log', audio_driver='CoreAudio'))
            self.assertEqual(process.call_args.args[0][1:4], ['--headless', '--audio-driver', 'CoreAudio'])

    def test_unknown_fixture_layout_fails_without_rewriting(self):
        with tempfile.TemporaryDirectory() as scratch:
            project = Path(scratch)
            scripts = project / 'scripts'; scripts.mkdir()
            steam = scripts / 'Steam.gd'; original = 'func _ready():\n\tInitializeSteam()\n'
            steam.write_text(original)
            with self.assertRaises(ValueError): isolate_runtime(project)
            self.assertEqual(steam.read_text(), original)
