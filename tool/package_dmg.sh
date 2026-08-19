#!/usr/bin/env bash
#
# Wrap the macOS build into the disk image that gets published:
#
#     tool/package_dmg.sh
#
# `flutter build macos --release` stops at tunebox.app, which is a directory:
# attached to a release, a browser hands the reader a folder of Mach-O files.
# The .dmg is the envelope macOS expects, and the symlink next to the app is
# the entire install procedure — drag one onto the other.
#
# Run from the release workflow and by hand, so a local disk image and a
# published one are built by the same code.
#
# The signature inside is ad-hoc: the Xcode project asks for identity "-",
# which needs no certificate and no Apple account. That is enough for macOS to
# run the app, and it is not Developer ID, so a copy that arrives through a
# browser carries the quarantine attribute and Gatekeeper refuses it until the
# reader allows it by hand. Only notarising removes that step, and notarising
# needs the paid certificate.
set -euo pipefail

cd "$(dirname "$0")/.."

app=build/macos/Build/Products/Release/tunebox.app
[[ -d "$app" ]] || {
  echo "no $app — run flutter build macos --release first" >&2
  exit 1
}

full=$(sed -n 's/^version: *//p' pubspec.yaml | tr -d '[:space:]')
out="build/tunebox-$full.dmg"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"

rm -f "$out"
hdiutil create -volname "Tunebox $full" -srcfolder "$stage" -ov -format UDZO "$out" >/dev/null

# Read it back the way a reader would rather than trusting that it was written:
# mount it and look at the app inside. A disk image whose bundle has a broken
# seal builds without complaining and only fails on somebody else's machine.
mnt=$(hdiutil attach "$out" -nobrowse -readonly | tail -1 | awk -F'\t' '{print $NF}')
detach() { hdiutil detach "$mnt" -quiet 2>/dev/null || true; rm -rf "$stage"; }
trap detach EXIT

inside="$mnt/tunebox.app"
[[ -d "$inside" ]] || { echo "$out carries no tunebox.app" >&2; exit 1; }
codesign --verify --deep --strict "$inside" || {
  echo "the app inside $out does not verify its own signature" >&2
  exit 1
}

# The runner that builds this is arm64, and an app built for the host alone
# would install on an Intel Mac and refuse to open there — a failure nobody
# holding the machine that made it can see.
arches=$(lipo -archs "$inside/Contents/MacOS/tunebox")
for arch in x86_64 arm64; do
  grep -qw "$arch" <<<"$arches" || {
    echo "the app inside $out is missing $arch (has: $arches)" >&2
    exit 1
  }
done

# The bundle takes its version from pubspec through Flutter's generated
# xcconfig; if that ever came loose the disk image would be named after one
# version and carry another.
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$inside/Contents/Info.plist")
[[ "$build" == "${full##*+}" ]] || {
  echo "$out is named for build ${full##*+} but carries $build" >&2
  exit 1
}

echo "$out — universal, signed $(codesign -dv "$inside" 2>&1 | sed -n 's/^Signature=//p'), build $build"
