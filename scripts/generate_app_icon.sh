#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_SVG="$ROOT_DIR/voiceKey/Resources/AppIconSource.svg"
ICONSET_DIR="$ROOT_DIR/voiceKey/Resources/Assets.xcassets/AppIcon.appiconset"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/voicekey-appicon.XXXXXX")"
OPAQUE_JPEG="$TMP_DIR/AppIconSource-flat.jpg"
OPAQUE_PNG="$TMP_DIR/AppIconSource-flat.png"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if ! command -v qlmanage >/dev/null 2>&1; then
  echo "qlmanage is not available."
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "sips is not available."
  exit 1
fi

if [[ ! -f "$SOURCE_SVG" ]]; then
  echo "Missing source SVG: $SOURCE_SVG"
  exit 1
fi

mkdir -p "$ICONSET_DIR"
rm -f "$ICONSET_DIR"/*.png

qlmanage -t -s 1024 -o "$TMP_DIR" "$SOURCE_SVG" >/dev/null 2>&1

SOURCE_PNG="$TMP_DIR/$(basename "$SOURCE_SVG").png"
if [[ ! -f "$SOURCE_PNG" ]]; then
  echo "Failed to render $SOURCE_SVG"
  exit 1
fi

# Strip alpha so Finder/Dock won't blend transparent edge pixels into gray on light backgrounds.
sips -s format jpeg -s formatOptions best "$SOURCE_PNG" --out "$OPAQUE_JPEG" >/dev/null 2>&1
sips -s format png "$OPAQUE_JPEG" --out "$OPAQUE_PNG" >/dev/null 2>&1

generate_icon() {
  local filename="$1"
  local size="$2"
  sips -z "$size" "$size" "$OPAQUE_PNG" --out "$ICONSET_DIR/$filename" >/dev/null 2>&1
}

generate_icon "icon_16x16.png" 16
generate_icon "icon_16x16@2x.png" 32
generate_icon "icon_32x32.png" 32
generate_icon "icon_32x32@2x.png" 64
generate_icon "icon_128x128.png" 128
generate_icon "icon_128x128@2x.png" 256
generate_icon "icon_256x256.png" 256
generate_icon "icon_256x256@2x.png" 512
generate_icon "icon_512x512.png" 512
generate_icon "icon_512x512@2x.png" 1024

cat > "$ICONSET_DIR/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Generated $ICONSET_DIR"
