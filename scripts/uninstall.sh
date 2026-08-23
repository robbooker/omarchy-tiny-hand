#!/usr/bin/env bash
set -euo pipefail

plugin_id="robbooker.tiny-hand"
hypr_module="$HOME/.config/hypr/tiny_hand.lua"
hypr_main="$HOME/.config/hypr/hyprland.lua"
require_line='require("hypr.tiny_hand")'

omarchy-shell -q tiny-hand disable || true
hyprctl eval 'hl.config({ cursor = { invisible = false } })' >/dev/null 2>&1 || true
omarchy plugin disable "$plugin_id" >/dev/null 2>&1 || true

if [[ -f $hypr_main ]] && grep -Fqx -- "$require_line" "$hypr_main"; then
  backup="$hypr_main.bak.$(date +%Y%m%d%H%M%S)"
  cp -- "$hypr_main" "$backup"
  temp_file=$(mktemp "${TMPDIR:-/tmp}/tiny-hand-hyprland.XXXXXX")
  awk -v require_line="$require_line" '
    $0 == "-- Tiny Hand cursor integration." { next }
    $0 == require_line { next }
    { print }
  ' "$hypr_main" >"$temp_file"
  install -m 0644 "$temp_file" "$hypr_main"
  rm -f -- "$temp_file"
fi

rm -f -- "$hypr_module"
hyprctl reload >/dev/null 2>&1 || true

omarchy plugin remove "$plugin_id" --yes

cat <<EOF
Tiny Hand was disabled and removed. Its runtime bindings and any legacy
Hyprland integration were cleaned up, and the native cursor was restored.
EOF
