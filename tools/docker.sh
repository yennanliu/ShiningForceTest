#!/usr/bin/env bash
# Run project tasks inside the pinned Godot container. No local Godot needed.
#   tools/docker.sh test [filter]   layer check + tests
#   tools/docker.sh export          build/Banner.x86_64 (Linux) + smoke test
#   tools/docker.sh shell           interactive shell in the container
set -euo pipefail
cd "$(dirname "$0")/.."
V=$(cat .godot-version)
task="${1:-test}"; shift || true

target=base
[[ "$task" == "export" ]] && target=export
image="banner-godot:${V}-${target}"
platform=()
# Exported Linux builds are x86_64, so build them on amd64 (emulated on Apple Silicon).
[[ "$task" == "export" ]] && platform=(--platform linux/amd64)

docker build -q "${platform[@]+"${platform[@]}"}" --target "$target" --build-arg GODOT_VERSION="$V" -t "$image" . >/dev/null
run() { docker run --rm "${platform[@]+"${platform[@]}"}" -v "$PWD":/project "$image" "$@"; }

case "$task" in
  test)   run bash -c "tools/check_layers.sh && tools/test.sh ${1:-}" ;;
  export) run bash -c 'mkdir -p build && godot --headless --path . --import >/dev/null 2>&1; godot --headless --path . --export-release Linux build/Banner.x86_64 && build/Banner.x86_64 --headless --quit-after 60 && echo "export + smoke: OK"' ;;
  shell)  docker run --rm -it -v "$PWD":/project "$image" bash ;;
  *) echo "usage: tools/docker.sh test|export|shell"; exit 2 ;;
esac
