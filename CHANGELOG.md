# Changelog

## 1.0.0 — 2026-08-02

Gmr theme bundle, first public release.

### Bundle contents

- **`gmr/`** Omarchy theme — fork of Onyx with:
  - `colors.toml` pinned (auto-derivation from alacritty.toml removed).
  - `alacritty.toml`, `ghostty.conf`, `kitty.conf`, `foot.ini` aligned.
  - `hyprland.conf` with clean border variables, no blur, no shadows,
    animations only on the workspace special and border.
  - `hyprlock.conf` with single themeable input-field, `$color` defined,
    consistent palette.
  - `mako.ini` port including core overrides (urgency, spotify invisibility).
  - `waybar.css` exposing `@accent`, `@window_active`, `@text_window`,
    `@surface`, `@surface_hi`, `@image`, `@selected-text` so downstream
    styles don't break.
  - `swayosd.css` with `@image` defined.
  - `walker.css` with `@selected-text` defined.
  - `gtk.css` aligned with the rest of the palette.
  - 8 Unsplash wallpapers + `CREDITS.md`.
  - `LICENSE` (MIT), `README.md`, `preview.png`.

- **`dots/`** non-theme overlays:
  - `waybar/style.css`, `waybar/config.jsonc`, `waybar/window.sh` (no
    discord/vesktop hardcodes).
  - `alacritty/alacritty.toml`, `ghostty/config`, `kitty/kitty.conf`,
    `foot/foot.ini`.
  - `swayosd/style.css`, `mako/config` (symlink source), `walker/config.toml`.
  - `hypr/hyprlock-user.conf` (override that keeps the theme single
    input-field).
  - `fontconfig/fonts.conf` (sans/serif/mono aliases).
  - `gtk-3.0/settings.ini` (color scheme + theme + icon theme).
  - `btop/btop.conf` snippet to set `color_theme = "current"`.

### Installer

- `install-gmr-theme.sh` with `--dry-run`, `--validate-only`, `--apply`,
  `--rollback`, `--list-backups`, `--help`, `--verbose`.
- SHA256 manifest of the payload.
- Validates Omarchy version, presence of dependencies, diskspace and
  payload integrity before touching the filesystem.
- Atomic install via staging + `mv`.
- Backups under `~/omarchy-ai-bootstrap/reports/theme-backups/<ts>/`.

### Known limitations

- Changing GTK theme on the fly requires re-launching any open GTK app.
- Plymouth and SDDM are NOT managed by this bundle (Omarchy uses sudo
  helpers that require interactive confirmation).
- The Chromium policy is only rewritten for `chromium`; Chrome/Edge/Brave
  need a separate `omarchy-theme-set-browser` run.
