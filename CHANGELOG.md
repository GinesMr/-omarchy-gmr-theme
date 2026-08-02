# Changelog

## 1.0.0 — 2026-08-02

Gmr theme bundle, first public release.

### Repo name

The repository is named **`omarchy-gmr-theme`** (not `-omarchy-gmr-theme`)
on purpose. The leading `-` in the previous name caused
`omarchy-theme-install` to normalise the local directory to
`themes/-omarchy-gmr/` instead of `themes/gmr/`. Omarchy's
`omarchy-theme-set -omarchy-gmr` then copied the bundle artefacts
(payload, installer, manifest) into `~/.config/omarchy/current/theme/`,
breaking Hyprland's `source = ~/.config/omarchy/current/theme/hyprland.conf`.

With the corrected name `omarchy-gmr-theme`, normalisation produces
`gmr` cleanly and Omarchy's `theme-set gmr` reads the user theme
directly.

### Bundle contents

- **`install-gmr-theme.sh`** (18 122 bytes, sha256
  `5718b03afc6275a207acb04f1142cf687db548b2ca088fcac00ff51a5a71415f`)
  — portable Bash installer. `--dry-run`, `--validate-only`, `--no-apply`,
  `--rollback[=ts]`, `--list-backups`, `--help`, `--verbose`. SHA256 of the
  payload is checked before any change. Pre- and post-move guards reject
  malformed payloads and ensure the moved theme contains the
  Omarchy-required files.

- **`gmr-theme-1.0.0.tar.zst`** (12 268 003 bytes, sha256
  `6a80c9ba35e9e2d216d0de33a44b2950c0b02f779f7ffc300ee6ee38bd7faf87`)
  — `theme/` (27 files) plus `dots/` (13 files for Waybar, the four
  terminals, Mako, SwayOSD, Walker, hyprlock override, fontconfig, GTK 3.0
  and btop) plus `MANIFEST.toml`.

### Fixes vs. the audited source state

1. **Hyprland gradients** now use `#RRGGBBAA` (Hyprland does not accept
   `rgba(R,G,B,α)` with floats in gradient expressions).
2. **Mako was disconnected** from the theme. The installer recreates the
   `~/.config/mako/config` symlink so `gmr`'s palette is consumed.
3. **Hyprlock had two input-fields** (one transparent). The theme's
   `hyprlock.conf` is shipped with a single themeable widget; the user
   `hyprlock.conf` keeps only the override-safe fields.
4. **Waybar used hardcoded VS Code colors**. Now expressed as
   `@accent`, `@window_active`, `@text_window`, `@surface`, `@surface_hi`
   from the theme's `waybar.css`.
5. **Walker CSS** now defines `@selected-text`.
6. **SwayOSD CSS** now defines `@image`.
7. **Waybar screenrecord on-click** points to
   `omarchy-capture-screenrecording` (the correct command).
8. **btop.conf** is updated in-place to set `color_theme = "current"`.

### Install

```bash
git clone https://github.com/GinesMr/omarchy-gmr-theme
cd omarchy-gmr-theme
./install-gmr-theme.sh gmr-theme-1.0.0.tar.zst
```

Or, with the curl-only path:

```bash
curl -L https://github.com/GinesMr/omarchy-gmr-theme/releases/download/v1.0.0/install-gmr-theme.sh -o install-gmr-theme.sh
curl -L https://github.com/GinesMr/omarchy-gmr-theme/releases/download/v1.0.0/gmr-theme-1.0.0.tar.zst -o gmr-theme-1.0.0.tar.zst
chmod +x install-gmr-theme.sh
./install-gmr-theme.sh gmr-theme-1.0.0.tar.zst
```

Or via Omarchy's standard installer:

```bash
omarchy theme install https://github.com/GinesMr/omarchy-gmr-theme
```

### Known limitations

- Changing GTK theme on the fly requires re-launching any open GTK app.
- Plymouth and SDDM are NOT managed by this bundle (Omarchy uses sudo
  helpers that require interactive confirmation).
- The Chromium policy is only rewritten for `chromium`; Chrome/Edge/Brave
  need a separate `omarchy-theme-set-browser` run.
- Wallpapers are aspect 3:2/16:10 on a 21:9 monitor — `swaybg -m fill`
  crops vertically.

### Files NOT modified by the installer

The installer is intentionally non-destructive. The following
hardware- and workflow-specific files are NEVER touched, even when
`--force` is set:

- `~/.config/hypr/monitors.conf` (DP-2, 3440x1440@180, scale 1)
- `~/.config/hypr/input.conf` (keyboard layout, touchpad, repeat)
- `~/.config/hypr/bindings.conf` (personal shortcuts, web apps,
  dictator-ptt)
- `~/.config/hypr/autostart.conf` (dictator-ptt)
- `~/.config/hypr/hypridle.conf`, `hyprsunset.conf`
- `~/.config/nvim/**` (LazyVim personal config)

### What's portable (and what isn't)

Portable across machines that share the same packages:

- The Omarchy theme itself (`gmr/`)
- Waybar `style.css`, `config.jsonc`, `window.sh`
- Terminal configs (Alacritty, Ghostty, Kitty, Foot)
- Mako, SwayOSD, Walker CSS
- Hyprlock override (single input-field)
- Fontconfig override
- GTK 3.0 settings.ini (color scheme + theme + icon theme)
- btop color_theme directive

NOT portable (kept on the source machine):

- Monitor/input/binding/autostart configs (see above)
- Personal Neovim/LazyVim config
- Plymouth/SDDM (require sudo)

### License

MIT — see `LICENSE`. Wallpapers under the Unsplash License — see
`theme/backgrounds/CREDITS.md` after install.
