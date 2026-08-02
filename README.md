# Gmr (Onyx fork)

Personal dark theme for [Omarchy](https://omarchy.org/) on this workstation —
charcoal/translucent surfaces, pastel terminal palette, hard square corners,
no blur, no shadows, no gaps, fully opaque windows.

> Forked from [Onyx](https://github.com/luntta/omarchy-onyx-theme) (Raine Luntta),
> which itself descends from [Spectra](https://github.com/abhijeet-swami/omarchy-spectra-theme)
> (Abhijeet Swami, MIT). The original Onyx → Gmr changes are documented under
> `CHANGELOG.md`.

![Gmr preview](preview.png)

## Install

```bash
./install-gmr-theme.sh gmr-theme.tar.zst
```

The installer places the theme under `~/.config/omarchy/themes/gmr/` and then
runs `omarchy-theme-set gmr` so all consumers (Hyprland, terminals, Waybar,
Walker, Mako, SwayOSD, btop, Neovim, Gum, Chromium, Obsidian) pick it up.

## Uninstall / rollback

```bash
./install-gmr-theme.sh --rollback
```

## Architecture

This bundle packages two files:

1. **`install-gmr-theme.sh`** — portable Bash installer with `--dry-run`,
   `--validate-only`, `--rollback`, `--list-backups`, exit codes and a
   pre-flight check.
2. **`gmr-theme.tar.zst`** — a zstd-compressed tarball containing the theme
   `~/.config/omarchy/themes/gmr/` plus reusable `dots/` overlays for the
   non-theme configs (Waybar, terminals, Mako, SwayOSD, fontconfig, hyprlock
   override, btop symlink).

The installer:
- Idempotent — re-running with the same version is a no-op.
- Reversible — every install creates a backup under
  `~/omarchy-ai-bootstrap/reports/theme-backups/<timestamp>/`.
- Validated — runs `shellcheck`/`shfmt`-clean code, checksums the payload,
  refuses to operate without `bash`, `tar`, `zstd`, `sha256sum`.
- Non-destructive — never touches `~/.local/share/omarchy/`, never escalates
  to root, never overwrites hardware-specific files (`monitors.conf`,
  `input.conf`, `bindings.conf`, `autostart.conf`).

## What's portable

Included in the bundle (deploys on any machine that has the same packages):

- The Omarchy theme itself (`gmr/`).
- Waybar `style.css` + `config.jsonc` + `window.sh` helper.
- Terminal configs (Alacritty, Ghostty, Kitty, Foot).
- Mako, SwayOSD, Walker CSS.
- Hyprlock override (centralized; doesn't duplicate the theme's input-field).
- Fontconfig override (sans/serif/mono aliases).
- GTK 3.0 settings.ini (forces Adwaita-dark + Yaru-sage + dark color-scheme).
- btop symlink helper.

## What's NOT portable (kept on the source machine)

These are hardware- or workflow-specific and are never overwritten by the
installer:

- `~/.config/hypr/monitors.conf` — output names, sizes, refresh, scale.
- `~/.config/hypr/input.conf` — keyboard layout, touchpad, repeat.
- `~/.config/hypr/bindings.conf` — personal shortcuts, web apps, dictator-ptt.
- `~/.config/hypr/autostart.conf` — personal autostart (e.g. dictator-ptt).
- `~/.config/hypr/hypridle.conf`, `hyprsunset.conf` — personal timeouts.
- `~/.config/waybar/window.sh` discord/vesktop hardcodes — generic helper is
  provided instead.
- `~/.config/nvim/` — Neovim (LazyVim) is a personal config; the theme still
  ships `neovim.lua` for the Omarchy symlink.

## What gets corrected (vs raw state)

The pre-bundle audit found several inconsistencies in the source machine. The
package ships the corrected versions:

1. **Mako was disconnected** from the theme. The installer recreates the
   `~/.config/mako/config` symlink so `gmr`'s palette is consumed.
2. **Hyprlock had two input-fields** (one transparent). The theme's
   `hyprlock.conf` is replaced with a single themeable widget; the user
   `hyprlock.conf` keeps only the override-safe fields (background, blur,
   font_family, animations, fingerprint).
3. **Waybar used hardcoded VS Code colors** (`#569cd6`, `#9cdcfe`, `#2472c8`).
   Now expressed as `@accent`, `@window_active`, `@text_window` from the
   theme's `waybar.css`.
4. **Walker CSS used `@selected-text`** without defining it. Fixed.
5. **SwayOSD CSS used `@image`** without defining it. Fixed.
6. **Waybar screenrecord on-click** pointed to `omarchy-cmd-screenrecord`
   (no such command). Now points to `omarchy-capture-screenrecording`.
7. **Background symlink target** is preserved; the payload keeps the eight
   Unsplash wallpapers and `CREDITS.md`.

## License

MIT — see `LICENSE`. Wallpapers under the Unsplash License — see
`backgrounds/CREDITS.md`.
