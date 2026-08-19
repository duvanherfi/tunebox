#!/usr/bin/env bash
#
# The apk is signed by the release key, not by the debug one:
#
#     tool/check_signature.sh build/tunebox-0.1.5+6.apk
#
# Gradle falls back to the debug key when android/key.properties is missing,
# and it does that quietly — the build succeeds and the apk installs on the
# machine that made it. What it cannot do is install over a copy signed by the
# real key, which is every copy anybody already has. So a release that fell
# back is not a broken build, it is a file nobody can use, and the only way to
# tell them apart is to read the certificate back out of the apk.
#
# Run from both tool/release.sh and the release workflow, so a local build and
# a published one are checked by the same code. Both write key.properties
# first: on a laptop it is already there, in CI the job writes it from the
# environment's secrets.
set -euo pipefail

cd "$(dirname "$0")/.."

apk=${1:-}
[[ -n "$apk" && -f "$apk" ]] || {
  echo "usage: tool/check_signature.sh <apk>" >&2
  exit 1
}

[[ -f android/key.properties ]] || {
  echo "android/key.properties missing — there is nothing to compare against" >&2
  exit 1
}

sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
# The newest build-tools installed; apksigner lives only inside the SDK.
apksigner=$(ls -d "$sdk"/build-tools/*/ 2>/dev/null | sort -V | tail -1)apksigner
[[ -x "$apksigner" ]] || { echo "no apksigner under $sdk/build-tools" >&2; exit 1; }

# Every certificate the apk carries: v2 and v3 are both on, so this is more
# than one line and any of them matching is the answer.
signed=$("$apksigner" verify --print-certs "$apk" \
  | sed -n 's/.*certificate SHA-256 digest: *//p' | tr 'A-Z' 'a-z')

store=$(sed -n 's/^storeFile=//p' android/key.properties)
alias=$(sed -n 's/^keyAlias=//p' android/key.properties)
password=$(sed -n 's/^storePassword=//p' android/key.properties)
# storeFile is resolved against android/, which is Gradle's root project here.
expected=$(keytool -list -v -keystore "android/$store" -alias "$alias" \
  -storepass "$password" \
  | sed -n 's/.*SHA256: *//p' | tr -d ':' | tr 'A-Z' 'a-z')

grep -qx "$expected" <<<"$signed" || {
  echo "the apk is not signed by the release key — nobody could install it" >&2
  exit 1
}
echo "signed by $alias"
