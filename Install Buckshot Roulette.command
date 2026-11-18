#!/bin/sh
# Double-click to build and install Buckshot Roulette for macOS from your own Steam copy.
cd "$(dirname "$0")" || exit 1
command -v python3 >/dev/null || { echo "Python 3 is needed. Install it from python.org, then double-click this again."; read -r _; exit 1; }
python3 build.py "$@"
build_status=$?
echo; echo "Press Enter to close."; read -r _

exit "$build_status"
