#!/usr/bin/env bash
# Converte os renders .mp4 da pasta Render para a versão web, gera videos.js
# e publica no GitHub. Uso (Git Bash):  bash atualizar.sh
set -euo pipefail
cd "$(dirname "$0")"
RENDER_DIR=".."
mkdir -p videos

entries=()
shopt -s nullglob
for src in "$RENDER_DIR"/*.mp4; do
  name="$(basename "$src" .mp4)"
  title="${name#Painel de Led - }"
  slug="$(echo "$title" | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')"
  out="videos/$slug.mp4"
  if [ ! -f "$out" ] || [ "$src" -nt "$out" ]; then
    echo "Convertendo: $name"
    ffmpeg -v error -y -i "$src" -c:v libx264 -crf 17 -preset slow -pix_fmt yuv420p \
      -movflags +faststart -c:a aac -b:a 192k "$out"
    ffmpeg -v error -y -ss 2 -i "$out" -frames:v 1 -q:v 3 "videos/$slug.jpg"
  fi
  dur="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out")"
  secs="$(printf '%.0f' "$dur")"
  entries+=("  { title: \"$title\", src: \"$out\", poster: \"videos/$slug.jpg\", duration: \"0:$(printf '%02d' "$secs")\" }")
done

{
  echo "// Gerado por atualizar.sh — lista de vídeos exibidos no painel."
  echo "window.VIDEOS = ["
  for i in "${!entries[@]}"; do
    sep=","; [ "$i" -eq $((${#entries[@]} - 1)) ] && sep=""
    echo "${entries[$i]}$sep"
  done
  echo "];"
} > videos.js

echo "videos.js atualizado com ${#entries[@]} vídeo(s)."

if [ "${1:-}" != "--sem-push" ]; then
  git add -A
  git commit -m "Atualiza vídeos do painel" || echo "Nada novo para publicar."
  git push
fi
