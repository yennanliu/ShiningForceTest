#!/usr/bin/env bash
# Generated files must match their generators: re-run them and fail on any diff.
# Covers data/ (make_content), tests/fixtures (make_fixtures), tests/golden (make_golden),
# and assets/audio (make_audio.py).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s res://tools/make_fixtures.gd >/dev/null 2>&1
"$GODOT" --headless --path . -s res://tools/make_content.gd >/dev/null 2>&1
"$GODOT" --headless --path . -s res://tools/make_golden.gd >/dev/null 2>&1
if command -v python3 >/dev/null; then python3 tools/make_audio.py >/dev/null; fi
if ! git diff --exit-code --stat -- data tests/fixtures tests/golden assets/audio; then
  echo "ERROR: generated files are out of date. Re-run the generators and commit the result."
  exit 1
fi
echo "generated files: OK"
