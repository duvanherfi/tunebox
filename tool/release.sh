#!/usr/bin/env bash
#
# Build, sign, tag and publish a release.
#
# Run by hand from the repo root, with the notes for this version:
#
#     tool/release.sh docs/releases/v0.1.4.md
#
# There is no store here: the APK this produces is the only way an update
# reaches anybody, and the in-app updater refuses one that is not signed by the
# same key as the copy already installed. So the two things that would quietly
# produce an unusable release — a build that fell back to the debug key, and a
# shrinker that ate the drawables the media controls reach by name — are
# checked here rather than discovered by whoever installs it.
#
# The signing key is read from android/key.properties, which is not in the
# repository. Without it Gradle falls back to the debug key and this stops.
set -euo pipefail

cd "$(dirname "$0")/.."

notes=${1:-}
[[ -n "$notes" && -f "$notes" ]] || {
  echo "usage: tool/release.sh <notes-file>" >&2
  exit 1
}

for tool in flutter git gh; do
  command -v "$tool" >/dev/null || { echo "missing $tool" >&2; exit 1; }
done

sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
# The newest build-tools installed; these two live only inside the SDK.
tools=$(ls -d "$sdk"/build-tools/*/ 2>/dev/null | sort -V | tail -1)
apksigner="${tools}apksigner"
aapt2="${tools}aapt2"
[[ -x "$apksigner" && -x "$aapt2" ]] || {
  echo "no apksigner/aapt2 under $sdk/build-tools" >&2
  exit 1
}

[[ -f android/key.properties ]] || {
  echo "android/key.properties missing — this would sign with the debug key" >&2
  exit 1
}

[[ -z "$(git status --porcelain)" ]] || {
  echo "working tree is dirty; commit or stash first" >&2
  exit 1
}

branch=$(git rev-parse --abbrev-ref HEAD)
[[ "$branch" == main ]] || { echo "on $branch, not main" >&2; exit 1; }

# `0.1.4+5` — the version line is the single source for both numbers.
full=$(sed -n 's/^version: *//p' pubspec.yaml | tr -d '[:space:]')
version=${full%%+*}
build=${full##*+}
tag="v$version"
[[ "$version" != "$build" ]] || {
  echo "pubspec version '$full' has no build number" >&2
  exit 1
}

git rev-parse -q --verify "refs/tags/$tag" >/dev/null && {
  echo "$tag already exists; bump version in pubspec.yaml first" >&2
  exit 1
}
gh release view "$tag" >/dev/null 2>&1 && {
  echo "$tag is already published" >&2
  exit 1
}

echo "==> $tag ($full)"

flutter pub get
flutter analyze
flutter test

flutter build apk --release

apk=build/app/outputs/flutter-apk/app-release.apk
# The build number rides in the file name because a GitHub release has nowhere
# else to put it, and the updater reads it from there to decide.
asset="build/tunebox-$full.apk"
cp "$apk" "$asset"

echo "==> signature"
signed=$("$apksigner" verify --print-certs "$asset" \
  | sed -n 's/.*certificate SHA-256 digest: *//p' | tr 'A-Z' 'a-z')
store=$(sed -n 's/^storeFile=//p' android/key.properties)
alias=$(sed -n 's/^keyAlias=//p' android/key.properties)
password=$(sed -n 's/^storePassword=//p' android/key.properties)
expected=$(keytool -list -v -keystore "android/$store" -alias "$alias" \
  -storepass "$password" \
  | sed -n 's/.*SHA256: *//p' | tr -d ':' | tr 'A-Z' 'a-z')
grep -qx "$expected" <<<"$signed" || {
  echo "the apk is not signed by the release key — nobody could install it" >&2
  exit 1
}
echo "signed by $alias"

echo "==> pinned drawables"
# Every drawable Dart reaches by name, checked inside the built APK rather than
# against res/raw/keep.xml. The unit test already keeps keep.xml in step with
# the Dart sources; what it cannot know is whether the shrinker obeyed it, and
# that is the failure that only exists in a release build. If one is gone,
# getIdentifier answers 0, audio_service throws out of every setPlaybackState,
# and the notification and the car's media session die with it.
missing=()
resources=$("$aapt2" dump resources "$asset")
while read -r drawable; do
  grep -q "drawable/$drawable" <<<"$resources" || missing+=("$drawable")
done < <(
  grep -rhoE "'(drawable/)?ic_[a-z0-9_]+'" lib \
    | tr -d "'" | sed 's|^drawable/||' | sort -u
)
((${#missing[@]} == 0)) || {
  echo "the shrinker deleted: ${missing[*]}" >&2
  exit 1
}
echo "all pinned drawables survived"

echo "==> publishing"
git tag -a "$tag" -m "Tunebox $version"
git push origin "$tag"
gh release create "$tag" "$asset#tunebox-$full.apk" \
  --title "Tunebox $version" \
  --notes-file "$notes"

echo "==> $tag published"
