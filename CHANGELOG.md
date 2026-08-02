# Changelog

## 1.0.0 — 2026-08-02

Gmr theme bundle, first public release.

### Bundle contents

- **`install-gmr-theme.sh`** (16 KB) — portable Bash installer with `--dry-run`,
  `--validate-only`, `--apply`, `--no-apply`, `--rollback`, `--list-backups`,
  `--help`, `--verbose`. Validates dependencies, payload SHA256, expected
  files. Atomic install via staging + `mv`. Backups timestamped under
  `~/omarchy-ai-bootstrap/reports/theme-backups/<ts>/`.
  **Hardened in this release**: pre-move sanity checks reject malformed
  payloads (no `theme/`, missing `colors.toml`/`alacritty.toml`, or any stray
  bundle artefact inside `theme/` such as
  `gmr-theme-1.0.0.tar.zst` / `install-gmr-theme.sh` / `MANIFEST.toml`).
  Post-move sanity verifies the moved theme contains the Omarchy-required
  files.

- **`gmr-theme-1.0.0.tar.zst`** (12 MB) — payload containing:
  - `theme/` with 27 Omarchy-theme files (colors.toml, alacritty.toml,
    ghostty.conf, kitty.conf, foot.ini, hyprland.conf, hyprlock.conf,
    mako.ini, waybar.css, swayosd.css, walker.css, gtk.css, btop.theme,
    chromium.theme, keyboard.rgb, icons.theme, eza.yml, helix.toml,
    gum.env.conf, neovim.lua, obsidian.css, hyprland-preview-share-picker.css,
    LICENSE, README.md, CHANGELOG.md, preview.png) plus 8 Unsplash
    wallpapers and `backgrounds/CREDITS.md`.
  - `dots/` with portable overlays for Waybar
    (`config.jsonc`+`style.css`+`window.sh`), the four terminals
    (alacritty, ghostty, kitty, foot), Mako, SwayOSD, Walker, Hyprlock
    (user override), fontconfig, GTK 3.0, and btop.

### Fixes vs. the audited source state

1. **Hyprland gradients** now use `#RRGGBBAA` (Hyprland does not accept
   `rgba(R,G,B,α)` with floats in gradient expressions).
2. **Mako was disconnected** from the theme. The installer recreates the
   `~/.config/mako/config` symlink so `gmr`'s palette is consumed.
3. **Hyprlock had two input-fields** (one transparent). The theme's
   `hyprlock.conf` is shipped with a single themeable widget; the user
   `hyprlock.conf` keeps only the override-safe fields (background, blur,
   font_family, animations, fingerprint).
4. **Waybar used hardcoded VS Code colors** (`#569cd6`, `#9cdcfe`, `#2472c8`).
   Now expressed as `@accent`, `@window_active`, `@text_window` from the
   theme's `waybar.css`.
5. **Walker CSS used `@selected-text`** without defining it. Fixed.
6. **SwayOSD CSS used `@image`** without defining it. Fixed.
7. **Waybar screenrecord on-click** pointed to `omarchy-cmd-screenrecord`
   (no such command). Now points to `omarchy-capture-screenrecording`.
8. **btop.conf** had `color_theme` duplicated; installer now replaces
   in place.

### Known limitations

- Changing GTK theme on the fly requires re-launching any open GTK app.
- Plymouth and SDDM are NOT managed by this bundle (Omarchy uses sudo
  helpers that require interactive confirmation).
- The Chromium policy is only rewritten for `chromium`; Chrome/Edge/Brave
  need a separate `omarchy-theme-set-browser` run.
- Wallpapers are aspect 3:2/16:10 on a 21:9 monitor — `swaybg -m fill`
  crops vertically.
