#!/usr/bin/env bash
#
# Render the app mark into every platform's icon slot.
#
# Run by hand after editing icon.svg or icon-macos.svg, from the repo root:
#
#     tool/icons/generate.sh
#
# The outputs are committed. This is deliberately not a build step: the art
# changes about once a year, the renderers are not something every checkout has,
# and a build that silently rewrites tracked binaries makes every diff a
# question. Needs `rsvg-convert` (librsvg) and `magick` (ImageMagick):
#
#     brew install librsvg imagemagick
#
set -euo pipefail

cd "$(dirname "$0")/../.."
here=tool/icons
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for tool in rsvg-convert magick; do
  command -v "$tool" >/dev/null || { echo "missing $tool — brew install librsvg imagemagick" >&2; exit 1; }
done

# render <source.svg> <size> <destination.png>
render() {
  mkdir -p "$(dirname "$3")"
  rsvg-convert -w "$2" -h "$2" "$1" -o "$3"
}

echo "Android — the legacy bitmaps. API 26 and up draw the adaptive icon from"
echo "          mipmap-anydpi-v26 instead and never look at these."
render "$here/icon.svg"  48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
render "$here/icon.svg"  72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
render "$here/icon.svg"  96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
render "$here/icon.svg" 144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
render "$here/icon.svg" 192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

echo "macOS — from the grid variant. Sizes and names come from the catalogue's"
echo "        Contents.json, which pairs each one with a 1x and a 2x slot."
macos=macos/Runner/Assets.xcassets/AppIcon.appiconset
for size in 16 32 64 128 256 512 1024; do
  render "$here/icon-macos.svg" "$size" "$macos/app_icon_$size.png"
done

echo "iOS — full bleed; the system rounds the corners. The 1024 marketing icon"
echo "      is rejected with an alpha channel, so every one is flattened."
ios=ios/Runner/Assets.xcassets/AppIcon.appiconset
ios_icon() { # ios_icon <size> <filename>
  render "$here/icon.svg" "$1" "$work/ios.png"
  magick "$work/ios.png" -background '#C2185B' -alpha remove -alpha off "$ios/$2"
}
ios_icon   20 'Icon-App-20x20@1x.png'
ios_icon   40 'Icon-App-20x20@2x.png'
ios_icon   60 'Icon-App-20x20@3x.png'
ios_icon   29 'Icon-App-29x29@1x.png'
ios_icon   58 'Icon-App-29x29@2x.png'
ios_icon   87 'Icon-App-29x29@3x.png'
ios_icon   40 'Icon-App-40x40@1x.png'
ios_icon   80 'Icon-App-40x40@2x.png'
ios_icon  120 'Icon-App-40x40@3x.png'
ios_icon  120 'Icon-App-60x60@2x.png'
ios_icon  180 'Icon-App-60x60@3x.png'
ios_icon   76 'Icon-App-76x76@1x.png'
ios_icon  152 'Icon-App-76x76@2x.png'
ios_icon  167 'Icon-App-83.5x83.5@2x.png'
ios_icon 1024 'Icon-App-1024x1024@1x.png'

echo "Windows — one .ico carrying every size Explorer picks between."
for size in 16 24 32 48 64 128 256; do
  render "$here/icon.svg" "$size" "$work/win-$size.png"
done
magick "$work"/win-16.png "$work"/win-24.png "$work"/win-32.png \
       "$work"/win-48.png "$work"/win-64.png "$work"/win-128.png \
       "$work"/win-256.png windows/runner/resources/app_icon.ico

echo "Linux — nothing reads this yet. Flutter's Linux shell has no icon slot,"
echo "        and the app dies in AudioService.init there anyway; the file is"
echo "        here so packaging has something to point at when that changes."
render "$here/icon.svg" 512 linux/runner/resources/app_icon.png

echo "done"
