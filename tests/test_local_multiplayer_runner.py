from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts.test_local_multiplayer import run_local
from scripts.test_multiplayer import main


class LocalMultiplayerChecks(unittest.TestCase):
    def test_solo_mode_never_launches_the_production_wrapper(self):
        with patch('sys.argv', ['test_multiplayer.py', '--local']), \
                patch('scripts.test_local_multiplayer.run_local', return_value=0) as local, \
                patch('scripts.test_multiplayer.launch') as production:
            self.assertEqual(main(), 0)
            local.assert_called_once_with(Path('/Applications/Buckshot Roulette.app'), smoke=False)
            production.assert_not_called()

    def test_automatic_mode_propagates_failure(self):
        with patch('sys.argv', ['test_multiplayer.py', '--smoke']), \
                patch('scripts.test_local_multiplayer.run_local', return_value=1) as local:
            self.assertEqual(main(), 1)
            self.assertTrue(local.call_args.kwargs['smoke'])

    def test_adjacent_game_pack_is_refused_before_extracting_or_running(self):
        with tempfile.TemporaryDirectory() as scratch:
            home = Path(scratch)
            runtime = home / 'Library/Caches/buckshot-roulette-mac/godot-4.4.1-runtime'
            runtime.parent.mkdir(parents=True)
            runtime.touch(); runtime.with_suffix('.pck').touch()
            app = home / 'Game.app'
            (app / 'Contents/Resources').mkdir(parents=True)
            (app / 'Contents/Resources/Buckshot Roulette.pck').touch()
            with patch('scripts.test_local_multiplayer.Path.home', return_value=home), \
                    patch('scripts.test_local_multiplayer.extract') as extract, \
                    patch('scripts.test_local_multiplayer.subprocess.run') as run:
                with self.assertRaisesRegex(ValueError, 'standalone runtime'):
                    run_local(app)
                extract.assert_not_called(); run.assert_not_called()
