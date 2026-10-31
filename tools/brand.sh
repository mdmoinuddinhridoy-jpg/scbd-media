#!/usr/bin/env bash
# Brand an image or video for Secret Collection BD.
# Logo top-left, margin = 3% of width.
#  - Image logo (tools/logo.png): width 18%, 80% opacity
#  - Text logo (fallback): elegant serif, white fill + solid black outline, width 40%, 100% opacity
# Usage: tools/brand.sh <input> <output> [logo.png]
# Env: FONT=<ttf name in tools/fonts> (default PlayfairDisplay-Bold.ttf)
set -euo pipefail
IN="$1"; OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
LOGO="${3:-$HERE/logo.png}"
FONT="$HERE/fonts/${FONT:-PlayfairDisplay-Bold.ttf}"
OPACITY=0.8; SIZE=0.18; MARGIN=0.03
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

if [[ ! -f "$LOGO" ]]; then
  OPACITY=1.0; SIZE=0.40
  LOGO="$TMP/textlogo.png"
  convert -background none -fill white -font "$FONT" -pointsize 220 label:"Secret Collection BD" \
    -bordercolor none -border 30 "$TMP/t.png"
  # solid black outline around white text
  convert "$TMP/t.png" \( +clone -fill black -colorize 100 -channel RGBA -morphology Dilate Disk:14 +channel \) \
    +swap -compose over -composite -trim +repage "$LOGO"
fi

W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$IN")
LW=$(awk "BEGIN{printf \"%d\", $W*$SIZE}")
M=$(awk "BEGIN{printf \"%d\", $W*$MARGIN}")

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
