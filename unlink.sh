#!/usr/bin/env bash
set -euo pipefail

MANIFEST="$HOME/.local/share/dotfiles/manifest"

if [[ ! -f "$MANIFEST" ]]; then
  echo "No manifest found at $MANIFEST; nothing to unlink."
  exit 0
fi

while IFS='|' read -r dst backup; do
  [[ -z "$dst" ]] && continue
  if [[ -L "$dst" ]]; then
    rm "$dst"
    echo "[unlink] removed $dst"
  fi
  if [[ -n "$backup" && -e "$backup" ]]; then
    mv "$backup" "$dst"
    echo "[unlink] restored $dst from $backup"
  fi
done < "$MANIFEST"

rm "$MANIFEST"
echo "[unlink] Done."
