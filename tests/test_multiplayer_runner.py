import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.test_multiplayer import game_running, launch


class MultiplayerLauncherChecks(unittest.TestCase):
    def test_running_game_is_reused_without_starting_another(self):
        with patch('scripts.test_multiplayer.game_running', return_value=True), \
                patch('scripts.test_multiplayer.subprocess.Popen') as start:
            self.assertIsNone(launch(Path('/Applications/Buckshot Roulette.app'), Path('/tmp/test.log')))
            start.assert_not_called()

    def test_launch_uses_production_wrapper_and_separate_log(self):
        app = Path('/Applications/Buckshot Roulette.app')
        with patch('scripts.test_multiplayer.game_running', return_value=False), \
                patch('scripts.test_multiplayer.subprocess.Popen') as start:
            launch(app, Path('/tmp/test.log'))
            self.assertEqual(start.call_args.args[0], [str(app / 'Contents/MacOS/launch'), '--log-file', '/tmp/test.log'])
            self.assertTrue(start.call_args.kwargs['start_new_session'])

    def test_process_detection_matches_exact_app_executable(self):
        app = Path('/Applications/Buckshot Roulette.app')
        result = subprocess.CompletedProcess([], 0, str(app / 'Contents/MacOS/Buckshot Roulette') + '\n')
        with patch('scripts.test_multiplayer.subprocess.run', return_value=result):
            self.assertTrue(game_running(app))
            self.assertFalse(game_running(Path('/tmp/Other.app')))
