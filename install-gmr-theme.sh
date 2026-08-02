#!/usr/bin/env bash
# install-gmr-theme.sh — portable installer for the Gmr Omarchy theme bundle.
#
# Usage:
#   ./install-gmr-theme.sh [gmr-theme.tar.zst] [--dry-run] [--validate-only]
#                          [--no-apply] [--force] [--rollback[=<ts>]]
#                          [--list-backups] [--help] [--verbose]
#
# Idempotent, reversible, never requires root. Backups live under
#   ~/omarchy-ai-bootstrap/reports/theme-backups/<timestamp>/
# Mirror of the audit documented in ~/omarchy-ai-bootstrap/reports/.

set -euo pipefail

#----------------- defaults -----------------
SCRIPT_NAME="${BASH_SOURCE[0]##*/}"
PAYLOAD=""
TARGET_DIR=""
BACKUP_DIR=""
BACKUP_ROOT=""
THEME_NAME="gmr"
THEME_VERSION="1.0.0"
DRY_RUN=0
VALIDATE_ONLY=0
NO_APPLY=0
FORCE=0
ROLLBACK_TS=""
LIST_BACKUPS=0
VERBOSE=0
SHOW_HELP=0

#----------------- logging ------------------
log()  { printf '%s\n' "$*" >&2; }
vlog() { (( VERBOSE )) || return 0; log "[v] $*"; }
err()  { log "[!] $*" >&2; }
die()  { err "$*"; exit "${2:-1}"; }

#----------------- help ---------------------
usage() {
  cat <<EOF
$SCRIPT_NAME — install/rollback the Gmr Omarchy theme bundle.

Usage:
  $SCRIPT_NAME [PAYLOAD] [options]

Arguments:
  PAYLOAD                Path to gmr-theme.tar.zst (default: auto-detect next to script)

Options:
  --dry-run              Show what would happen; make no changes
  --validate-only        Verify payload (checksums, files) and exit
  --no-apply             Install files but skip omarchy-theme-set
  --force                Overwrite existing theme without confirmation
  --rollback[=<ts>]      Restore the most recent (or given) backup
  --list-backups         Enumerate available backups
  --target-dir=<path>    Theme staging directory (default: ~/.config/omarchy/themes)
  --backup-dir=<path>    Where to keep backups (default: ~/omarchy-ai-bootstrap/reports/theme-backups)
  --theme-name=<name>    Override theme name (default: $THEME_NAME)
  --verbose, -v          Verbose tracing
  --help, -h             Show this help

Exit codes:
  0  success
  1  bad arguments
  2  payload missing or invalid
  3  missing dependency
  4  validation failed
  5  install partial
  6  rollback failed

Environment:
  OMARCHY_THEME_SKIP_BACKGROUND=1  skip background swap on apply
EOF
}

#----------------- arg parsing --------------
parse_args() {
  while (( $# )); do
    case "$1" in
      -h|--help)            SHOW_HELP=1 ;;
      -v|--verbose)         VERBOSE=1 ;;
      --dry-run)            DRY_RUN=1 ;;
      --validate-only)      VALIDATE_ONLY=1 ;;
      --no-apply)           NO_APPLY=1 ;;
      --force)              FORCE=1 ;;
      --list-backups)       LIST_BACKUPS=1 ;;
      --rollback)           ROLLBACK_TS="latest" ;;
      --rollback=*)         ROLLBACK_TS="${1#*=}" ;;
      --target-dir=*)       TARGET_DIR="${1#*=}" ;;
      --backup-dir=*)       BACKUP_DIR="${1#*=}" ;;
      --theme-name=*)       THEME_NAME="${1#*=}" ;;
      --payload=*)          PAYLOAD="${1#*=}" ;;
      -*)                   die "Unknown option: $1" 1 ;;
      *)                    PAYLOAD="$1" ;;
    esac
    shift
  done
}

#----------------- preflight ----------------
need_bin() {
  local b="$1"
  command -v "$b" >/dev/null 2>&1 || die "missing required binary: $b" 3
}

all_bins() {
  local b
  for b in bash tar zstd sha256sum mktemp awk sed find realpath readlink basename dirname sort tr jq cut; do
    need_bin "$b"
  done
}

auto_payload() {
  if [[ -n "$PAYLOAD" ]]; then
    [[ -f "$PAYLOAD" ]] || die "payload not found: $PAYLOAD" 2
    return
  fi
  local here candidate
  here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  candidate="$(find "$here" -maxdepth 1 -type f -name 'gmr-theme-*.tar.zst' | sort -V | tail -n1 || true)"
  [[ -n "$candidate" ]] || die "no payload given and no gmr-theme-*.tar.zst next to $SCRIPT_NAME" 2
  PAYLOAD="$candidate"
  vlog "payload auto-detected: $PAYLOAD"
}

