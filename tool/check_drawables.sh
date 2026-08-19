#!/usr/bin/env bash
#
# Every drawable Dart reaches by name, checked inside a built APK:
#
#     tool/check_drawables.sh build/app/outputs/flutter-apk/app-release.apk
#
# Not against res/raw/keep.xml. The unit test already keeps keep.xml in step
# with the Dart sources; what it cannot know is whether the shrinker obeyed it,
# and that is the failure that only exists in a release build. If one is gone,
# getIdentifier answers 0, audio_service throws out of every setPlaybackState,
# and the notification and the car's media session die with it.
#
# Run from both tool/release.sh and CI, so the release and the branch are
# checked by the same code.
set -euo pipefail

cd "$(dirname "$0")/.."

apk=${1:-}
[[ -n "$apk" && -f "$apk" ]] || {
  echo "usage: tool/check_drawables.sh <apk>" >&2
  exit 1
}

sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
# The newest build-tools installed; aapt2 lives only inside the SDK.
aapt2=$(ls -d "$sdk"/build-tools/*/ 2>/dev/null | sort -V | tail -1)aapt2
[[ -x "$aapt2" ]] || { echo "no aapt2 under $sdk/build-tools" >&2; exit 1; }

# Both spellings: the media controls pass 'drawable/ic_x', the car's shelves
# pass a bare 'ic_auto_x' to a helper that prefixes it.
drawables=()
while read -r drawable; do
  drawables+=("$drawable")
done < <(
  grep -rhoE "'(drawable/)?ic_[a-z0-9_]+'" lib \
    | tr -d "'" | sed 's|^drawable/||' | sort -u
)
((${#drawables[@]} > 0)) || { echo "no drawable names found in lib/" >&2; exit 1; }

resources=$("$aapt2" dump resources "$apk")
missing=()
for drawable in "${drawables[@]}"; do
  grep -q "drawable/$drawable" <<<"$resources" || missing+=("$drawable")
done

((${#missing[@]} == 0)) || {
  echo "the shrinker deleted: ${missing[*]}" >&2
  exit 1
}
echo "all ${#drawables[@]} pinned drawables survived"
