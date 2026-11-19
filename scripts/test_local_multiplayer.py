"""Play the owner's multiplayer scene locally with scripted seats; no Steam networking."""
from datetime import datetime
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

from scripts.game_test_fixture import extract, isolate_runtime

ROOT = Path(__file__).resolve().parent.parent


def run_local(app, smoke=False):
    runtime = Path.home() / 'Library/Caches/buckshot-roulette-mac/godot-4.4.1-runtime'
    pck = app / 'Contents/Resources/Buckshot Roulette.pck'
    if not runtime.is_file() or not pck.is_file():
        raise ValueError('Build/install the port first; its game data and cached runtime are needed.')
    if runtime.with_suffix('.pck').exists():
        raise ValueError('The test requires a standalone runtime without an adjacent game pack.')
    name = 'buckshot-local-mp-' + uuid.uuid4().hex
    save = Path.home() / 'Library/Application Support' / name
    logs = ROOT / 'local/multiplayer-tests' / datetime.now().strftime('local-%Y%m%d-%H%M%S-%f')
    logs.mkdir(parents=True)
    print('Local multiplayer: you play MIKE; three scripted seats grab items and shoot.', flush=True)
    print('Separate temporary saves; no Steam connections, achievements or real-account changes.', flush=True)
    print('This checks gameplay, not network synchronization or invites.', flush=True)
    print(f'Private log: {logs / "game.log"}', flush=True)
    try:
        with tempfile.TemporaryDirectory(prefix='buckshot-local-mp-') as scratch:
            game = Path(scratch) / 'game'
            extract(pck, game, True)
            isolate_runtime(game)
            (game / 'override.cfg').write_text(
                '[application]\nconfig/use_custom_user_dir=true\n'
                f'config/custom_user_dir_name="{name}"\n'
                '[debug]\nfile_logging/enable_file_logging=false\n'
                '[display]\nwindow/size/mode=0\nwindow/size/window_width_override=1280\n'
                'window/size/window_height_override=720\n'
                '[audio]\ndriver/enable_input=false\n'
                '[rendering]\nrendering_device/driver.macos="metal"\n')
            for parent, framework in [('addons/godotsteam/osx', 'libgodotsteam.macos.template_release.framework'),
                                      ('mac/osx', 'BuckshotFullscreen.framework')]:
                target = game / parent / framework
                source = (app / 'Contents/Frameworks' / framework).resolve()
                if not source.exists():
                    if framework == 'BuckshotFullscreen.framework': continue
                    raise ValueError('The installed app is missing its GodotSteam framework.')
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(source)
            command = [str(runtime)]
            if smoke:
                command += ['--headless', '--audio-driver', 'Dummy']
            command += ['--path', str(game), '--script', str(ROOT / 'tests/local_multiplayer.gd'), '--', name]
            if smoke: command.append('smoke')
            with (logs / 'game.log').open('w') as log:
                try:
                    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                            timeout=130 if smoke else None)
                except subprocess.TimeoutExpired:
                    print('Local test deadline reached; only the test process was stopped.')
                    return 1
            output = (logs / 'game.log').read_text(errors='replace')
            ok = result.returncode == 0 and 'SCRIPT ERROR' not in output
            if smoke: ok = ok and 'PASS LOCAL MULTIPLAYER' in output
            status = ('PASS' if ok else 'FAIL') if smoke else f'Local session closed (exit {result.returncode})'
            print(f'{status}; logs: {logs}', flush=True)
            return int(not ok)
    finally:
        shutil.rmtree(save, ignore_errors=True)