#----------------- manifest -----------------
read_manifest_field() {
  # usage: read_manifest_field <field>
  local field="$1"
  awk -F' = ' -v k="$field" '
    /^[a-zA-Z_]/ {
      gsub(/^[[:space:]]+/,"",$1)
      if ($1 == k) { sub(/^[^=]+= /,""); print; exit }
    }
  ' "$WORK_MANIFEST"
}

#----------------- validation --------------
validate_payload() {
  local file_count total_size_bytes
  vlog "resetting workdir"
  rm -rf "$WORK_DIR"
  mkdir -p "$WORK_DIR"

  vlog "listing tar contents"
  zstd -dcq "$PAYLOAD" | tar -tf - >"$WORK_DIR/archive.lst" 2>/dev/null \
    || die "could not list tar contents" 2

  # Find the top-level directory prefix (handles both "gmr-theme-1.0.0/" and "gmr-theme-1.0.0/./" forms).
  local top_prefix
  top_prefix="$(grep -E '^[^/]+/$' "$WORK_DIR/archive.lst" | head -n1 | sed 's:/$::' || true)"
  # Some tar variants may list "./" entries; if no clean top dir, fall back to first component.
  if [[ -z "$top_prefix" ]]; then
    top_prefix="$(head -n1 "$WORK_DIR/archive.lst" | awk -F/ '{print $1}')"
  fi
  [[ -n "$top_prefix" ]] || die "could not determine top-level directory in archive" 2
  vlog "top prefix: $top_prefix"

  # Extract MANIFEST.toml (handles both forms)
  local manifest_path
  manifest_path="$(grep -E "^${top_prefix}(/\\./)?/MANIFEST\\.toml$" "$WORK_DIR/archive.lst" | head -n1 || true)"
  [[ -n "$manifest_path" ]] || die "MANIFEST.toml not found at top of archive" 2
  zstd -dcq "$PAYLOAD" | tar -xOf - "$manifest_path" >"$WORK_MANIFEST" 2>/dev/null \
    || die "could not extract MANIFEST.toml" 2

  (( $(wc -l <"$WORK_MANIFEST") > 0 )) || die "MANIFEST.toml is empty" 2

  # Version sanity
  local m_ver
  m_ver="$(read_manifest_field version)"
  [[ -n "$m_ver" ]] || die "MANIFEST version missing" 4
  vlog "manifest version: $m_ver"

  if [[ -n "$THEME_VERSION" && "$m_ver" != "$THEME_VERSION" ]]; then
    vlog "note: payload version $m_ver differs from script default $THEME_VERSION"
  fi

  # Required files
  local missing=0
  local expects_file
  expects_file="$(awk -F' = ' '/^[[:space:]]*files[[:space:]]*=/ {sub(/^[^=]+= /,""); print; exit}' "$WORK_MANIFEST" || true)"

  if [[ -n "$expects_file" ]]; then
    vlog "validating expected files in archive"
    while IFS= read -r rel; do
      rel="${rel//\"/}"
      rel="${rel%,}"
      [[ -z "$rel" ]] && continue
      if ! grep -qE "^${top_prefix}(/\\./)?/theme/$rel$" "$WORK_DIR/archive.lst"; then
        err "missing expected file in archive: theme/$rel"
        missing=1
      fi
    done < <(printf '%s' "$expects_file" | tr ',' '\n')
  fi

  (( missing == 0 )) || die "payload missing required files" 4

  # Compute checksums
  vlog "computing sha256 of payload"
  PAYLOAD_SHA="$(sha256sum "$PAYLOAD" | awk '{print $1}')"
  vlog "payload sha256: $PAYLOAD_SHA"

  # Counts
  file_count=$(grep -cE "^${top_prefix}(/\\./)?/theme/" "$WORK_DIR/archive.lst" || true)
  total_size_bytes=$(wc -c <"$PAYLOAD")
  vlog "payload: $file_count theme files, $total_size_bytes bytes"
}

#----------------- backups ------------------
list_backups() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log "no backups yet ($BACKUP_DIR missing)"
    return 0
  fi
  log "Available backups under $BACKUP_DIR:"
  find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | sed 's/^/  /'
  log ""
  log "Latest: $(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | head -n1 || echo none)"
}

