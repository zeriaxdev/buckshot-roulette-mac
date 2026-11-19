#!/bin/sh
# Double-click for a guided real multiplayer check; never closes the game.
cd "$(dirname "$0")" || exit 1
command -v python3 >/dev/null || { echo "Python 3 is needed. Install it from python.org."; read -r _; exit 1; }
if [ "$#" -eq 0 ]; then set -- --local; fi
python3 scripts/test_multiplayer.py "$@"
test_status=$?
echo; echo "Press Enter to close."; read -r _
exit "$test_status"
