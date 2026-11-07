#!/usr/bin/env bash
# Scripted text-mode playthrough: the game must handle commands, bad input and quit
# without script errors. Used by CI; no GPU needed.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
input=$'h\nu 1\nf 5\ndance\nm 99 99\nm 2 7\nw\nw\nw\nw\nw\nw\nw\nw\nq\n'
out=$(printf '%s' "$input" | "$GODOT" --headless --path . -s res://tools/play.gd -- --seed=7 2>&1)
fail=0
grep -q "Commands" <<<"$out" || { echo "missing help text"; fail=1; }
grep -q "unknown command" <<<"$out" || { echo "bad input not reported"; fail=1; }
grep -qE "Bye\.|\*\*\* (VICTORY|DEFEAT) \*\*\*" <<<"$out" || { echo "did not end (quit or battle result)"; fail=1; }
if grep -E "SCRIPT ERROR|Parse Error" <<<"$out"; then echo "script errors during play"; fail=1; fi
[[ $fail -eq 0 ]] && echo "smoke play: OK"
exit $fail
