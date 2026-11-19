"""Rebuild the small, asset-free macOS presentation helper (requires Xcode tools)."""
from pathlib import Path
import plistlib
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parent
    framework = root / 'BuckshotFullscreen.framework'
    framework.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='br-native-') as scratch:
        binaries = []
        for arch, minimum in [('arm64', '11.0'), ('x86_64', '10.13')]:
            output = Path(scratch) / arch
            subprocess.run(['xcrun', 'clang++', '-dynamiclib', '-arch', arch, '-std=c++17',
                            '-fobjc-arc', '-O2', f'-mmacosx-version-min={minimum}', '-framework', 'Cocoa',
                            '-install_name', '@rpath/BuckshotFullscreen.framework/BuckshotFullscreen',
                            str(root / 'presentation.mm'), '-o', str(output)], check=True)
            binaries.append(str(output))
        subprocess.run(['xcrun', 'lipo', '-create', *binaries, '-output', str(framework / 'BuckshotFullscreen')], check=True)
    (framework / 'Info.plist').write_bytes(plistlib.dumps({
        'CFBundleExecutable': 'BuckshotFullscreen', 'CFBundleIdentifier': 'local.buckshotroulette.fullscreen',
        'CFBundlePackageType': 'FMWK', 'CFBundleVersion': '1', 'CFBundleShortVersionString': '1.0',
    }))
    print(framework)


if __name__ == '__main__':
    main()
