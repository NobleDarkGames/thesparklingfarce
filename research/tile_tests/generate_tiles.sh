#!/bin/bash
# Generate a complete grass tileset with variations

OUTPUT_DIR="${1:-.}"
SIZE="${2:-32}"

# Base colors
BASE="#2D5A1D"
LIGHT="#4D7A3D"
DARK="#1D4A0D"
MID="#3D6A2D"

# Generate 4 variations with different noise seeds
for i in 1 2 3 4; do
    convert -size ${SIZE}x${SIZE} xc:"$BASE" \
        -seed $i \
        +noise Random -colorspace gray \
        \( +clone -threshold 85% -fill "$LIGHT" -opaque white -transparent black \) -composite \
        \( +clone -threshold 92% -fill "$DARK" -opaque white -transparent black \) -composite \
        -colorspace sRGB \
        "$OUTPUT_DIR/grass_v${i}.png"
done

# Create corner and edge pieces
# Top-left corner (grass fading to dirt)
convert -size ${SIZE}x${SIZE} xc:'#8B6914' \
    -fill "$BASE" -draw "polygon 0,0 ${SIZE},0 0,${SIZE}" \
    "$OUTPUT_DIR/grass_corner_tl.png"

echo "Generated tiles in $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"/*.png
