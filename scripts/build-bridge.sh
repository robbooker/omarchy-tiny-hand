#!/usr/bin/env bash
# Build tiny-hand-bridge inside its pinned, network-isolated toolchain.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root_dir=$(dirname -- "$script_dir")
output_dir=${1:-}
image="tiny-hand-bridge-builder:debian-bookworm-20260820"

if [[ -z $output_dir || ! -d $output_dir ]]; then
  echo "usage: $0 EXISTING_OUTPUT_DIRECTORY" >&2
  exit 2
fi
command -v docker >/dev/null 2>&1 || {
  echo "Docker is required for the pinned release build." >&2
  exit 1
}

docker build --pull --platform linux/amd64 \
  --tag "$image" \
  "$root_dir/build/tiny-hand-bridge"

docker run --rm --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  --network none \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --tmpfs /tmp:rw,nosuid,nodev,noexec,size=32m \
  --mount "type=bind,src=$root_dir/src/tiny-hand-bridge.c,dst=/src/tiny-hand-bridge.c,readonly" \
  --mount "type=bind,src=$(cd -- "$output_dir" && pwd),dst=/out" \
  "$image"
