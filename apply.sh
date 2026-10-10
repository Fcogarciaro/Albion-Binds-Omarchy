#!/usr/bin/env bash
# Escribe ~/.config/hypr/albion-binds.lua con el contenido recibido en $1,
# se asegura de que hyprland.lua lo cargue y recarga Hyprland solo si algo cambió.
set -euo pipefail

content="$1"
hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
target="$hypr_dir/albion-binds.lua"
main="$hypr_dir/hyprland.lua"
marker='pcall(require, "hypr.albion-binds")'
changed=0

if ! printf '%s' "$content" | cmp -s - "$target" 2>/dev/null; then
  tmp="$(mktemp "$target.XXXXXX")"
  printf '%s' "$content" >"$tmp"
  mv "$tmp" "$target"
  changed=1
fi

if [[ -f $main ]] && ! grep -qF "$marker" "$main"; then
  printf '\n-- Albion Binds (plugin fcogarcia.albion-binds): atajos solo para Albion Online.\n%s\n' "$marker" >>"$main"
  changed=1
fi

if (( changed )); then
  hyprctl reload config-only >/dev/null
  sleep 0.3
fi

errors="$(hyprctl configerrors 2>/dev/null | grep -i albion || true)"
if [[ -n $errors ]]; then
  echo "$errors" >&2
  exit 1
fi
echo ok
