#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

jq -e '
  .version == "0.5.2"
  and .license == "MIT"
  and (.kinds | index("service") != null)
  and (.kinds | index("bar-widget") != null)
  and .entryPoints.service == "Service.qml"
  and .entryPoints.barWidget == "BarWidget.qml"
  and .barWidget.defaultSection == "right"
  and .barWidget.defaults.jazzHands == true
' "$root_dir/manifest.json" >/dev/null

for style in tiny-hand middle-finger cat-paw pixel-gauntlet neon-comet omarchy-blade; do
  rg -q "\"$style\"" "$root_dir/Service.qml"
  rg -q "\"$style\"" "$root_dir/PointerArt.qml"
done

rg -q 'styleKey: "jazz-hand"' "$root_dir/Service.qml"
rg -q 'Triple-click jazz hands' "$root_dir/Panel.qml"
rg -q 'focusTarget: keyCatcher' "$root_dir/Panel.qml"
rg -q 'pointerSuspendedForMenu' "$root_dir/Panel.qml"
rg -q 'readonly property bool barPopoutOpen:' "$root_dir/Service.qml"
rg -q 'shell.bar.activePopout !== null' "$root_dir/Service.qml"
rg -q 'readonly property bool loaderPanelOpen:' "$root_dir/Service.qml"
rg -q 'loader.item.opened === undefined || loader.item.opened === true' "$root_dir/Service.qml"
rg -q 'readonly property bool nativeCursorFallback:.*omasnapOpen' "$root_dir/Service.qml"
rg -q 'openlayer>>omasnap' "$root_dir/src/tiny-hand-bridge.c"
rg -q 'closelayer>>omasnap' "$root_dir/src/tiny-hand-bridge.c"
rg -q 'running: root.pointerEngaged' "$root_dir/Service.qml"
rg -q 'visible: root.pointerEngaged' "$root_dir/Service.qml"
rg -q 'onTabRequested' "$root_dir/Panel.qml"
rg -q 'Tiny Hand click observer' "$root_dir/src/tiny-hand-bridge.c"
rg -q 'omarchy_tiny_hand_hotkey_bind' "$root_dir/src/tiny-hand-bridge.c"
rg -q '\[root.bridgePath, "hotkey"\]' "$root_dir/Service.qml"

[[ ! -e "$root_dir/hypr/tiny_hand.lua" ]] || {
  echo "legacy persistent Hyprland integration is still packaged" >&2
  exit 1
}
if rg -q 'printf.*require_line.*hypr_main' "$root_dir/scripts/install.sh"; then
  echo "installer still adds a persistent Hyprland require" >&2
  exit 1
fi

for file in \
  LICENSE README.md CHANGELOG.md THIRD_PARTY_NOTICES.md SECURITY.md \
  RELEASING.md MARKETPLACE_SUBMISSION.md preview.png \
  scripts/build-bridge.sh scripts/verify-bridge.sh \
  build/tiny-hand-bridge/Dockerfile build/tiny-hand-bridge/build-helper.sh \
  .github/workflows/build-bridge.yml .github/workflows/test-plugin.yml \
  .github/workflows/verify-bridge.yml; do
  [[ -s "$root_dir/$file" ]] || { echo "missing publication file: $file" >&2; exit 1; }
done

for file in Service.qml BarWidget.qml Panel.qml PointerArt.qml; do
  [[ -s "$root_dir/$file" ]] || { echo "missing $file" >&2; exit 1; }
done

echo "plugin tests passed"
