#!/usr/bin/env bash
set -euo pipefail

plugin_id="robbooker.tiny-hand"
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target_dir="$HOME/.config/omarchy/plugins/$plugin_id"
backup_dir="$HOME/.local/state/omarchy-tiny-hand/backups"
hypr_module="$HOME/.config/hypr/tiny_hand.lua"
hypr_main="$HOME/.config/hypr/hyprland.lua"
require_line='require("hypr.tiny_hand")'

for command_name in omarchy omarchy-shell hyprctl jq; do
  command -v "$command_name" >/dev/null || {
    echo "Missing required command: $command_name" >&2
    exit 1
  }
done

[[ -x "$source_dir/bin/tiny-hand-bridge" ]] || {
  echo "Missing executable bridge: $source_dir/bin/tiny-hand-bridge" >&2
  exit 1
}
omarchy plugin validate "$source_dir"

saved_entry=""
shell_config="$HOME/.config/omarchy/shell.json"
if [[ -f $shell_config ]]; then
  saved_entry=$(jq -c --arg id "$plugin_id" '[
    .bar.layout.left[]?, .bar.layout.center[]?, .bar.layout.right[]?, .plugins[]?
  ] | map(select(.id == $id)) | .[0] // empty' "$shell_config")
fi

if [[ $source_dir != "$target_dir" ]]; then
  mkdir -p "$backup_dir"
  stage_dir=$(mktemp -d "$backup_dir/stage.XXXXXX")
  mkdir -p "$stage_dir/assets" "$stage_dir/bin" \
    "$stage_dir/build/tiny-hand-bridge" "$stage_dir/scripts" \
    "$stage_dir/src" "$stage_dir/tests"
  install -m 0644 "$source_dir/manifest.json" "$stage_dir/manifest.json"
  install -m 0644 "$source_dir/Service.qml" "$stage_dir/Service.qml"
  install -m 0644 "$source_dir/BarWidget.qml" "$stage_dir/BarWidget.qml"
  install -m 0644 "$source_dir/Panel.qml" "$stage_dir/Panel.qml"
  install -m 0644 "$source_dir/PointerArt.qml" "$stage_dir/PointerArt.qml"
  install -m 0644 "$source_dir/README.md" "$stage_dir/README.md"
  install -m 0644 "$source_dir/LICENSE" "$stage_dir/LICENSE"
  install -m 0644 "$source_dir/CHANGELOG.md" "$stage_dir/CHANGELOG.md"
  install -m 0644 "$source_dir/THIRD_PARTY_NOTICES.md" "$stage_dir/THIRD_PARTY_NOTICES.md"
  install -m 0644 "$source_dir/SECURITY.md" "$stage_dir/SECURITY.md"
  install -m 0644 "$source_dir/RELEASING.md" "$stage_dir/RELEASING.md"
  install -m 0644 "$source_dir/MARKETPLACE_SUBMISSION.md" "$stage_dir/MARKETPLACE_SUBMISSION.md"
  install -m 0644 "$source_dir/Makefile" "$stage_dir/Makefile"
  install -m 0644 "$source_dir/assets/tiny-hand.svg" "$stage_dir/assets/tiny-hand.svg"
  install -m 0644 "$source_dir/preview.png" "$stage_dir/preview.png"
  install -m 0755 "$source_dir/bin/tiny-hand-bridge" "$stage_dir/bin/tiny-hand-bridge"
  install -m 0755 "$source_dir/scripts/install.sh" "$stage_dir/scripts/install.sh"
  install -m 0755 "$source_dir/scripts/uninstall.sh" "$stage_dir/scripts/uninstall.sh"
  install -m 0755 "$source_dir/scripts/build-bridge.sh" "$stage_dir/scripts/build-bridge.sh"
  install -m 0755 "$source_dir/scripts/verify-bridge.sh" "$stage_dir/scripts/verify-bridge.sh"
  install -m 0644 "$source_dir/build/tiny-hand-bridge/Dockerfile" "$stage_dir/build/tiny-hand-bridge/Dockerfile"
  install -m 0755 "$source_dir/build/tiny-hand-bridge/build-helper.sh" "$stage_dir/build/tiny-hand-bridge/build-helper.sh"
  install -m 0644 "$source_dir/src/tiny-hand-bridge.c" "$stage_dir/src/tiny-hand-bridge.c"
  install -m 0755 "$source_dir/tests/test_bridge.sh" "$stage_dir/tests/test_bridge.sh"
  install -m 0755 "$source_dir/tests/test_plugin.sh" "$stage_dir/tests/test_plugin.sh"

  if [[ -e $target_dir ]]; then
    backup="$backup_dir/plugin.$(date +%Y%m%d%H%M%S).$$"
    mv -- "$target_dir" "$backup"
    echo "Backed up the previous plugin to $backup"
  fi
  mv -- "$stage_dir" "$target_dir"
fi

# Versions before 0.5 used a persistent Hyprland Lua include. Runtime binding
# handles now belong to the helper process, so upgrade that legacy integration
# away while preserving a timestamped copy of the user's main config.
legacy_hypr_changed=false
if [[ -f $hypr_main ]] && grep -Fqx -- "$require_line" "$hypr_main"; then
  cp -- "$hypr_main" "$hypr_main.bak.$(date +%Y%m%d%H%M%S)"
  temp_file=$(mktemp "${TMPDIR:-/tmp}/tiny-hand-hyprland.XXXXXX")
  awk -v require_line="$require_line" '
    $0 == "-- Tiny Hand cursor integration." { next }
    $0 == require_line { next }
    { print }
  ' "$hypr_main" >"$temp_file"
  install -m 0644 "$temp_file" "$hypr_main"
  rm -f -- "$temp_file"
  legacy_hypr_changed=true
fi
if [[ -f $hypr_module ]]; then
  rm -f -- "$hypr_module"
  legacy_hypr_changed=true
fi

omarchy plugin validate "$target_dir"
omarchy-shell shell rescanPlugins >/dev/null
omarchy plugin disable "$plugin_id" >/dev/null 2>&1 || true
omarchy plugin enable "$plugin_id" --section right

if [[ -n $saved_entry ]]; then
  while IFS=$'\t' read -r setting_key setting_value; do
    omarchy bar set "$plugin_id" "$setting_key" "$setting_value" --json >/dev/null
  done < <(jq -r 'to_entries[] | select(.key != "id") | [.key, (.value | tojson)] | @tsv' <<<"$saved_entry")
fi

if [[ $legacy_hypr_changed == true ]]; then
  hyprctl reload >/dev/null
fi

errors=$(hyprctl configerrors)
if [[ -n $errors ]]; then
  printf 'Hyprland reported configuration errors:\n%s\n' "$errors" >&2
  exit 1
fi

omarchy restart shell

echo "Tiny Hand is installed and active. Toggle it with Super+Alt+P."
