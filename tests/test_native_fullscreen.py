from pathlib import Path
import plistlib
import struct
import subprocess
import sys
import tempfile
import unittest


class NativeFullscreenArtifactChecks(unittest.TestCase):
    @unittest.skipUnless(sys.platform == 'darwin', 'Cocoa requires macOS')
    def test_notch_shadow_restores_original_window_appearance(self):
        source = Path(__file__).with_name('native_shadow.mm')
        with tempfile.TemporaryDirectory(prefix='br-shadow-') as scratch:
            executable = Path(scratch) / 'shadow-test'
            subprocess.run(['xcrun', 'clang++', '-fobjc-arc', '-std=c++17', '-framework', 'Cocoa',
                            str(source), '-o', str(executable)], check=True, capture_output=True)
            subprocess.run([str(executable)], check=True, capture_output=True)

    def test_shipped_helper_has_both_supported_architectures(self):
        framework = Path(__file__).resolve().parent.parent / 'tools/native/BuckshotFullscreen.framework'
        metadata = plistlib.loads((framework / 'Info.plist').read_bytes())
        binary = (framework / metadata['CFBundleExecutable']).read_bytes()
        magic, count = struct.unpack_from('>II', binary)
        self.assertEqual(magic, 0xCAFEBABE)
        self.assertEqual(count, 2)
        architectures = set()
        for index in range(count):
            cpu, _, offset, size, _ = struct.unpack_from('>IIIII', binary, 8 + index * 20)
            self.assertGreater(size, 0)
            self.assertLessEqual(offset + size, len(binary))
            architectures.add(cpu)
        self.assertEqual(architectures, {0x01000007, 0x0100000C})
