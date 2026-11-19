import sys, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import build


class BuildChecks(unittest.TestCase):
    def test_rejects_non_exe(self):
        with tempfile.NamedTemporaryFile(suffix=".exe") as f:
            f.write(b"PK"); f.flush()
            with self.assertRaises(ValueError):
                build.check_exe(Path(f.name))

    def test_accepts_mz(self):
        with tempfile.NamedTemporaryFile(suffix=".exe") as f:
            f.write(b"MZ"); f.flush()
            build.check_exe(Path(f.name))

    def test_metadata_has_no_placeholders(self):
        meta = build.app_metadata()
        self.assertEqual(meta["CFBundleExecutable"], "launch")
        self.assertIs(meta["NSPrefersDisplaySafeAreaCompatibilityMode"], False)
        self.assertTrue(all("$" not in str(v) for v in meta.values()))


class SetupChecks(unittest.TestCase):
    def test_existing_game_skips_console(self):
        with patch("build.find_depot_exe", return_value=Path("owned.exe")), patch("build.subprocess.run") as opened:
            self.assertEqual(build.locate_game(None), Path("owned.exe"))
            opened.assert_not_called()

    def test_continue_after_download_in_same_run(self):
        with patch("build.find_depot_exe", side_effect=[None, Path("owned.exe")]), patch("build.sys.stdin.isatty", return_value=True), patch("build.ask", return_value=""), patch("build.subprocess.run") as opened:
            self.assertEqual(build.locate_game(None), Path("owned.exe"))
            opened.assert_called_once_with(["open", "steam://open/console"])

    def test_noninteractive_missing_game_stops_without_opening_apps(self):
        with patch("build.find_depot_exe", return_value=None), patch("build.sys.stdin.isatty", return_value=False), patch("build.subprocess.run") as opened:
            with self.assertRaisesRegex(ValueError, "--game"):
                build.locate_game(None)
            opened.assert_not_called()

    def test_cancel_does_not_recheck_or_build(self):
        with patch("build.find_depot_exe", return_value=None) as find, patch("build.sys.stdin.isatty", return_value=True), patch("build.ask", return_value="q"), patch("build.subprocess.run"):
            with self.assertRaisesRegex(ValueError, "Cancelled"):
                build.locate_game(None)
            self.assertEqual(find.call_count, 1)

    def test_incomplete_download_stops(self):
        with patch("build.find_depot_exe", return_value=None), patch("build.sys.stdin.isatty", return_value=True), patch("build.ask", return_value=""), patch("build.subprocess.run"):
            with self.assertRaisesRegex(ValueError, "Let Steam finish"):
                build.locate_game(None)


class InstallChecks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.old = self.root / "installed.app"
        self.new = self.root / "candidate.app"
        for path, content in ((self.old, "old"), (self.new, "new")):
            path.mkdir()
            (path / "version").write_text(content)
        self.home = patch.object(Path, "home", return_value=self.root)
        self.home.start()
        self.addCleanup(self.home.stop)

    def test_success_preserves_old_app_in_trash(self):
        build.install_app(self.new, self.old, True)
        self.assertEqual((self.old / "version").read_text(), "new")
        backups = list((self.root / ".Trash").glob("*.app"))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / "version").read_text(), "old")

    def test_staging_failure_keeps_old_app(self):
        with patch("build.shutil.move", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                build.install_app(self.new, self.old, True)
        self.assertEqual((self.old / "version").read_text(), "old")

    def test_failed_download_keeps_installed_app(self):
        game = self.root / "game.exe"
        game.write_bytes(b"MZ")
        with patch("build.sys.platform", "darwin"), patch("build.CACHE", self.root / "cache"), patch("build.fetch", side_effect=RuntimeError("download failed")):
            with self.assertRaises(RuntimeError):
                build.main(["--game", str(game), "--output", str(self.old), "--replace", "--i-own-the-game"])
        self.assertEqual((self.old / "version").read_text(), "old")

    def test_failed_swap_restores_old_app(self):
        rename = Path.rename
        def fail_swap(path, target):
            if path.parent.name.startswith(".br-install-"):
                raise OSError("rename failed")
            return rename(path, target)
        with patch.object(Path, "rename", fail_swap):
            with self.assertRaises(OSError):
                build.install_app(self.new, self.old, True)
        self.assertEqual((self.old / "version").read_text(), "old")

    def test_unapproved_destination_is_kept(self):
        with self.assertRaises(ValueError):
            build.install_app(self.new, self.old, False)
        self.assertEqual((self.old / "version").read_text(), "old")


if __name__ == "__main__":
    unittest.main()
