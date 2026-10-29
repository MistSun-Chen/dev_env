#!/usr/bin/env bash
# Apply Catppuccin Mocha to the current/default GNOME Terminal profile.
# This is opt-in: dev_env's installer only copies this file and never runs it.
set -euo pipefail

command -v gsettings >/dev/null 2>&1 || {
  echo "gsettings not found; this script is for GNOME Terminal only." >&2
  exit 1
}

PROFILE="$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")"
[[ -n "$PROFILE" ]] || {
  echo "No default GNOME Terminal profile found." >&2
  exit 1
}

BASE="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${PROFILE}/"

gsettings set "$BASE" use-theme-colors false
gsettings set "$BASE" background-color '#1e1e2e'
gsettings set "$BASE" foreground-color '#cdd6f4'
gsettings set "$BASE" cursor-colors-set true
gsettings set "$BASE" cursor-background-color '#f5e0dc'
gsettings set "$BASE" cursor-foreground-color '#1e1e2e'
gsettings set "$BASE" highlight-colors-set true
gsettings set "$BASE" highlight-background-color '#585b70'
gsettings set "$BASE" highlight-foreground-color '#cdd6f4'
gsettings set "$BASE" bold-is-bright true
gsettings set "$BASE" palette "['#45475a', '#f38ba8', '#a6e3a1', '#f9e2af', '#89b4fa', '#f5c2e7', '#94e2d5', '#bac2de', '#585b70', '#f38ba8', '#a6e3a1', '#f9e2af', '#89b4fa', '#f5c2e7', '#94e2d5', '#a6adc8']"

echo "Applied Catppuccin Mocha to GNOME Terminal profile: $PROFILE"
