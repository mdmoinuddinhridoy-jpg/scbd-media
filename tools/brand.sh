#!/usr/bin/env bash
# Brand an image or video for Secret Collection BD.
# Logo top-left, 80% opacity, width = 18% of media width, margin = 3% of width.
# Usage: tools/brand.sh <input> <output> [logo.png]
# If no logo is given (and tools/logo.png is missing), a text logo is generated.
set -euo pipefail
IN="$1"; OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
LOGO="${3:-$HERE/logo.png}"
OPACITY=0.8; SIZE=0.18; MARGIN=0.03
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT


if [[ ! -f "$LOGO" ]]; then
  LOGO="$TMP/textlogo.png"
  SIZE=0.30
  convert -background none -fill white -font Poppins-Bold -pointsize 200 label:"Secret Collection BD" "$TMP/t.png"
  # white text with solid black outline
  convert "$TMP/t.png" -bordercolor none -border 30 \( +clone -fill black -colorize 100 -channel RGBA -morphology Dilate Disk:9 +channel \) \
    +swap -compose over -composite +repage "$LOGO"
fi

W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$IN")
LW=$(awk "BEGIN{printf \"%d\", $W*$SIZE}")
M=$(awk "BEGIN{printf \"%d\", $W*$MARGIN}")

# Resize logo and apply opacity
convert "$LOGO" -resize "${LW}x" -alpha on -channel A -evaluate multiply $OPACITY +channel "$TMP/logo.png"

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
