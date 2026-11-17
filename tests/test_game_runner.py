import struct
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from scripts.test_game import extract, run


def archive(name, payload=b'test'):
    name = name.encode()
    header = struct.pack('<5IIQ', 0x43504447, 2, 4, 4, 1, 0, 0) + bytes(64) + struct.pack('<I', 1)
    offset = len(header) + 4 + len(name) + 16 + 20
    return header + struct.pack('<I', len(name)) + name + struct.pack('<QQ', offset, len(payload)) + bytes(20) + payload


class RunnerChecks(unittest.TestCase):
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
