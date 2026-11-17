#!/usr/bin/env python3
"""Run short, isolated regressions against your locally built game. No game files are included.

python3 scripts/test_game.py --repeat 5
Use --baseline to demonstrate the existing timer errors without applying the proposed patches.
"""
import argparse
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_GODOT = Path.home() / 'Library/Caches/buckshot-roulette-mac/godot-4.4.1/Godot.app/Contents/MacOS/Godot'


def extract(pck, dest, full):
    with pck.open('rb') as f:
        magic, version = struct.unpack('<II', f.read(8))
        if magic != 0x43504447 or version != 2:
            raise ValueError('Expected an unencrypted Godot 4 PCK')
        f.read(12)
        flags, base = struct.unpack('<IQ', f.read(12))
        if flags & 1:
            raise ValueError('Encrypted PCK directories are not supported')
        f.read(64)
        count, = struct.unpack('<I', f.read(4))
        entries = []
        for _ in range(count):
            length, = struct.unpack('<I', f.read(4))
            if length > 65536:
                raise ValueError('Invalid PCK path length')
            name = f.read(length).rstrip(b'\0').decode().removeprefix('res://')
            offset, size = struct.unpack('<QQ', f.read(16))
            f.read(20)
            path = dest / name
            if not path.resolve().is_relative_to(dest.resolve()):
                raise ValueError('PCK path escapes test folder')
            if full or name in ('scripts/BlinkerBranch.gd', 'scripts/BpmLight.gd', 'scripts/PartitionBranch.gd'):
                entries.append((path, base + offset, size))
        for path, offset, size in entries:
            f.seek(offset)
            data = f.read(size)
            if len(data) != size:
                raise ValueError('Truncated PCK entry')
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)


def run(godot, project, script, args, log, timeout=45):
    command = [str(godot), '--headless', '--path', str(project), '--script', str(script), '--', *map(str, args)]
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        text = result.stdout.decode(errors='replace')
    except subprocess.TimeoutExpired as error:
        text = (error.stdout or b'').decode(errors='replace') + '\nTEST TIMEOUT'
        log.write_text(text)
        return False
    log.write_text(text)
    # The dummy headless renderer emits mesh warnings. Script errors and real lifecycle errors fail.
    return (result.returncode == 0 and 'SCENARIO PASS' in text
            and not re.search(r'SCRIPT ERROR|Parameter .*null|TEST TIMEOUT', text))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=Path('/Applications/Buckshot Roulette.app'))
    parser.add_argument('--godot', type=Path, default=DEFAULT_GODOT)
    parser.add_argument('--scenario', choices=['lifecycle', 'death', 'all'], default='all')
    parser.add_argument('--repeat', type=int, default=1)
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--logs', type=Path, default=ROOT / 'local/test-logs')
    args = parser.parse_args()
    if not 1 <= args.repeat <= 100:
        parser.error('--repeat must be between 1 and 100')
    pck = args.app / 'Contents/Resources/Buckshot Roulette.pck'
    if not pck.is_file() or not args.godot.is_file():
        parser.error('Build the app first, or supply --app and --godot')
    logs = args.logs.resolve() / uuid.uuid4().hex[:10]
    logs.mkdir(parents=True)
    failures = 0
    save_name = 'buckshot-test-' + uuid.uuid4().hex
    save_dir = Path.home() / 'Library/Application Support' / save_name
    try:
        with tempfile.TemporaryDirectory(prefix='buckshot-tests-') as scratch:
            work = Path(scratch)
            bootstrap = work / 'bootstrap'
            bootstrap.mkdir()
            (bootstrap / '.godot').mkdir()
            (bootstrap / '.godot/global_script_class_cache.cfg').write_text('list=[]\n')
            (bootstrap / 'project.godot').write_text(
                '[application]\nconfig/name="Buckshot tests"\nconfig/use_custom_user_dir=true\n'
                f'config/custom_user_dir_name="{save_name}"\n[debug]\nfile_logging/enable_file_logging=false\n')
            game = work / 'game'
            extract(pck, game, args.scenario != 'lifecycle')
            mode = 'baseline' if args.baseline else 'patched'
            if args.scenario in ('lifecycle', 'all'):
                for i in range(args.repeat):
                    log = logs / f'lifecycle-{i}.log'
                    ok = run(args.godot, bootstrap, ROOT / 'tests/runtime_lifecycle.gd', [game, ROOT / 'tools/repack.gd', mode], log)
                    failures += not ok
                    print(f'{"PASS" if ok else "FAIL"} lifecycle {i + 1}; {log}', flush=True)
            if args.scenario in ('death', 'all'):
                if not args.baseline:
                    log = logs / 'prepare.log'
                    if not run(args.godot, bootstrap, ROOT / 'tests/runtime_lifecycle.gd', [game, ROOT / 'tools/repack.gd', 'prepare'], log):
                        raise RuntimeError(f'Patch preparation failed: {log}')
                framework = args.app / 'Contents/Frameworks/libgodotsteam.macos.template_release.framework'
                native = game / 'addons/godotsteam/osx'
                native.mkdir(parents=True, exist_ok=True)
                (native / framework.name).symlink_to(framework.resolve())
                (game / 'override.cfg').write_text((bootstrap / 'project.godot').read_text())
                for i in range(args.repeat):
                    for target, health, damage in [('heaven', 1, 1), ('heaven', 2, 2), ('death', 1, 1)]:
                        # Each case starts without the previous case's checkpoint.
                        shutil.rmtree(save_dir, ignore_errors=True)
                        log = logs / f'{target}-{health}-{damage}-{i}.log'
                        ok = run(args.godot, game, ROOT / 'tests/game_scenarios.gd', [save_name, target, health, damage], log)
                        failures += not ok
                        print(f'{"PASS" if ok else "FAIL"} {target} hp={health} damage={damage} #{i+1}; {log}', flush=True)
    finally:
        shutil.rmtree(save_dir, ignore_errors=True)
    print(f'{failures} failures; logs: {logs}')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
