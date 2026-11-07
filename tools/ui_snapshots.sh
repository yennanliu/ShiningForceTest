#!/usr/bin/env bash
# UI snapshots (doc/03 step 18): screenshot every screen and compare with tests/ui_golden/.
# Needs a window (GPU), like tools/screenshot.gd. Animations are skipped (the close-up is held on its
# final frame) and saves are empty, so shots are repeatable. Layout is the same at every window size (the 1920x1080 canvas is scaled),
# so shots are taken at the default 1280x720 window.
#   tools/ui_snapshots.sh            compare; fails if any screen differs by more than 1%
#   tools/ui_snapshots.sh --update   accept the current look as the new golden images
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=build/ui
GOLD=tests/ui_golden
mkdir -p "$OUT" "$GOLD"
SHOTS=(
  "title|--screen=title --skip-anim"
  "settings|--screen=settings --skip-anim"
  "camp_ch1|--screen=camp --chapter=1 --skip-anim"
  "camp_ch3|--screen=camp --chapter=3 --skip-anim"
  "town_ch2|--screen=town --chapter=2 --skip-anim"
  "results|--screen=results --chapter=1 --skip-anim"
  "battle_2d_ch1|--screen=battle --chapter=1 --view=2d --settle=150 --skip-anim"
  "battle_3d_ch3|--screen=battle --chapter=3 --view=3d --settle=150 --skip-anim"
  "scene|--screen=scene --chapter=3 --still"
)
fail=0
for entry in "${SHOTS[@]}"; do
  name="${entry%%|*}"
  args="${entry#*|}"
  # shellcheck disable=SC2086
  "$GODOT" --path . -s res://tools/screenshot.gd -- $args --clean-saves --out="$OUT/$name.png" >/dev/null 2>&1
  if [[ ! -f "$OUT/$name.png" ]]; then
    echo "FAIL  $name: no screenshot"; fail=1; continue
  fi
  if [[ "${1:-}" == "--update" ]]; then
    cp "$OUT/$name.png" "$GOLD/$name.png"; echo "updated $name"; continue
  fi
  if [[ ! -f "$GOLD/$name.png" ]]; then
    echo "FAIL  $name: no golden image (run with --update)"; fail=1; continue
  fi
  res=$("$GODOT" --headless --path . -s res://tools/compare_images.gd -- --a="$OUT/$name.png" --b="$GOLD/$name.png" --diff="$OUT/${name}_diff.png" 2>/dev/null | grep "compare:")
  code=${PIPESTATUS[0]}
  if echo "$res" | grep -q "differ (max" && [[ $(echo "$res" | sed -E 's/compare: ([0-9.]+)%.*/\1/' | awk '{print ($1 <= 1.0)}') == 1 ]]; then
    echo "ok    $name: $res"
  else
    echo "FAIL  $name: $res (see $OUT/${name}_diff.png)"; fail=1
  fi
done
[[ "${1:-}" == "--update" ]] && exit 0
[[ $fail == 0 ]] && echo "ui snapshots: OK" || echo "ui snapshots: FAILED"
exit $fail
