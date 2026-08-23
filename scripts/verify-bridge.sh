#!/usr/bin/env bash
# Rebuild with the pinned toolchain and compare with the committed executable.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root_dir=$(dirname -- "$script_dir")
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT

echo "source:"
sha256sum "$root_dir/src/tiny-hand-bridge.c"
echo "committed binary:"
sha256sum "$root_dir/bin/tiny-hand-bridge"

"$script_dir/build-bridge.sh" "$work_dir"

echo "rebuilt binary:"
sha256sum "$work_dir/tiny-hand-bridge"
if cmp --silent "$root_dir/bin/tiny-hand-bridge" "$work_dir/tiny-hand-bridge"; then
  echo "MATCH: bundled helper is byte-for-byte reproducible"
else
  echo "MISMATCH: bundled helper differs from the pinned rebuild" >&2
  exit 1
fi
