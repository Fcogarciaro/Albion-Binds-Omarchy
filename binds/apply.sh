#!/usr/bin/env bash
# Escribe ~/.config/hypr/albion-companion.lua con el contenido recibido en $1,
# se asegura de que hyprland.lua lo cargue y recarga Hyprland solo si algo cambió.
set -euo pipefail

content="$1"
hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
target="$hypr_dir/albion-companion.lua"
main="$hypr_dir/hyprland.lua"
marker='pcall(require, "hypr.albion-companion")'
legacy_marker='pcall(require, "hypr.albion-binds")'
legacy_comment='-- Albion Binds (plugin fcogarcia.albion-binds)'
legacy_target="$hypr_dir/albion-binds.lua"
changed=0

# Write through symlinks (dotfiles setups): mv over a link would replace it
# with a regular file. Temp files are created next to the real file.
real_target="$(readlink -f -- "$target")"
real_main="$(readlink -f -- "$main")"
tmp=""
trap '[[ -z $tmp ]] || rm -f -- "$tmp"' EXIT

if ! printf '%s' "$content" | cmp -s - "$target" 2>/dev/null; then
  tmp="$(mktemp "$real_target.XXXXXX")"
  printf '%s' "$content" >"$tmp"
  # Refuse to install a file Lua cannot compile (when luac is available).
  if command -v luac >/dev/null 2>&1; then
    if ! lua_errors="$(luac -p "$tmp" 2>&1)"; then
      rm -f "$tmp"
      echo "$lua_errors" >&2
      exit 1
    fi
  fi
  mv "$tmp" "$real_target"
  tmp=""
  changed=1
fi

# Cleanup of the pre-rename plugin (fcogarcia.albion-binds): drop its loader
# line and comment (exact lines only) and its generated file.
if [[ -f $main ]] && { grep -qxF "$legacy_marker" "$main" || grep -q "^$legacy_comment" "$main"; }; then
  tmp="$(mktemp "$real_main.XXXXXX")"
  grep -vxF "$legacy_marker" "$main" | grep -v "^$legacy_comment" >"$tmp" || true
  chmod --reference="$real_main" "$tmp" 2>/dev/null || true
  mv "$tmp" "$real_main"
  tmp=""
  changed=1
fi
if [[ -f $legacy_target ]]; then
  rm -f "$legacy_target"
  changed=1
fi

if [[ -f $main ]] && ! grep -qF "$marker" "$main"; then
  printf '\n-- Albion Companion (plugin fcogarcia.albion-companion): atajos solo para Albion Online.\n%s\n' "$marker" >>"$main"
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
