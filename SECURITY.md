# Security

## Supported versions

Security fixes are applied to the latest released Tiny Hand version.

## Reporting

Please do not open a public issue for a vulnerability. Use GitHub's private
security-advisory flow for the Tiny Hand repository once it is public.

Useful reports include the Tiny Hand version, Omarchy and Hyprland versions,
reproduction steps, logs with personal data removed, and the observed impact.

## Runtime boundary

Tiny Hand runs inside the unsandboxed Omarchy shell and launches its bundled
native bridge. The bridge has no network code and does not open input devices.
It communicates only with local Hyprland and plugin-owned Unix sockets under
`$XDG_RUNTIME_DIR`. See the README for the complete capability description.
