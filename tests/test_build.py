import sys, tempfile, unittest
from pathlib import Path
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


if __name__ == "__main__":
    unittest.main()
