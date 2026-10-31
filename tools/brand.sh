#!/usr/bin/env bash
# Brand an image or video for Secret Collection BD.
#  - Top-left : brand name (tools/name.png) - Poppins, white with solid black outline, 45% of width
#  - Top-right: original logo exactly as given (tools/logo-original.png), 18% of width
# Margin = 3% of width. 100% opacity. Original quality kept (images q95, video CRF 18, audio copied).
# Usage: tools/brand.sh <input> <output>
set -euo pipefail
IN="$1"; OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME_SIZE=0.45; LOGO_SIZE=0.18; MARGIN=0.03
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$IN")
NW=$(awk "BEGIN{printf \"%d\", $W*$NAME_SIZE}")
LW=$(awk "BEGIN{printf \"%d\", $W*$LOGO_SIZE}")
M=$(awk "BEGIN{printf \"%d\", $W*$MARGIN}")
LX=$((W - LW - M))

convert "$HERE/name.png" -resize "${NW}x" "$TMP/name.png"
convert "$HERE/logo-original.png" -resize "${LW}x" "$TMP/logo.png"
# vertically centre the name against the logo
NH=$(identify -format %h "$TMP/name.png"); LH=$(identify -format %h "$TMP/logo.png")
NY=$(( M + (LH - NH) / 2 ))

case "${IN,,}" in
  *.jpg|*.jpeg|*.png|*.webp)
    convert "$IN" "$TMP/name.png" -geometry +$M+$NY -composite \
      "$TMP/logo.png" -geometry +$LX+$M -composite -quality 95 "$OUT" ;;
  *)
    ffmpeg -y -v error -i "$IN" -i "$TMP/name.png" -i "$TMP/logo.png" \
      -filter_complex "[0:v][1:v]overlay=$M:$NY[a];[a][2:v]overlay=$LX:$M" \
      -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p \
      -c:a copy -movflags +faststart "$OUT" ;;
esac
echo "Branded -> $OUT"
