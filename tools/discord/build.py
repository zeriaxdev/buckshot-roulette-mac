"""Rebuild this project's Universal 2 Discord IPC helper with Xcode tools."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='br-discord-') as scratch:
    slices = []
    for arch, minimum in [('arm64', '11.0'), ('x86_64', '10.13')]:
        output = Path(scratch) / arch
        subprocess.run(['xcrun', 'clang++', '-std=c++17', '-fobjc-arc', '-O2', '-arch', arch,
                        f'-mmacosx-version-min={minimum}', '-framework', 'Foundation',
                        str(root / 'presence.mm'), '-o', str(output)], check=True)
        slices.append(str(output))
    subprocess.run(['xcrun', 'lipo', '-create', *slices, '-output', str(root / 'discord-presence')], check=True)
