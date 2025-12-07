#!/bin/bash
# Generate placeholder app icons for AppIcon.appiconset
# Usage:
#   ./scripts/generate_appicon_placeholders.sh [source.png]
# If source.png is provided and is at least 1024x1024, it will be resized into all required slots.
# If no source is provided, simple colored placeholders will be generated.

set -euo pipefail

WORKDIR="${PWD}"
ASSETS_DIR="SwiftBmo/Assets.xcassets/AppIcon.appiconset"
OUTDIR="$WORKDIR/$ASSETS_DIR"

mkdir -p "$OUTDIR"

# Define sizes and filenames (match Contents.json)
declare -a sizes=("16:icon_16x16.png" "32:icon_16x16@2x.png" "32:icon_32x32.png" "64:icon_32x32@2x.png" "128:icon_128x128.png" "256:icon_128x128@2x.png" "256:icon_256x256.png" "512:icon_256x256@2x.png" "512:icon_512x512.png" "1024:icon_512x512@2x.png")

SRC="$1"

if [ -n "${SRC-}" ] && [ -f "$SRC" ]; then
  echo "Using source image: $SRC"
  for entry in "${sizes[@]}"; do
    SIZE=${entry%%:*}
    FNAME=${entry#*:}
    OUT="$OUTDIR/$FNAME"
    echo "Generating $OUT ($SIZE x $SIZE)"
    # Use sips if available
    if command -v sips >/dev/null 2>&1; then
      sips -Z $SIZE "$SRC" --out "$OUT" >/dev/null
    else
      # Fallback to Python pillow if sips isn't available
      python3 - <<PY
from PIL import Image
im = Image.open('$SRC').convert('RGBA')
im = im.resize(($SIZE,$SIZE), Image.LANCZOS)
im.save('$OUT')
PY
    fi
  done
  echo "Generated icons in $OUTDIR"
else
  echo "No source image provided; creating colored placeholders."
  for entry in "${sizes[@]}"; do
    SIZE=${entry%%:*}
    FNAME=${entry#*:}
    OUT="$OUTDIR/$FNAME"
    echo "Creating placeholder $OUT ($SIZE x $SIZE)"
    # Use sips to create a simple colored PNG
    if command -v sips >/dev/null 2>&1; then
      sips -s format png --resampleHeightWidthMax $SIZE --out "$OUT" "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" >/dev/null 2>&1 || \
      convert -size ${SIZE}x${SIZE} xc:#88CCFF "$OUT" >/dev/null 2>&1 || \
      echo "Failed to create via sips; ensure ImageMagick 'convert' is installed or provide a source PNG."
    else
      # Use python pillow as fallback
      python3 - <<PY
from PIL import Image, ImageDraw
SIZE = $SIZE
img = Image.new('RGBA', (SIZE, SIZE), (136,204,255,255))
draw = ImageDraw.Draw(img)
# optional simple mark
r = SIZE//8
draw.ellipse((SIZE//2 - r, SIZE//2 - r, SIZE//2 + r, SIZE//2 + r), fill=(255,255,255,200))
img.save('$OUT')
PY
    fi
  done
  echo "Created placeholder icons in $OUTDIR"
fi

echo "Done. Add/refresh files in Xcode if needed."
