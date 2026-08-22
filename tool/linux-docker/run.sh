#!/usr/bin/env bash
# Builds the Linux app in the container and runs it under a virtual screen,
# leaving a screenshot behind. See the Dockerfile for what this does and does
# not prove.
#
#   tool/linux-docker/run.sh [seconds-before-the-screenshot]
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
wait_for="${1:-25}"

docker build -t tunebox-linux "$repo/tool/linux-docker"

# The repository is mounted rather than copied so a rebuild is a rebuild and
# not a fresh clone. Two directories get a volume of their own instead: build/,
# because build/ here holds a macOS build and the two toolchains overwrite each
# other's caches, and .dart_tool/, because `pub get` writes absolute paths into
# it — the container's, which leave the analyser on this machine pointing at
# /opt/flutter and reporting thousands of errors until pub get is run again.
docker run --rm \
  -v "$repo:/app" \
  -v tunebox-linux-build:/app/build \
  -v tunebox-linux-dart-tool:/app/.dart_tool \
  tunebox-linux bash -c "
    set -e
    flutter pub get
    flutter build linux --debug
    export DISPLAY=:99
    Xvfb :99 -screen 0 1280x900x24 &
    sleep 3
    build/linux/*/debug/bundle/tunebox &
    sleep $wait_for
    import -window root /app/linux-shot.png
  "
echo "shot: $repo/linux-shot.png"
