import hashlib, struct, sys, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import steam_entry as se


def record(appid, tree, strings):
    payload = se.encode(tree, strings)
    return struct.pack("<II", appid, 60 + len(payload)) + bytes(40) + hashlib.sha1(payload).digest() + payload


def fake_cache(path, osextended=True):
    """Synthetic v41 cache: another game, then Buckshot Roulette shaped like Steam's real record."""
    strings = []
    other = record(10, {"appinfo": (0, {"common": (0, {"name": (1, "Other Game")})})}, strings)
    common = {"name": (1, se.NAME), "oslist": (1, "windows,linux")}
    if osextended:
        common["osextended"] = (1, "")
    buckshot = record(se.APP_ID, {"appinfo": (0, {
        "common": (0, common),
        "config": (0, {"launch": (0, {"0": (0, {"executable": (1, "Buckshot Roulette.exe"), "config": (0, {"oslist": (1, "windows")})})})}),
        "depots": (0, {"branches": (0, {"public": (0, {"buildid": (2, struct.pack("<I", 1234))})})}),
    })}, strings)
    body = other + buckshot + struct.pack("<I", 0)
    table = 16 + len(body)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(struct.pack("<IIQ", se.MAGIC, 1, table) + body
                     + struct.pack("<I", len(strings)) + b"".join(s.encode() + b"\0" for s in strings))


class SteamEntryChecks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.steam = root / "Steam"
        self.p = se.paths(self.steam)
        fake_cache(self.p["cache"])
        (self.steam / "steamapps/common").mkdir(parents=True)
        self.app = root / "Applications/Buckshot Roulette.app"
        (self.app / "Contents/MacOS").mkdir(parents=True)
        (self.app / "Contents/MacOS/Buckshot Roulette").write_bytes(b"binary")
        self.patches = [patch("steam_entry.steam_running", return_value=False),
                        patch("steam_entry.app_archs", return_value={"x86_64", "arm64"})]
        for p in self.patches:
            p.start()

    def tearDown(self):
        for p in self.patches:
            p.stop()
        self.tmp.cleanup()

    def records(self):
        return dict(se.read_cache(self.p["cache"])[2])

    def test_add_sets_up_play_and_touches_no_other_game(self):
        before = self.records()
        se.add(self.app, self.steam)
        after = self.records()
        self.assertEqual(before[10], after[10])
        *_, tree = se.load(self.p["cache"])
        common = tree["appinfo"][1]["common"][1]
        self.assertEqual(common["oslist"][1], "windows,linux,macos")
        self.assertEqual(common["osextended"][1], "macos64,macosapplesilicon")
        self.assertTrue(any(se.ours(e) for e in tree["appinfo"][1]["config"][1]["launch"][1].values()))
        self.assertIn('"buildid"\t\t"1234"', self.p["manifest"].read_text())
        self.assertEqual((self.p["folder"] / se.LAUNCH_EXE).resolve(), self.app.resolve())
        self.assertTrue(se.status(self.steam).startswith("on"))

    def test_add_twice_changes_nothing_more(self):
        se.add(self.app, self.steam)
        first = self.p["cache"].read_bytes()
        self.assertIn("already", se.add(self.app, self.steam))
        self.assertEqual(first, self.p["cache"].read_bytes())

    def test_remove_restores_the_original_record(self):
        for osextended in (True, False):
            with self.subTest(osextended=osextended):
                fake_cache(self.p["cache"], osextended)
                original = self.records()
                se.add(self.app, self.steam)
                se.remove(self.steam)
                # Every record is byte-identical again. Added key names stay in Steam's shared
                # string table: removing them could shift indexes other records use.
                self.assertEqual(original, self.records())
                self.assertFalse(self.p["manifest"].exists() or self.p["folder"].exists() or self.p["receipt"].exists())
                self.assertEqual(se.status(self.steam), "off")

    def test_refuses_while_steam_runs(self):
        original = self.p["cache"].read_bytes()
        with patch("steam_entry.steam_running", return_value=True):
            with self.assertRaisesRegex(se.SteamEntryError, "Quit Steam"):
                se.add(self.app, self.steam)
        self.assertEqual(original, self.p["cache"].read_bytes())
        self.assertFalse(self.p["manifest"].exists())

    def test_refuses_unknown_or_damaged_caches_unchanged(self):
        good = self.p["cache"].read_bytes()
        for bad in (struct.pack("<I", 0x07564428) + good[4:], good[:-30], good[:200]):
            with self.subTest(size=len(bad)):
                self.p["cache"].write_bytes(bad)
                with self.assertRaises(se.SteamEntryError):
                    se.add(self.app, self.steam)
                self.assertEqual(bad, self.p["cache"].read_bytes())

    def test_leaves_another_install_alone(self):
        self.p["manifest"].parent.mkdir(parents=True, exist_ok=True)
        self.p["manifest"].write_text('"AppState"\n{\n\t"installdir"\t\t"Buckshot Roulette"\n}\n')
        with self.assertRaisesRegex(se.SteamEntryError, "another"):
            se.add(self.app, self.steam)


if __name__ == "__main__":
    unittest.main()
