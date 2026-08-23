#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
bridge="$root_dir/bin/tiny-hand-bridge"

actual=$("$bridge" parse '{"x": 12, "y": -3.5}')
[[ $actual == "12.000 -3.500" ]] || {
  echo "unexpected parser output: $actual" >&2
  exit 1
}

if "$bridge" parse '{"x": 12}' >/dev/null 2>&1; then
  echo "parser accepted a response without y" >&2
  exit 1
fi

# A click while the service is stopped is intentionally a quiet no-op.
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}" \
HYPRLAND_INSTANCE_SIGNATURE="test-session" \
  "$bridge" click

echo "bridge tests passed"
