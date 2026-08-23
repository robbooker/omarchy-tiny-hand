import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "robbooker.tiny-hand"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property string selectedStyle: setting("style", "tiny-hand")
  readonly property bool configuredEnabled: setting("enabled", true) === true
  readonly property bool pointerActive: service ? service.active === true : configuredEnabled

  function pushSettings() {
    if (service && typeof service.applySettings === "function") service.applySettings(settings)
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePointer() {
    if (service && typeof service.setActive === "function") service.setActive(!service.active)
  }

  function cycleStyle() {
    var keys = ["tiny-hand", "middle-finger", "cat-paw", "pixel-gauntlet", "neon-comet", "omarchy-blade"]
    var index = keys.indexOf(selectedStyle)
    var next = keys[(index + 1 + keys.length) % keys.length]
    var entry = { id: moduleName }
    for (var key in settings) if (key !== "id") entry[key] = settings[key]
    entry.style = next
    settings = entry
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, entry)
    pushSettings()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: { injectPanel(); pushLater.restart() }
  onSettingsChanged: { injectPanel(); pushLater.restart() }
  onServiceChanged: pushLater.restart()
  Component.onCompleted: pushLater.restart()

  Timer {
    id: pushLater
    interval: 25
    repeat: false
    onTriggered: root.pushSettings()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.pointerActive
    tooltipText: root.pointerActive ? "Tiny Hand settings · middle-click to hide" : "Tiny Hand is hidden · middle-click to show"
    iconComponent: Component {
      PointerArt {
        styleKey: root.selectedStyle
        fillColor: root.bar ? root.bar.barForeground : Color.foreground
        shadeColor: Qt.darker(fillColor, 1.25)
        outlineColor: root.bar ? root.bar.background : Color.background
        accentColor: Color.accent
        urgentColor: root.bar ? root.bar.urgent : Color.urgent
        lineScale: 0.72
      }
    }
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.togglePointer()
      else if (b === Qt.RightButton) root.cycleStyle()
      else root.togglePanel()
    }
  }
}