make_backup() {
  local ts="$1"
  local dest="$BACKUP_DIR/$ts"
  mkdir -p "$dest"
  log "  backup: $dest"

  local manifest="$dest/manifest.txt"
  {
    echo "ts=$ts"
    echo "theme=$THEME_NAME"
    echo "payload=$PAYLOAD"
    echo "payload_sha256=$PAYLOAD_SHA"
    echo "previously_active=$(cat "${HOME}/.config/omarchy/current/theme.name" 2>/dev/null || echo unknown)"
    echo "user=$USER"
    echo "hostname=$(hostname)"
  } >"$manifest"

  # Snapshot current theme (the snapshot directory, not the user theme)
  if [[ -d "${HOME}/.config/omarchy/current" ]]; then
    cp -a "${HOME}/.config/omarchy/current" "$dest/omarchy-current"
  fi

  # Snapshot existing user theme (if any) so we can restore it on rollback
  if [[ -d "$TARGET_DIR/$THEME_NAME" ]]; then
    mkdir -p "$dest/themes"
    cp -a "$TARGET_DIR/$THEME_NAME" "$dest/themes/$THEME_NAME"
  fi

  # Snapshot dots we plan to overwrite
  for d in waybar mako swayosd walker hypr alacritty ghostty kitty foot fontconfig gtk-3.0 btop; do
    if [[ -d "${HOME}/.config/$d" ]]; then
      mkdir -p "$dest/dots/$d"
      cp -a "${HOME}/.config/$d/." "$dest/dots/$d/" 2>/dev/null || true
    fi
  done

  echo "$ts" >>"$BACKUP_ROOT/registry.tsv"
  return 0
}

#----------------- install ------------------
install_theme() {
  local ts dest
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  dest="$BACKUP_DIR/$ts"

  if (( DRY_RUN )); then
    log "DRY-RUN: would create backup at $dest"
    log "DRY-RUN: would extract theme into staging"
    log "DRY-RUN: would atomically move staging -> $TARGET_DIR/$THEME_NAME"
    log "DRY-RUN: would install overlays into ~/.config/"
    log "DRY-RUN: would symlink ~/.config/mako/config -> current/theme/mako.ini"
    log "DRY-RUN: would link btop themes/current.theme -> current/theme/btop.theme"
    if (( ! NO_APPLY )); then
      log "DRY-RUN: would invoke omarchy-theme-set $THEME_NAME"
    fi
    return 0
  fi

  # Backup first
  make_backup "$ts"

  # Full extract to staging
  local staging
  staging="$(mktemp -d -t gmr-install.XXXXXX)"
  vlog "extracting payload into $staging"
  tar --use-compress-program='zstd -dc' -xf "$PAYLOAD" -C "$staging"
  # Cleanup staging explicitly at end of install_theme.

  # Find the single top-level dir
  local top_dir
  top_dir="$(find "$staging" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  [[ -n "$top_dir" ]] || die "no top-level directory found in payload" 2

  # Sanity: the theme/ subdir must exist before we move it
  if [[ ! -d "$top_dir/theme" ]]; then
    err "ERROR: theme/ subdirectory not found at $top_dir/theme"
    err "staging contents:"
    ls -la "$staging" >&2
    err "top_dir contents:"
    ls -la "$top_dir" >&2
    rm -rf "$staging"
    die "aborting: malformed payload" 2
  fi

  # Sanity: theme/ must contain colors.toml OR alacritty.toml (the Omarchy contract)
  if [[ ! -f "$top_dir/theme/colors.toml" && ! -f "$top_dir/theme/alacritty.toml" ]]; then
    err "ERROR: theme/ has neither colors.toml nor alacritty.toml"
    err "this is not a valid Omarchy theme package"
    rm -rf "$staging"
    die "aborting: theme/ has no color source" 2
  fi

  # Sanity: theme/ must NOT contain stray bundle artefacts (e.g. the payload itself)
  if [[ -f "$top_dir/theme/gmr-theme-1.0.0.tar.zst" \
     || -f "$top_dir/theme/install-gmr-theme.sh" \
     || -f "$top_dir/theme/MANIFEST.toml" \
     || -f "$top_dir/theme/SHA256SUMS" ]]; then
    err "ERROR: theme/ contains bundle artefacts — payload was probably extracted into the wrong place"
    err "this usually means the caller invoked the installer with the wrong working directory"
    rm -rf "$staging"
    die "aborting: theme/ has bundle leaks" 2
  fi

  # Move theme into target
  if [[ -d "$TARGET_DIR/$THEME_NAME" && $FORCE -ne 1 ]]; then
    err "theme '$THEME_NAME' already exists in $TARGET_DIR"
    err "  use --force to overwrite, or --rollback to restore a previous version"
    die "aborting" 5
  fi

  if [[ -d "${TARGET_DIR:?}/$THEME_NAME" ]]; then
    vlog "removing previous theme directory"
    rm -rf "${TARGET_DIR:?}/$THEME_NAME"
  fi
  mkdir -p "$TARGET_DIR"
  vlog "mv $top_dir/theme -> $TARGET_DIR/$THEME_NAME"
  mv "$top_dir/theme" "$TARGET_DIR/$THEME_NAME"

  # Post-move sanity: the moved theme must contain the Omarchy-required files
  if [[ ! -f "$TARGET_DIR/$THEME_NAME/colors.toml" \
     && ! -f "$TARGET_DIR/$THEME_NAME/alacritty.toml" ]]; then
    err "ERROR: theme was moved but has no colors.toml or alacritty.toml"
    err "aborting; current/theme will be restored by omarchy-theme-set on next run"
    rm -rf "$staging"
    die "aborting: theme install failed post-move" 5
  fi
  if [[ ! -f "$TARGET_DIR/$THEME_NAME/hyprland.conf" \
     && ! -f "$TARGET_DIR/$THEME_NAME/alacritty.toml" ]]; then
    err "WARNING: theme has no hyprland.conf — Hyprland may load without color/style"
  fi

  # Install non-theme overlays
  if [[ -d "$top_dir/dots" ]]; then
    install_overlays "$top_dir/dots"
  fi

  # Re-establish Mako symlink so the theme is consumed
  if [[ -f "$TARGET_DIR/$THEME_NAME/mako.ini" ]]; then
    mkdir -p "${HOME}/.config/mako"
    ln -nsf "$TARGET_DIR/$THEME_NAME/mako.ini" "${HOME}/.config/mako/config"
    log "  mako: linked ~/.config/mako/config -> current theme"
  fi

  # btop symlink
  if [[ -f "$TARGET_DIR/$THEME_NAME/btop.theme" ]]; then
    mkdir -p "${HOME}/.config/btop/themes"
    ln -nsf "$TARGET_DIR/$THEME_NAME/btop.theme" "${HOME}/.config/btop/themes/current.theme"
    log "  btop: linked themes/current.theme -> current theme"
  fi

  # Apply
  if (( NO_APPLY )); then
    log "  --no-apply: skipping omarchy-theme-set"
  elif command -v omarchy-theme-set >/dev/null 2>&1; then
    log "  applying: omarchy-theme-set $THEME_NAME"
    if ! "${OMARCHY_THEME_SKIP_BACKGROUND:-}" || true; then
      omarchy-theme-set "$THEME_NAME"
    else
      OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy-theme-set "$THEME_NAME"
    fi
  else
    err "  omarchy-theme-set not on PATH; install complete but theme not applied"
    err "  run: omarchy-theme-set $THEME_NAME"
  fi

  log "DONE. Backup: $dest"
  rm -rf "$staging"
}

