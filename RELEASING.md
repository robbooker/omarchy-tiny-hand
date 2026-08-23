# Releasing Tiny Hand

## Release gate

1. Confirm `manifest.json` has the intended permanent ID and version.
2. Build the committed helper with the pinned toolchain:

   ```bash
   make release-build
   make verify-bridge
   ```

   If local Docker access is unavailable, run the `Build release bridge`
   workflow, download its `tiny-hand-bridge-linux-amd64` artifact into `bin/`,
   mark it executable, commit it, and let `Verify bundled bridge` confirm exact
   byte equality.

3. Run local validation:

   ```bash
   make check
   ```

4. Install from a clean Git clone using only Omarchy's public path:

   ```bash
   omarchy plugin add https://github.com/robbooker/omarchy-tiny-hand.git --enable
   ```

5. Verify pointer tracking, click effects, jazz hands, settings navigation,
   persistence, theme switching, shell restart, disable/re-enable, and removal.
6. Confirm disabling and removal leave no Tiny Hand helpers or live bindings
   and restore `cursor:invisible` to `false`.
7. Confirm `preview.png`, `README.md`, `CHANGELOG.md`, `LICENSE`, and
   `THIRD_PARTY_NOTICES.md` match the release.
8. Create and push an annotated version tag.

## Marketplace

Submit the repository root to the Omarchy Plugin Marketplace with:

- Category: `Desktop`
- Tags: `bar`, `hyprland`, `quickshell`
- Suggested missing tag: `cursor`

Review `MARKETPLACE_SUBMISSION.md` with the owner before creating the issue.
The exact commit must pass marketplace compatibility validation and the
Automated Security Baseline before publication.
