#!/bin/bash
# Font Standardization Script - Fix Editor Plugin Font Sizes
# Converts all non-compliant font sizes to Monogram-approved sizes

EDITOR_DIR="addons/sparkling_editor/ui"

# Fix each violation size
# 9px -> 16px
find "$EDITOR_DIR" -name "*.gd" -type f -exec sed -i 's/add_theme_font_size_override("font_size", 9)/add_theme_font_size_override("font_size", 16)/g' {} +

# 10px -> 16px
find "$EDITOR_DIR" -name "*.gd" -type f -exec sed -i 's/add_theme_font_size_override("font_size", 10)/add_theme_font_size_override("font_size", 16)/g' {} +

# 11px -> 16px
find "$EDITOR_DIR" -name "*.gd" -type f -exec sed -i 's/add_theme_font_size_override("font_size", 11)/add_theme_font_size_override("font_size", 16)/g' {} +

# 12px -> 16px
find "$EDITOR_DIR" -name "*.gd" -type f -exec sed -i 's/add_theme_font_size_override("font_size", 12)/add_theme_font_size_override("font_size", 16)/g' {} +

# 14px -> 16px
find "$EDITOR_DIR" -name "*.gd" -type f -exec sed -i 's/add_theme_font_size_override("font_size", 14)/add_theme_font_size_override("font_size", 16)/g' {} +

# 18px -> 16px
find "$EDITOR_DIR" -name "*.gd" -type f -exec sed -i 's/add_theme_font_size_override("font_size", 18)/add_theme_font_size_override("font_size", 16)/g' {} +

echo "Editor font standardization complete!"
echo "All editor UI fonts now comply with Monogram standards (16px minimum)"
