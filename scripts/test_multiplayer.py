#!/usr/bin/env python3
"""Launch the installed game and record a short, real Steam multiplayer test."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import shutil
import subprocess
import time
import sys

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

ROOT = Path(__file__).resolve().parent.parent
CHECKS = (
    ('lobby', 'Host a lobby; have a second player join. Confirm both see each other.'),
    ('invites', 'Try Shift+Tab and the in-game Invite Friends button. Confirm an invitation works.'),
    ('match', 'Start a match. Both players take turns, shoot, and use an item. Check health/items agree.'),
    ('round', 'Finish a round, including a player reaching zero health. Confirm the next state loads for both.'),
    ('rejoin', 'Return to the lobby. Have the guest leave and rejoin; start another match.'),
)


def game_running(app):
    result = subprocess.run(['/bin/ps', '-axo', 'comm='], capture_output=True, text=True, check=True)
    executable = str(app / 'Contents/MacOS/Buckshot Roulette')
    return executable in (line.strip() for line in result.stdout.splitlines())


def launch(app, log):
    if game_running(app):
        print('Using your running game. It will stay open; its normal log will be copied at the end.')
        return None
    return subprocess.Popen([str(app / 'Contents/MacOS/launch'), '--log-file', str(log)],
                            stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT, start_new_session=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=Path.home() / 'Applications/Buckshot Roulette.app')  # where the installer puts it
    parser.add_argument('--local', action='store_true', help='play locally with three scripted seats; no second account needed')
    parser.add_argument('--smoke', action='store_true', help='run a bounded automatic local gameplay check')
    args = parser.parse_args()
    app = args.app.expanduser().resolve()
    if args.local or args.smoke:
        from scripts.test_local_multiplayer import run_local
        try:
            return run_local(app, smoke=args.smoke)
        except (OSError, ValueError) as error:
            parser.exit(1, f'Local test could not start: {error}\n')
    if not (app / 'Contents/MacOS/launch').is_file():
        parser.error('Install the Mac port first, or specify its app with --app')
    started = time.time()
    folder = ROOT / 'local/multiplayer-tests' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    folder.mkdir(parents=True)
    print('Real Steam test: use a second player/account on another computer. About 10–15 minutes.')
    print('Steam and ownership checks remain enabled. Saves and achievements use your normal account.')
    print(f'Private results: {folder}\n')
    try:
        process = launch(app, folder / 'game.log')
    except (OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Could not check/start the game: {error}\n')
    report = {'app': str(app), 'started': datetime.now().isoformat(), 'checks': {}}
    try:
        for index, (key, instruction) in enumerate(CHECKS, 1):
            print(f'\n{index}/{len(CHECKS)}: {instruction}')
            while True:
                answer = input('Result [p=pass, f=fail, s=skip, q=finish]: ').strip().lower()
                if answer in ('p', 'f', 's', 'q'):
                    break
            if answer == 'q':
                break
            note = input('Short note (Enter to leave blank): ').strip() if answer == 'f' else ''
            report['checks'][key] = {'result': {'p': 'pass', 'f': 'fail', 's': 'skip'}[answer], 'note': note}
    except (EOFError, KeyboardInterrupt):
        print('\nSaving partial results. Your game stays open.')
    finally:
        report['exit_code'] = process.poll() if process else None
        normal_log = Path.home() / 'Library/Application Support/Godot/app_userdata/Buckshot Roulette/logs/godot.log'
        diagnostics = Path.home() / 'Library/Logs/DiagnosticReports'
        try:
            if process is None and normal_log.is_file():
                shutil.copy2(normal_log, folder / 'game.log')
            for crash in diagnostics.glob('Buckshot Roulette*.ips'):
                if crash.stat().st_mtime >= started:
                    shutil.copy2(crash, folder / crash.name)
        finally:
            (folder / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
            print(f'\nResults saved: {folder}')
            print('The game remains open. Unchecked items are not passes. Logs may contain player identifiers; review before sharing.')
    return int(any(check['result'] == 'fail' for check in report['checks'].values())
               or report['exit_code'] not in (None, 0))


if __name__ == '__main__':
    raise SystemExit(main())
