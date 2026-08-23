# Marketplace submission draft

Do not submit this draft until the repository is public, the exact release
commit is verified, and the owner has explicitly confirmed every checklist
statement.

Issue title:

```text
[Plugin]: Tiny Hand
```

Issue body:

```markdown
### Repository URL

https://github.com/robbooker/omarchy-tiny-hand

### Category

Desktop

### Tags

bar, hyprland, quickshell

### Suggest a missing tag

cursor

### Maintainer notes

Tiny Hand is an original, theme-aware animated pointer pack. It bundles a
small x86-64 C helper and its complete source. The helper performs no network
access and does not read /dev/input. It reads cursor coordinates from
Hyprland's local IPC socket, owns two live Lua binding handles, and restores
the native cursor and removes those exact handles during shutdown. The helper
has a digest-pinned reproducible build and byte-for-byte CI verification.

### Submission checklist

- [ ] The repository is public and contains installation and removal instructions.
- [ ] I have documented the plugin license and any external dependencies.
- [ ] I confirm that I own or have permission to submit this plugin and its preview assets.
- [ ] The plugin does not overwrite user configuration without explicit consent.
- [ ] I understand that approval is for listing and is not a security review.
```