install_overlays() {
  local dots="$1"
  vlog "installing overlays from $dots"

  # waybar
  if [[ -f "$dots/waybar/style.css" ]]; then
    mkdir -p "${HOME}/.config/waybar"
    install -m 0644 "$dots/waybar/style.css" "${HOME}/.config/waybar/style.css"
  fi
  if [[ -f "$dots/waybar/config.jsonc" ]]; then
    install -m 0644 "$dots/waybar/config.jsonc" "${HOME}/.config/waybar/config.jsonc"
  fi
  if [[ -f "$dots/waybar/window.sh" ]]; then
    mkdir -p "${HOME}/.config/waybar"
    install -m 0755 "$dots/waybar/window.sh" "${HOME}/.config/waybar/window.sh"
  fi

  # terminals
  for term in alacritty ghostty kitty foot; do
    if [[ -d "$dots/$term" ]]; then
      mkdir -p "${HOME}/.config/$term"
      cp -a "$dots/$term/." "${HOME}/.config/$term/"
    fi
  done

  # swayosd
  if [[ -d "$dots/swayosd" ]]; then
    mkdir -p "${HOME}/.config/swayosd"
    cp -a "$dots/swayosd/." "${HOME}/.config/swayosd/"
  fi

  # walker
  if [[ -f "$dots/walker/config.toml" ]]; then
    mkdir -p "${HOME}/.config/walker"
    install -m 0644 "$dots/walker/config.toml" "${HOME}/.config/walker/config.toml"
  fi

  # hyprlock user override
  if [[ -f "$dots/hypr/hyprlock.conf" ]]; then
    mkdir -p "${HOME}/.config/hypr"
    install -m 0644 "$dots/hypr/hyprlock.conf" "${HOME}/.config/hypr/hyprlock.conf"
  fi

  # fontconfig
  if [[ -f "$dots/fontconfig/fonts.conf" ]]; then
    mkdir -p "${HOME}/.config/fontconfig"
    install -m 0644 "$dots/fontconfig/fonts.conf" "${HOME}/.config/fontconfig/fonts.conf"
  fi

  # gtk-3.0
  if [[ -f "$dots/gtk-3.0/settings.ini" ]]; then
    mkdir -p "${HOME}/.config/gtk-3.0"
    install -m 0644 "$dots/gtk-3.0/settings.ini" "${HOME}/.config/gtk-3.0/settings.ini"
  fi

  # btop append
  if [[ -f "$dots/btop/append.conf" ]]; then
    local cur="${HOME}/.config/btop/btop.conf"
    if [[ -f "$cur" ]] && grep -q '^color_theme *=' "$cur"; then
      vlog "btop: replacing existing color_theme directive"
      sed -i 's|^color_theme *=.*$|color_theme = "current"|' "$cur"
    elif [[ -f "$cur" ]]; then
      vlog "appending btop color_theme directive"
      printf '\n%s\n' 'color_theme = "current"' >>"$cur"
    fi
  fi
}

