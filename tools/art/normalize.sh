#!/usr/bin/env bash
# Normalize an AI-generated asset to the GreedMiner style-A palette.
# Usage: tools/art/normalize.sh input.png output.png [max_size_px]
# Requires: ImageMagick (magick) and pngquant.  brew install imagemagick pngquant
set -euo pipefail
IN="$1"; OUT="$2"; SIZE="${3:-128}"
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
# 1) remove the flat grey #808080 background, 2) trim, 3) fit to SIZE,
# 4) snap every pixel to the palette (no dithering keeps flat tones flat).
magick "$IN" -fuzz 6% -transparent "#808080" -trim +repage \
  -resize "${SIZE}x${SIZE}>" \
  -dither None -remap "$HERE/palette.png" "$TMP/remapped.png"
pngquant --force --quality 80-100 --strip --output "$OUT" "$TMP/remapped.png"
rm -rf "$TMP"
echo "$OUT: $(wc -c < "$OUT") bytes"
