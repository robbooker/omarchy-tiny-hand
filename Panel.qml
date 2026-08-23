import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "robbooker.tiny-hand"
  ipcTarget: "tiny-hand-settings"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null

  property string draftStyle: "tiny-hand"
  property string draftSize: "Giant"
  property bool draftThemeAware: true
  property bool draftClickEffects: true
  property bool draftJazzHands: true
  property bool draftEnabled: true
  property bool initialDraftEnabled: true
  property string saveMessage: ""

  // The settings popup is above the click-through pointer overlay. Suspend the
  // pointer for the popup's lifetime so Hyprland restores its native cursor,
  // then restore the exact runtime state that existed before the menu opened.
  property bool pointerSuspendedForMenu: false
  property bool wasActiveBeforeOpen: false
  property bool resumePointerAfterClose: false

  property int keyboardIndex: 0
  readonly property int keyboardControlCount: 13
  readonly property var sizes: ["Small", "Medium", "Large", "Giant"]
  readonly property var styles: [
    { key: "tiny-hand", name: "Tiny Hand", note: "Giant classic" },
    { key: "middle-finger", name: "Middle Finger", note: "Large & loud" },
    { key: "cat-paw", name: "Cat Paw", note: "Medium" },
    { key: "pixel-gauntlet", name: "Pixel Gauntlet", note: "Compact" },
    { key: "neon-comet", name: "Neon Comet", note: "Small & bright" },
    { key: "omarchy-blade", name: "Omarchy Blade", note: "Slim precision" }
  ]

  function readSetting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function loadDraft() {
    draftStyle = String(readSetting("style", "tiny-hand"))
    draftSize = String(readSetting("size", "Giant"))
    draftThemeAware = readSetting("themeAware", true) === true
    draftClickEffects = readSetting("clickEffects", true) === true
    draftJazzHands = readSetting("jazzHands", true) === true
    draftEnabled = readSetting("enabled", true) === true
    initialDraftEnabled = draftEnabled
    saveMessage = ""
    var selected = -1
    for (var i = 0; i < styles.length; i++) if (styles[i].key === draftStyle) selected = i
    keyboardIndex = selected >= 0 ? selected : 0
  }

  function suspendPointer() {
    if (pointerSuspendedForMenu || !service) return
    wasActiveBeforeOpen = service.active === true
    resumePointerAfterClose = wasActiveBeforeOpen
    pointerSuspendedForMenu = true
    if (service.active && typeof service.setActive === "function") service.setActive(false)
  }

  function restorePointer() {
    if (!pointerSuspendedForMenu) return
    var shouldResume = resumePointerAfterClose
    pointerSuspendedForMenu = false
    wasActiveBeforeOpen = false
    resumePointerAfterClose = false
    if (shouldResume && service && typeof service.setActive === "function") service.setActive(true)
  }

  function open() {
    if (opened) return
    loadDraft()
    suspendPointer()
    controller.show()
  }

  function close() {
    controller.hide()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function defaults() {
    draftStyle = "tiny-hand"
    draftSize = "Giant"
    draftThemeAware = true
    draftClickEffects = true
    draftJazzHands = true
    draftEnabled = true
    saveMessage = "Defaults ready — press Save"
  }

  function save() {
    var enabledWasChanged = draftEnabled !== initialDraftEnabled
    var entry = {
      id: moduleName,
      style: draftStyle,
      size: draftSize,
      themeAware: draftThemeAware,
      clickEffects: draftClickEffects,
      jazzHands: draftJazzHands,
      enabled: draftEnabled
    }
    settings = entry
    if (hostWidget && "settings" in hostWidget) hostWidget.settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, entry)

    // Saving may apply `enabled` immediately. Keep the native cursor visible
    // while this panel remains open and remember what should happen on close.
    if (enabledWasChanged) resumePointerAfterClose = draftEnabled
    else resumePointerAfterClose = wasActiveBeforeOpen
    if (service && typeof service.applySettings === "function") {
      service.applySettings(entry)
      if (opened && service.active && typeof service.setActive === "function") service.setActive(false)
    }
    initialDraftEnabled = draftEnabled
    saveMessage = "Saved"
  }

  function setKeyboardIndex(value) {
    var count = keyboardControlCount
    keyboardIndex = ((Number(value) % count) + count) % count
    Qt.callLater(ensureKeyboardVisible)
  }

  function moveTab(direction) {
    setKeyboardIndex(keyboardIndex + (direction < 0 ? -1 : 1))
  }

  function cycleSize(direction) {
    var current = sizes.indexOf(draftSize)
    if (current < 0) current = sizes.length - 1
    draftSize = sizes[((current + direction) % sizes.length + sizes.length) % sizes.length]
    saveMessage = ""
  }

  function setToggleAt(index, value) {
    if (index === 7) draftThemeAware = value
    else if (index === 8) draftClickEffects = value
    else if (index === 9) draftJazzHands = value
    else if (index === 10) draftEnabled = value
    saveMessage = ""
  }

  function toggleAt(index) {
    if (index === 7) setToggleAt(index, !draftThemeAware)
    else if (index === 8) setToggleAt(index, !draftClickEffects)
    else if (index === 9) setToggleAt(index, !draftJazzHands)
    else if (index === 10) setToggleAt(index, !draftEnabled)
  }

  function moveKeyboard(dx, dy) {
    var index = keyboardIndex
    if (index < 6) {
      if (dx !== 0) {
        var rowStart = Math.floor(index / 3) * 3
        var column = index - rowStart
        setKeyboardIndex(rowStart + ((column + (dx < 0 ? -1 : 1) + 3) % 3))
      } else if (dy > 0) {
        setKeyboardIndex(index < 3 ? index + 3 : 6)
      } else if (dy < 0) {
        setKeyboardIndex(index >= 3 ? index - 3 : 12)
      }
      return
    }

    if (index === 6 && dx !== 0) {
      cycleSize(dx < 0 ? -1 : 1)
      return
    }
    if (index >= 7 && index <= 10 && dx !== 0) {
      setToggleAt(index, dx > 0)
      return
    }
    if (index >= 11 && dx !== 0) {
      setKeyboardIndex(index === 11 ? 12 : 11)
      return
    }
    if (dy !== 0) setKeyboardIndex(index + (dy < 0 ? -1 : 1))
  }

  function activateKeyboard() {
    var index = keyboardIndex
    if (index < 6) {
      draftStyle = styles[index].key
      saveMessage = ""
    } else if (index === 6) cycleSize(1)
    else if (index >= 7 && index <= 10) toggleAt(index)
    else if (index === 11) defaults()
    else if (index === 12) save()
  }

  function keyboardTarget() {
    if (keyboardIndex < 6) return styleRepeater.itemAt(keyboardIndex)
    if (keyboardIndex === 6) return sizeDropdown
    if (keyboardIndex === 7) return themeToggle
    if (keyboardIndex === 8) return effectsToggle
    if (keyboardIndex === 9) return jazzToggle
    if (keyboardIndex === 10) return enabledToggle
    if (keyboardIndex === 11) return resetButton
    return saveButton
  }

  function ensureKeyboardVisible() {
    var target = keyboardTarget()
    if (!target || !settingsScroll || settingsScroll.height <= 0) return
    var point = target.mapToItem(settingsScroll.contentItem, 0, 0)
    var top = point.y - Style.space(10)
    var bottom = point.y + target.height + Style.space(10)
    if (top < settingsScroll.contentY) settingsScroll.contentY = Math.max(0, top)
    else if (bottom > settingsScroll.contentY + settingsScroll.height)
      settingsScroll.contentY = Math.max(0, Math.min(
        Math.max(0, settingsScroll.contentHeight - settingsScroll.height),
        bottom - settingsScroll.height))
  }

  function keyboardLabel() {
    if (keyboardIndex < 6) return "Style: " + styles[keyboardIndex].name
    if (keyboardIndex === 6) return "Size: " + draftSize
    if (keyboardIndex === 7) return "Theme-aware colors"
    if (keyboardIndex === 8) return "Click fireworks"
    if (keyboardIndex === 9) return "Triple-click jazz hands"
    if (keyboardIndex === 10) return "Start enabled"
    if (keyboardIndex === 11) return "Reset"
    return "Save"
  }

  onOpenedChanged: {
    if (opened) Qt.callLater(function() { keyCatcher.forceActiveFocus(); ensureKeyboardVisible() })
    else restorePointer()
  }
  onServiceChanged: if (opened && !pointerSuspendedForMenu) suspendPointer()

  Connections {
    target: root.service
    function onActiveChanged() {
      // BarWidget reapplies saved settings after Save/config reload. Do not
      // let that hide the native cursor until this popup has actually closed.
      if (root.opened && root.pointerSuspendedForMenu && root.service && root.service.active)
        Qt.callLater(function() {
          if (root.opened && root.service && root.service.active) root.service.setActive(false)
        })
    }
  }

  IpcHandler {
    target: "tiny-hand-settings"
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function show(): string { root.open(); return "ok" }
    function hide(): string { root.close(); return "ok" }
    function toggle(): string { root.toggle(); return "ok" }
    function status(): string {
      return JSON.stringify({
        opened: root.opened,
        keyboardIndex: root.keyboardIndex,
        keyboardLabel: root.keyboardLabel(),
        pointerSuspended: root.pointerSuspendedForMenu,
        resumePointerAfterClose: root.resumePointerAfterClose,
        draftStyle: root.draftStyle,
        draftSize: root.draftSize,
        draftThemeAware: root.draftThemeAware,
        draftClickEffects: root.draftClickEffects,
        draftJazzHands: root.draftJazzHands,
        draftEnabled: root.draftEnabled
      })
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(730))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: sizeDropdown.popupOpen
      onMoveRequested: function(dx, dy) { root.moveKeyboard(dx, dy) }
      onActivateRequested: root.activateKeyboard()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.moveTab(direction) }
      onTextKey: function(text) {
        if (text === "s" || text === "S") root.save()
        else if (text === "r" || text === "R") root.defaults()
        else if (text >= "1" && text <= "6") {
          root.setKeyboardIndex(Number(text) - 1)
          root.activateKeyboard()
        }
      }

      Flickable {
        id: settingsScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: content
          width: settingsScroll.width
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            title: "Tiny Hand"
            meta: "Pointer pack"
            detail: root.draftSize
            foreground: Color.popups.text
            iconComponent: Component {
              PointerArt {
                width: Style.space(48)
                height: Style.space(54)
                styleKey: root.draftStyle
                fillColor: root.draftThemeAware ? Color.foreground : "#fff4d6"
                shadeColor: root.draftThemeAware ? Qt.darker(Color.foreground, 1.22) : "#ffc987"
                outlineColor: root.draftThemeAware ? Color.background : "#171922"
                accentColor: root.draftThemeAware ? Color.accent : "#ff9f1c"
                urgentColor: root.draftThemeAware ? Color.urgent : "#ff5d73"
                lineScale: 0.7
              }
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(104)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.10)
            border.width: Math.max(1, Style.normalBorderWidth)
            border.color: Color.popups.border

            PointerArt {
              anchors.centerIn: parent
              width: root.draftStyle === "tiny-hand" ? Style.space(82) : Style.space(68)
              height: root.draftStyle === "tiny-hand" ? Style.space(92) : Style.space(78)
              styleKey: root.draftStyle
              fillColor: root.draftThemeAware ? Color.foreground : "#fff4d6"
              shadeColor: root.draftThemeAware ? Qt.darker(Color.foreground, 1.22) : "#ffc987"
              outlineColor: root.draftThemeAware ? Color.background : "#171922"
              accentColor: root.draftThemeAware ? Color.accent : "#ff9f1c"
              urgentColor: root.draftThemeAware ? Color.urgent : "#ff5d73"
            }

            Text {
              anchors.left: parent.left
              anchors.bottom: parent.bottom
              anchors.margins: Style.space(10)
              text: "LIVE PREVIEW"
              color: Qt.darker(Color.popups.text, 1.45)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1
            }
          }

          Text {
            width: parent.width
            text: "TAB / SHIFT+TAB  MOVE   ·   ARROWS / HJKL  NAVIGATE   ·   ENTER / SPACE  SELECT   ·   ESC  CLOSE"
            wrapMode: Text.WordWrap
            color: Qt.darker(Color.popups.text, 1.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.6
          }

          PanelSectionHeader { text: "STYLE"; foreground: Color.popups.text }

          Grid {
            width: parent.width
            columns: 3
            columnSpacing: Style.space(8)
            rowSpacing: Style.space(8)

            Repeater {
              id: styleRepeater
              model: root.styles
              delegate: CursorSurface {
                required property var modelData
                required property int index
                width: (content.width - Style.space(16)) / 3
                height: Style.space(94)
                foreground: Color.popups.text
                accent: Color.accent
                current: modelData.key === root.draftStyle
                hasCursor: root.keyboardIndex === index
                bordered: true

                PointerArt {
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: Style.space(6)
                  width: Style.space(34)
                  height: Style.space(40)
                  styleKey: modelData.key
                  fillColor: root.draftThemeAware ? Color.foreground : "#fff4d6"
                  shadeColor: root.draftThemeAware ? Qt.darker(Color.foreground, 1.22) : "#ffc987"
                  outlineColor: root.draftThemeAware ? Color.background : "#171922"
                  accentColor: root.draftThemeAware ? Color.accent : "#ff9f1c"
                  urgentColor: root.draftThemeAware ? Color.urgent : "#ff5d73"
                  lineScale: 0.65
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: note.top
                  text: modelData.name
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                Text {
                  id: note
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(6)
                  text: modelData.note
                  color: Qt.darker(Color.popups.text, 1.45)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.setKeyboardIndex(parent.index)
                  onClicked: {
                    root.setKeyboardIndex(parent.index)
                    root.draftStyle = parent.modelData.key
                    root.saveMessage = ""
                  }
                }
              }
            }
          }

          Dropdown {
            id: sizeDropdown
            width: parent.width
            label: "SIZE"
            value: root.draftSize
            options: root.sizes
            foreground: Color.popups.text
            background: Color.popups.background
            hasCursor: root.keyboardIndex === 6
            onHovered: function(hovered) { if (hovered) root.setKeyboardIndex(6) }
            onChanged: function(value) { root.draftSize = value; root.saveMessage = "" }
          }

          PanelSectionHeader { text: "BEHAVIOR"; foreground: Color.popups.text }

          Toggle {
            id: themeToggle
            width: parent.width
            label: "Theme-aware colors"
            description: "Follows the active Omarchy palette"
            checked: root.draftThemeAware
            foreground: Color.popups.text
            hasCursor: root.keyboardIndex === 7
            onHovered: function(hovered) { if (hovered) root.setKeyboardIndex(7) }
            onClicked: { root.setKeyboardIndex(7); root.toggleAt(7) }
          }

          Toggle {
            id: effectsToggle
            width: parent.width
            label: "Click fireworks"
            description: "Keeps the escalating poke animation"
            checked: root.draftClickEffects
            foreground: Color.popups.text
            hasCursor: root.keyboardIndex === 8
            onHovered: function(hovered) { if (hovered) root.setKeyboardIndex(8) }
            onClicked: { root.setKeyboardIndex(8); root.toggleAt(8) }
          }

          Toggle {
            id: jazzToggle
            width: parent.width
            label: "Triple-click jazz hands"
            description: "Two palms fan out and wiggle on click three"
            checked: root.draftJazzHands
            foreground: Color.popups.text
            hasCursor: root.keyboardIndex === 9
            onHovered: function(hovered) { if (hovered) root.setKeyboardIndex(9) }
            onClicked: { root.setKeyboardIndex(9); root.toggleAt(9) }
          }

          Toggle {
            id: enabledToggle
            width: parent.width
            label: "Start enabled"
            description: "Middle-click and the hotkey remain temporary"
            checked: root.draftEnabled
            foreground: Color.popups.text
            hasCursor: root.keyboardIndex === 10
            onHovered: function(hovered) { if (hovered) root.setKeyboardIndex(10) }
            onClicked: { root.setKeyboardIndex(10); root.toggleAt(10) }
          }

          Row {
            anchors.right: parent.right
            spacing: Style.space(8)
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.saveMessage
              color: root.saveMessage === "Saved" ? Color.accent : Qt.darker(Color.popups.text, 1.4)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            Button {
              id: resetButton
              text: "Reset"
              bordered: true
              focusable: true
              hasCursor: root.keyboardIndex === 11
              foreground: Color.popups.text
              onHovered: function(hovered) { if (hovered) root.setKeyboardIndex(11) }
              onClicked: { root.setKeyboardIndex(11); root.defaults() }
            }
            Button {
              id: saveButton
              text: "Save"
              selected: true
              focusable: true
              hasCursor: root.keyboardIndex === 12
              foreground: Color.popups.text
              accent: Color.accent
              onHovered: function(hovered) { if (hovered) root.setKeyboardIndex(12) }
              onClicked: { root.setKeyboardIndex(12); root.save() }
            }
          }
        }
      }
    }
  }
}
