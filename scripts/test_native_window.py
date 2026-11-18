#!/usr/bin/env python3
"""Test real macOS notch/fullscreen transitions without game files or Steam."""
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parent.parent


def main():
    runtime = Path.home() / 'Library/Caches/buckshot-roulette-mac/godot-4.4.1-runtime'
    if not runtime.is_file():
        raise SystemExit('Build your local port first to cache the Godot runtime.')
    save_name = 'buckshot-native-' + uuid.uuid4().hex
    logs = ROOT / 'local/native-window-tests' / save_name
    logs.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix='br-native-window-') as scratch:
        project = Path(scratch)
        app = project / 'Notch Window Test.app'
        executable = app / 'Contents/MacOS/NotchTest'
        executable.parent.mkdir(parents=True)
        subprocess.run(['cp', '-c', str(runtime), str(executable)], check=True)
        shutil.copytree(ROOT / 'tools/native/BuckshotFullscreen.framework', app / 'Contents/Frameworks/BuckshotFullscreen.framework')
        (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
            'CFBundleExecutable': 'NotchTest', 'CFBundleIdentifier': 'local.buckshot.' + uuid.uuid4().hex,
            'CFBundleName': 'Notch Window Test', 'CFBundlePackageType': 'APPL',
            'NSHighResolutionCapable': True, 'NSPrefersDisplaySafeAreaCompatibilityMode': False,
        }))
        subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(app)], check=True, capture_output=True)
        (project / '.godot').mkdir(); (project / 'mac').mkdir()
        (project / '.godot/global_script_class_cache.cfg').write_text('list=[]\n')
        (project / '.godot/extension_list.cfg').write_text('res://mac/fullscreen.gdextension\n')
        (project / 'mac/fullscreen.gdextension').write_text(
            '[configuration]\nentry_symbol="buckshot_fullscreen_init"\ncompatibility_minimum="4.4"\n'
            '[libraries]\nmacos="osx/BuckshotFullscreen.framework"\n')
        (project / 'project.godot').write_text(
            'config_version=5\n[application]\nconfig/name="Native fullscreen test"\n'
            f'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="{save_name}"\n'
            '[display]\nwindow/size/viewport_width=960\nwindow/size/viewport_height=540\n'
            'window/stretch/mode="viewport"\nwindow/stretch/aspect="keep"\n'
            '[debug]\nfile_logging/enable_file_logging=false\n'
            '[rendering]\nrenderer/rendering_method="forward_plus"\n')
        print('Testing a synthetic fullscreen window for up to 30 seconds; no game or Steam data.', flush=True)
        try:
            subprocess.run(['open', '-W', '-n', str(app), '--stdout', str(logs / 'stdout.log'),
                            '--stderr', str(logs / 'stderr.log'), '--args', '--audio-driver', 'Dummy',
                            '--path', str(project), '--script', str(ROOT / 'tests/native_fullscreen.gd'),
                            '--', str(ROOT / 'tools/screen_fit.gd'), save_name], check=True, timeout=30)
        finally:
            # A timed-out LaunchServices wait can leave its app alive; stop only our exact executable.
            pid_file = project / 'probe.pid'
            if pid_file.exists():
                pid = int(pid_file.read_text())
                command = subprocess.run(['ps', '-p', str(pid), '-o', 'comm='], capture_output=True, text=True)
                if command.stdout.strip() == str(executable):
                    try: os.kill(pid, signal.SIGTERM)
                    except ProcessLookupError: pass
            shutil.rmtree(Path.home() / 'Library/Application Support' / save_name, ignore_errors=True)
    output = (logs / 'stdout.log').read_text(errors='replace')
    errors = (logs / 'stderr.log').read_text(errors='replace')
    ok = 'PASS NOTCH' in output and not errors.strip()
    print(output, errors, f'Logs: {logs}')
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
