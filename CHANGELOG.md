# Changelog

All notable Tiny Hand changes are documented here.

## 0.5.1 — 2026-08-23

- Prevent a loader-backed Omarchy panel that closed itself from leaving Tiny
  Hand permanently suspended behind a stale shell loader flag.

## 0.5.0 — 2026-08-22

- Make standard Omarchy installation self-contained: click observation and
  the toggle shortcut are registered as live Hyprland Lua bindings and removed
  with their exact binding handles.
- Remove mandatory persistent Hyprland configuration edits.
- Add a pinned, reproducible build and CI byte-for-byte verification for the
  bundled native bridge.
- Add six theme-aware pointer styles, configurable sizing, and persistent
  settings.
- Add the Middle Finger pointer and optional triple-click jazz hands.
- Add a top-right settings panel with complete mouse and keyboard control.
- Restore the native cursor while settings are open and restore the prior
  pointer state when settings close.
- Yield to the native cursor while any Omarchy bar popout or interactive panel
  is open, then resume the chosen pointer automatically when it closes.

## 0.1.0 — 2026-08-22

- Initial Tiny Hand pointer prototype.
