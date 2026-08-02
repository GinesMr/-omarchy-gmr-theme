# Gmr — Omarchy Theme Bundle

Personal dark theme for [Omarchy](https://omarchy.org/) — fork of
[Onyx](https://github.com/luntta/omarchy-onyx-theme) (Raine Luntta, MIT)
with a fully portable installer/rollback manager and non-theme overlays
(Waybar, four terminals, Mako, SwayOSD, Walker, fontconfig, GTK 3.0, btop).

## Why the repo name is `gmr-omarchy-bundle`

The repo name has **neither** the `omarchy-` prefix **nor** the
`-theme` suffix, so Omarchy's `omarchy-theme-install` will not try to
clone this repository as a theme into `~/.config/omarchy/themes/gmr/`
(overwriting your real theme on every install).

Install paths documented below all bypass `omarchy-theme-install` and
treat the bundle as a generic payload.

## Files

| File | Size | Purpose |
| --- | ---: | --- |
| `install-gmr-theme.sh` | 18 KB | Portable Bash installer |
| `gmr-theme-1.0.0.tar.zst` | 12 MB | Theme bundle (zstd-compressed) |
| `MANIFEST.toml` | 1.4 KB | Bundle metadata (version, expects, requires) |
| `SHA256SUMS` | — | SHA256 of the two binary files |
| `LICENSE` | 1.1 KB | MIT (with Unsplash credits in `theme/backgrounds/CREDITS.md`) |
| `CHANGELOG.md` | — | Release notes |

## Install (recommended)

```bash
git clone https://github.com/GinesMr/gmr-omarchy-bundle
cd gmr-omarchy-bundle
./install-gmr-theme.sh gmr-theme-1.0.0.tar.zst
```

The installer places the theme under `~/.config/omarchy/themes/gmr/`,
restores the Mako/btop/background symlinks, and then runs
`omarchy-theme-set gmr` so every consumer (Hyprland, Waybar, terminals,
Mako, SwayOSD, Walker, btop, Neovim, Gum, Chromium, Obsidian) picks it
up.

## Install (curl only — no git clone)

```bash
curl -L https://github.com/GinesMr/gmr-omarchy-bundle/releases/download/v1.0.0/install-gmr-theme.sh -o install-gmr-theme.sh
curl -L https://github.com/GinesMr/gmr-omarchy-bundle/releases/download/v1.0.0/gmr-theme-1.0.0.tar.zst -o gmr-theme-1.0.0.tar.zst
chmod +x install-gmr-theme.sh
./install-gmr-theme.sh gmr-theme-1.0.0.tar.zst
```

## Install (Omarchy theme-set, manual)

If you only want the theme files in `~/.config/omarchy/themes/gmr/`
and are happy to wire the rest yourself:

```bash
git clone --depth 1 https://github.com/GinesMr/gmr-omarchy-bundle /tmp/gmr
cp -a /tmp/gmr/gmr-theme-1.0.0.tar.zst /tmp/gmr-tmp.tar.zst
tar -C /tmp -xf <(zstd -dc /tmp/gmr-tmp.tar.zst)
cp -a /tmp/gmr-theme-1.0.0/theme ~/.config/omarchy/themes/gmr
omarchy-theme-set gmr
```

## Rollback

```bash
./install-gmr-theme.sh --rollback
```

Backups live under `~/omarchy-ai-bootstrap/reports/theme-backups/<ts>/`.
List them with `./install-gmr-theme.sh --list-backups`.

## What's portable vs. what isn't

See [`CHANGELOG.md`](./CHANGELOG.md) for the full architecture and
the list of files the installer never touches
(`monitors.conf`, `input.conf`, `bindings.conf`, `autostart.conf`,
`nvim/**`, Plymouth, SDDM).

## License

MIT — see [`LICENSE`](./LICENSE). Wallpapers under the Unsplash
License — see `theme/backgrounds/CREDITS.md` after install.