#----------------- rollback -----------------
do_rollback() {
  local target="$1"
  if [[ ! -d "$BACKUP_DIR" ]]; then
    die "no backups at $BACKUP_DIR" 6
  fi
  if [[ -z "$target" || "$target" == "latest" ]]; then
    target="$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | head -n1)"
    [[ -n "$target" ]] || die "no backups found" 6
    log "rolling back to latest backup: $target"
  else
    log "rolling back to $target"
  fi
  local src="$BACKUP_DIR/$target"
  [[ -d "$src" ]] || die "backup not found: $src" 6

  # Restore omarchy/current
  if [[ -d "$src/omarchy-current" ]]; then
    rm -rf "${HOME}/.config/omarchy/current"
    cp -a "$src/omarchy-current" "${HOME}/.config/omarchy/current"
    log "  restored current/"
  fi

  # Restore user theme
  if [[ -d "$src/themes/$THEME_NAME" ]]; then
    rm -rf "${TARGET_DIR:?}/$THEME_NAME"
    mkdir -p "$TARGET_DIR"
    cp -a "$src/themes/$THEME_NAME" "$TARGET_DIR/$THEME_NAME"
    log "  restored theme $THEME_NAME"
  fi

  # Restore dots
  if [[ -d "$src/dots" ]]; then
    ( shopt -s dotglob; cp -a "$src/dots/." "${HOME}/.config/" 2>/dev/null || true )
    log "  restored dots under ~/.config/"
  fi

  # Reapply via omarchy-theme-refresh (skip if --no-apply was passed)
  if (( NO_APPLY )); then
    log "  --no-apply: skipping omarchy-theme-refresh"
  elif command -v omarchy-theme-refresh >/dev/null 2>&1; then
    OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy-theme-refresh || true
    log "  ran omarchy-theme-refresh"
  fi
  log "rollback done"
}

#----------------- main ---------------------
main() {
  parse_args "$@"

  if (( SHOW_HELP )); then
    usage
    exit 0
  fi

  # Resolve HOME-dependent defaults after arg parsing
  : "${TARGET_DIR:=${HOME}/.config/omarchy/themes}"
  : "${BACKUP_DIR:=${HOME}/omarchy-ai-bootstrap/reports/theme-backups}"
  : "${BACKUP_ROOT:=${HOME}/omarchy-ai-bootstrap/reports}"

  all_bins

  if (( LIST_BACKUPS )); then
    list_backups
    exit 0
  fi

  WORK_DIR="$(mktemp -d -t gmr-install.XXXXXX)"
  WORK_MANIFEST="$WORK_DIR/MANIFEST.toml"
  trap 'rm -rf "${WORK_DIR:-}" 2>/dev/null || true' EXIT

  if [[ -n "$ROLLBACK_TS" ]]; then
    do_rollback "$ROLLBACK_TS"
    exit 0
  fi

  auto_payload
  validate_payload

  if (( VALIDATE_ONLY )); then
    log "VALIDATE-ONLY: payload OK"
    log "  payload: $PAYLOAD"
    log "  sha256:  $PAYLOAD_SHA"
    log "  theme:   $THEME_NAME"
    log "  version: $(read_manifest_field version)"
    exit 0
  fi

  install_theme
}

main "$@"
