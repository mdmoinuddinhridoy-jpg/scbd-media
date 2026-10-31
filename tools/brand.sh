#!/usr/bin/env bash
# Brand an image or video for Secret Collection BD.
# Top-left: original logo exactly as given (tools/logo-original.png) - colours/text unchanged,
# 25% of media width, 3% margin, 100% opacity, Lanczos resize + light sharpen so it stays crisp when zoomed.
# Images: PNG lossless / JPG quality 98 (4:4:4); video CRF 16 (near-lossless), audio copied.
# Usage: tools/brand.sh <input> <output>
set -euo pipefail
IN="$1"; OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
LOGO_SIZE=0.25; MARGIN=0.03; OPACITY=1.0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$IN")
LW=$(awk "BEGIN{printf \"%d\", $W*$LOGO_SIZE}")
M=$(awk "BEGIN{printf \"%d\", $W*$MARGIN}")
# Optional: LOGO_Y_PCT=<fraction of height> to push logo down (e.g. below a supplier watermark)
H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$IN")
Y=$M; [[ -n "${LOGO_Y_PCT:-}" ]] && Y=$(awk "BEGIN{printf \"%d\", $H*$LOGO_Y_PCT}")

convert "$HERE/logo-original.png" -filter Lanczos -resize "${LW}x" -unsharp 0x0.6+0.6+0 -alpha set -channel A -evaluate multiply $OPACITY +channel "$TMP/logo.png"

case "${IN,,}" in
  *.png)
    convert "$IN" "$TMP/logo.png" -geometry +$M+$Y -composite "$OUT" ;;
  *.jpg|*.jpeg|*.webp)
    convert "$IN" "$TMP/logo.png" -geometry +$M+$Y -composite -sampling-factor 4:4:4 -quality 98 "$OUT" ;;
  *)
    ffmpeg -y -v error -i "$IN" -i "$TMP/logo.png" \
      -filter_complex "[0:v][1:v]overlay=$M:$Y" \
      -c:v libx264 -preset veryfast -crf 16 -pix_fmt yuv420p \
      -c:a copy -movflags +faststart "$OUT" ;;
esac
echo "Branded -> $OUT"
