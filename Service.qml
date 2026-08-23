import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  Component.onDestruction: {
    bridge.running = false
    hotkeyBridge.running = false
    if (bridgePath !== "") Quickshell.execDetached([bridgePath, "cleanup"])
  }

  property var shell: null
  property var manifest: null
  readonly property string pluginDir: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
  readonly property string bridgePath: pluginDir === "" ? "" : pluginDir + "/bin/tiny-hand-bridge"

  property bool active: true
  property bool positionValid: false
  property real cursorX: 0
  property real cursorY: 0
  property double lastClickAt: 0
  property int clickStreak: 0
  property int jazzCount: 0
  property string bridgeError: ""
  property string hotkeyError: ""
  property bool omasnapOpen: false

  property string pointerStyle: "tiny-hand"
  property string pointerSize: "Giant"
  property bool themeAware: true
  property bool clickEffects: true
  property bool jazzHands: true

  // Bar widgets coordinate their interactive popouts through activePopout;
  // loader-backed panels use openPanelIds. External overlay applications such
  // as Omasnap are reported by the always-running hotkey helper. Tiny Hand's
  // layer sits below these surfaces, so yield to Hyprland's native cursor for
  // their entire interactive lifetime instead of leaving no visible pointer.
  function hasOpenPanel(panelIds, panelLoaders) {
    var ids = panelIds || {}
    var loaders = panelLoaders || {}
    for (var id in ids) {
      if (ids[id] !== true) continue

      // openPanelIds is the loader's lifetime signal, not necessarily the
      // panel's visible state. Some panels close themselves without asking
      // the shell to unload them, leaving the id behind. Prefer the panel's
      // opened property once its Loader has resolved so a stale loader cannot
      // strand Tiny Hand in native-cursor mode.
      var loader = loaders[id]
      if (!loader || !loader.item) return true
      if (loader.item.opened === undefined || loader.item.opened === true) return true
    }
    return false
  }

  readonly property bool barPopoutOpen: !!(shell && shell.bar && shell.bar.activePopout !== null)
  readonly property bool loaderPanelOpen: !!(shell && hasOpenPanel(shell.openPanelIds, shell.panelLoaders))
  readonly property bool nativeCursorFallback: active && (barPopoutOpen || loaderPanelOpen || omasnapOpen)
  readonly property bool pointerEngaged: active && !nativeCursorFallback

  readonly property var spec: styleSpec(pointerStyle)
  readonly property real sizeFactor: sizeScale(pointerSize)
  readonly property real pointerWidth: spec.width * sizeFactor
  readonly property real pointerHeight: spec.height * sizeFactor
  readonly property real hotspotX: spec.hotspotX * sizeFactor
  readonly property real hotspotY: spec.hotspotY * sizeFactor
  readonly property color artFill: themeAware ? Color.foreground : "#fff4d6"
  readonly property color artShade: themeAware ? Qt.darker(Color.foreground, 1.22) : "#ffc987"
  readonly property color artOutline: themeAware ? Color.background : "#171922"
  readonly property color artAccent: themeAware ? Color.accent : "#ff9f1c"
  readonly property color artUrgent: themeAware ? Color.urgent : "#ff5d73"

  signal poked(int energy)
  signal jazzed()
  signal settingsApplied()

  function styleSpec(key) {
    var catalog = {
      "tiny-hand": { width: 112, height: 126, hotspotX: 55, hotspotY: 6 },
      "middle-finger": { width: 92, height: 118, hotspotX: 46, hotspotY: 4 },
      "cat-paw": { width: 74, height: 82, hotspotX: 37, hotspotY: 4 },
      "pixel-gauntlet": { width: 70, height: 78, hotspotX: 4, hotspotY: 4 },
      "neon-comet": { width: 64, height: 64, hotspotX: 3, hotspotY: 3 },
      "omarchy-blade": { width: 60, height: 82, hotspotX: 30, hotspotY: 3 }
    }
    return catalog[key] || catalog["tiny-hand"]
  }

  function validStyle(value) {
    return ["tiny-hand", "middle-finger", "cat-paw", "pixel-gauntlet", "neon-comet", "omarchy-blade"].indexOf(String(value)) >= 0
      ? String(value) : "tiny-hand"
  }

  function validSize(value) {
    return ["Small", "Medium", "Large", "Giant"].indexOf(String(value)) >= 0 ? String(value) : "Giant"
  }

  function sizeScale(value) {
    var scales = { Small: 0.58, Medium: 0.72, Large: 0.86, Giant: 1.0 }
    return scales[value] || 1.0
  }

  function applySettings(values) {
    var next = values || {}
    pointerStyle = validStyle(next.style === undefined ? pointerStyle : next.style)
    pointerSize = validSize(next.size === undefined ? pointerSize : next.size)
    themeAware = next.themeAware === undefined ? themeAware : next.themeAware === true
    clickEffects = next.clickEffects === undefined ? clickEffects : next.clickEffects === true
    jazzHands = next.jazzHands === undefined ? jazzHands : next.jazzHands === true
    if (next.enabled !== undefined) setActive(next.enabled === true)
    settingsApplied()
  }

  function currentSettings() {
    return { style: pointerStyle, size: pointerSize, themeAware: themeAware, clickEffects: clickEffects, jazzHands: jazzHands, enabled: active }
  }

  function handleBridgeLine(rawLine) {
    var line = String(rawLine || "").trim()
    if (line === "") return
    var fields = line.split(/\s+/)
    if (fields[0] === "M" && fields.length >= 3) {
      var nextX = Number(fields[1])
      var nextY = Number(fields[2])
      if (!isNaN(nextX) && !isNaN(nextY)) {
        cursorX = nextX
        cursorY = nextY
        positionValid = true
      }
      return
    }
    if (fields[0] === "C") triggerPoke()
  }

  function handleHotkeyLine(rawLine) {
    var fields = String(rawLine || "").trim().split(/\s+/)
    if (fields[0] === "O" && fields.length >= 2) omasnapOpen = fields[1] === "1"
  }

  function triggerPoke() {
    var now = Date.now()
    clickStreak = now - lastClickAt < 360 ? Math.min(4, clickStreak + 1) : 1
    lastClickAt = now
    poked(clickStreak)
    if (clickStreak === 3 && jazzHands) {
      jazzCount++
      jazzed()
    }
  }

  function setActive(value) {
    active = value
    if (!active) { positionValid = false; clickStreak = 0 }
  }

  Process {
    id: bridge
    command: root.bridgePath === "" ? [] : [root.bridgePath, "stream"]
    running: root.pointerEngaged && root.bridgePath !== ""
    stdout: SplitParser { splitMarker: "\n"; onRead: function(line) { root.handleBridgeLine(line) } }
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        var message = String(line || "").trim()
        if (message !== "") root.bridgeError = message
      }
    }
    onStarted: { root.bridgeError = ""; bridgeRestart.stop() }
    onExited: function(exitCode) {
      root.positionValid = false
      if (root.pointerEngaged) { root.bridgeError = "bridge exited with status " + exitCode; bridgeRestart.restart() }
    }
  }

  Process {
    id: hotkeyBridge
    command: root.bridgePath === "" ? [] : [root.bridgePath, "hotkey"]
    running: root.bridgePath !== ""
    stdout: SplitParser { splitMarker: "\n"; onRead: function(line) { root.handleHotkeyLine(line) } }
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        var message = String(line || "").trim()
        if (message !== "") root.hotkeyError = message
      }
    }
    onStarted: { root.hotkeyError = ""; hotkeyRestart.stop() }
    onExited: function(exitCode) {
      if (root.bridgePath !== "") {
        root.hotkeyError = "hotkey helper exited with status " + exitCode
        hotkeyRestart.restart()
      }
    }
  }

  Timer {
    id: bridgeRestart
    interval: 750
    onTriggered: if (root.pointerEngaged && root.bridgePath !== "" && !bridge.running) bridge.running = true
  }

  Timer {
    id: hotkeyRestart
    interval: 750
    onTriggered: if (root.bridgePath !== "" && !hotkeyBridge.running) hotkeyBridge.running = true
  }

  IpcHandler {
    target: "tiny-hand"
    function click(): string { root.triggerPoke(); return "ok" }
    function enable(): string { root.setActive(true); return "enabled" }
    function disable(): string { root.setActive(false); return "disabled" }
    function toggle(): string { root.setActive(!root.active); return root.active ? "enabled" : "disabled" }
    function style(name: string): string { root.pointerStyle = root.validStyle(name); return root.pointerStyle }
    function size(name: string): string { root.pointerSize = root.validSize(name); return root.pointerSize }
    function reset(): string {
      root.applySettings({ style: "tiny-hand", size: "Giant", themeAware: true, clickEffects: true, jazzHands: true, enabled: true })
      return JSON.stringify(root.currentSettings())
    }
    function status(): string {
      return JSON.stringify({
        active: root.active, bridgeRunning: bridge.running, hotkeyRunning: hotkeyBridge.running,
        pointerEngaged: root.pointerEngaged, nativeCursorFallback: root.nativeCursorFallback,
        barPopoutOpen: root.barPopoutOpen, loaderPanelOpen: root.loaderPanelOpen,
        omasnapOpen: root.omasnapOpen,
        positionValid: root.positionValid,
        x: root.cursorX, y: root.cursorY, clickStreak: root.clickStreak, jazzCount: root.jazzCount,
        style: root.pointerStyle, size: root.pointerSize, themeAware: root.themeAware,
        clickEffects: root.clickEffects, jazzHands: root.jazzHands,
        width: root.pointerWidth, height: root.pointerHeight,
        error: root.bridgeError, hotkeyError: root.hotkeyError
      })
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData
      visible: root.pointerEngaged
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}
      WlrLayershell.namespace: "tiny-hand"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
      readonly property real logicalWidth: hyprMonitor ? hyprMonitor.width / Math.max(1, hyprMonitor.scale) : width
      readonly property real logicalHeight: hyprMonitor ? hyprMonitor.height / Math.max(1, hyprMonitor.scale) : height
      readonly property real localCursorX: hyprMonitor ? root.cursorX - hyprMonitor.x : -1000
      readonly property real localCursorY: hyprMonitor ? root.cursorY - hyprMonitor.y : -1000
      readonly property bool pointerHere: root.positionValid && hyprMonitor
        && localCursorX >= 0 && localCursorY >= 0 && localCursorX < logicalWidth && localCursorY < logicalHeight
      property real press: 0
      property real burst: 1
      property real jazzReveal: 0
      property real jazzWave: 0
      property int energy: 1

      Connections {
        target: root
        function onPoked(nextEnergy) {
          if (!panel.pointerHere) return
          panel.energy = nextEnergy
          pressAnimation.restart()
          if (root.clickEffects) burstAnimation.restart()
        }
        function onJazzed() {
          if (!panel.pointerHere) return
          jazzRevealAnimation.restart()
          jazzWaveAnimation.restart()
        }
      }

      SequentialAnimation {
        id: pressAnimation
        NumberAnimation { target: panel; property: "press"; from: 0; to: 1; duration: Math.max(38, 64 - panel.energy * 6); easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "press"; to: 0; duration: 125 + panel.energy * 12; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
      }
      NumberAnimation {
        id: burstAnimation
        target: panel; property: "burst"; from: 0; to: 1
        duration: 210 + panel.energy * 35; easing.type: Easing.OutCubic
      }
      SequentialAnimation {
        id: jazzRevealAnimation
        NumberAnimation { target: panel; property: "jazzReveal"; from: 0; to: 1; duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.7 }
        PauseAnimation { duration: 650 }
        NumberAnimation { target: panel; property: "jazzReveal"; to: 0; duration: 180; easing.type: Easing.InBack }
      }
      NumberAnimation {
        id: jazzWaveAnimation
        target: panel; property: "jazzWave"; from: 0; to: 6
        duration: 980; easing.type: Easing.Linear
      }

      Item {
        id: pointer
        visible: panel.pointerHere
        x: Math.round(panel.localCursorX - root.hotspotX)
        y: Math.round(panel.localCursorY - root.hotspotY + panel.press * (3 + panel.energy))
        width: root.pointerWidth
        height: root.pointerHeight
        transform: [
          Scale {
            origin.x: root.hotspotX; origin.y: root.hotspotY
            xScale: 1 + panel.press * (0.055 + panel.energy * 0.012)
            yScale: 1 - panel.press * (0.10 + panel.energy * 0.025)
          },
          Rotation {
            origin.x: root.hotspotX; origin.y: root.hotspotY
            angle: -panel.press * Math.min(5, panel.energy * 1.25)
          }
        ]

        Repeater {
          model: root.clickEffects ? 8 : 0
          delegate: Rectangle {
            required property int index
            readonly property real radians: index * Math.PI / 4
            readonly property real distance: 18 + panel.burst * (22 + panel.energy * 3)
            width: 3 + panel.energy * 0.45
            height: 9 + panel.energy * 1.8
            radius: width / 2
            color: index % 2 === 0 ? root.artAccent : root.artFill
            opacity: Math.max(0, 1 - panel.burst * 1.15)
            x: root.hotspotX + Math.cos(radians) * distance - width / 2
            y: root.hotspotY + Math.sin(radians) * distance - height / 2
            rotation: index * 45 + 90
          }
        }

        PointerArt {
          anchors.fill: parent
          styleKey: root.pointerStyle
          fillColor: root.artFill
          shadeColor: root.artShade
          outlineColor: root.artOutline
          accentColor: root.artAccent
          urgentColor: root.artUrgent
        }

        Item {
          anchors.fill: parent
          z: 2
          opacity: panel.jazzReveal
          visible: opacity > 0

          PointerArt {
            readonly property real artWidth: Math.max(52, root.pointerWidth * 0.68)
            width: artWidth
            height: artWidth * 1.07
            x: -width * (0.35 + panel.jazzReveal * 0.45)
            y: root.hotspotY + root.pointerHeight * 0.08 - panel.jazzReveal * height * 0.22
            rotation: -20 + Math.sin(panel.jazzWave * Math.PI) * 15
            scale: 0.2 + panel.jazzReveal * 0.8
            styleKey: "jazz-hand"
            fillColor: root.artFill
            shadeColor: root.artShade
            outlineColor: root.artOutline
            accentColor: root.artAccent
            urgentColor: root.artUrgent
          }

          PointerArt {
            readonly property real artWidth: Math.max(52, root.pointerWidth * 0.68)
            width: artWidth
            height: artWidth * 1.07
            x: pointer.width - width * (0.65 - panel.jazzReveal * 0.45)
            y: root.hotspotY + root.pointerHeight * 0.08 - panel.jazzReveal * height * 0.22
            rotation: 20 - Math.sin(panel.jazzWave * Math.PI) * 15
            scale: 0.2 + panel.jazzReveal * 0.8
            styleKey: "jazz-hand"
            fillColor: root.artFill
            shadeColor: root.artShade
            outlineColor: root.artOutline
            accentColor: root.artAccent
            urgentColor: root.artUrgent
          }
        }
      }
    }
  }
}
