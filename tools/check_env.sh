#!/usr/bin/env bash
# Environment check: the Godot in use must match .godot-version, and the project must import cleanly.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
want=$(cat .godot-version)                      # e.g. 4.7.2-stable
have=$("$GODOT" --version | head -1)            # e.g. 4.7.2.stable.official.ed1daf0bf
want_dots=${want//-/.}
if [[ "$have" != "$want_dots"* ]]; then
  echo "ERROR: Godot $have does not match .godot-version ($want)"; exit 1
fi
errors=$("$GODOT" --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Failed to load" || true)
if [[ -n "$errors" ]]; then echo "ERROR: import problems:"; echo "$errors"; exit 1; fi
echo "env check: OK (Godot $have)"
