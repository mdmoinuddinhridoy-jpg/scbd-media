#!/usr/bin/env bash
# Brand an image or video for Secret Collection BD.
#  - Top-left: original logo exactly as given (tools/logo-original.png), 18% of width, 100% opacity
# Margin = 3% of width. Original quality kept (images q95, video CRF 18, audio copied).
# Usage: tools/brand.sh <input> <output>
set -euo pipefail
IN="$1"; OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
LOGO_SIZE=0.18; MARGIN=0.03
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$IN")
LW=$(awk "BEGIN{printf \"%d\", $W*$LOGO_SIZE}")
M=$(awk "BEGIN{printf \"%d\", $W*$MARGIN}")
convert "$HERE/logo-original.png" -resize "${LW}x" "$TMP/logo.png"

case "${IN,,}" in
  *.jpg|*.jpeg|*.png|*.webp)
    convert "$IN" "$TMP/logo.png" -geometry +$M+$M -composite -quality 95 "$OUT" ;;
  *)
    ffmpeg -y -v error -i "$IN" -i "$TMP/logo.png" \
      -filter_complex "[0:v][1:v]overlay=$M:$M" \
      -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p \
      -c:a copy -movflags +faststart "$OUT" ;;
esac
echo "Branded -> $OUT"
