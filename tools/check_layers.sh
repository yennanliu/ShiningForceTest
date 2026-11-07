#!/usr/bin/env bash
# Enforce architecture rules (doc/02-eng-design.md §2):
#  1. core/ never touches Nodes, scenes, input or view/
#  2. the only randomness in core/ is core/battle/rng.gd
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
code_only() { grep -vE '^[^:]+:[0-9]+:[[:space:]]*#'; }

hits=$(grep -rnE 'extends Node|Node2D|Node3D|SceneTree|get_tree\(|Input\.|res://view/' core --include='*.gd' | code_only || true)
if [[ -n "$hits" ]]; then
  echo "ERROR: core/ must not use Nodes, scenes, input or view/:"; echo "$hits"; fail=1
fi

hits=$(grep -rnE '(^|[^_[:alnum:]])(randf|randi|randf_range|randi_range|randomize)\(' core --include='*.gd' \
  | grep -v '^core/battle/rng.gd:' | code_only || true)
if [[ -n "$hits" ]]; then
  echo "ERROR: randomness outside core/battle/rng.gd:"; echo "$hits"; fail=1
fi

[[ $fail -eq 0 ]] && echo "layer check: OK"
exit $fail
