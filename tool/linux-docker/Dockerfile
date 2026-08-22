# Building and running the Linux app from a Mac.
#
# Flutter desktop cannot be cross-compiled: a Linux build has to happen on
# Linux. A container is the cheap way to get one — cheaper than a VM, and on
# Apple Silicon the only one that runs at native speed. What it proves is the
# part this project can prove without a Linux machine: that the app compiles,
# that the GTK folder picker opens and answers, and that the walk finds what is
# in the folder it names. What it cannot prove is sound: there is no audio
# plugin for Linux yet, and no audio device here either.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# clang, cmake, ninja and GTK are what `flutter build linux` asks for — lld
# too, which Debian's clang package leaves out and the Dart build looks for by
# name inside the LLVM directory, and llvm for the llvm-ar it looks for
# there too;
# libsecret is flutter_secure_storage's; xvfb and imagemagick are how a
# headless container ends up producing a screenshot, and xdotool is how it
# gets clicked.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils zip \
      clang lld llvm cmake ninja-build pkg-config \
      libgtk-3-dev liblzma-dev libsecret-1-dev libglu1-mesa \
      xvfb x11-utils imagemagick dbus-x11 xdotool \
    && rm -rf /var/lib/apt/lists/*

# Pinned to what CI and the Mac use. An SDK that moves on its own turns an
# unrelated morning into a bisect.
ARG FLUTTER_VERSION=3.41.6
RUN git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Root owning the checkout is the normal case in a container and git refuses to
# read it otherwise, which stops flutter before it starts.
RUN git config --global --add safe.directory /opt/flutter \
    && git config --global --add safe.directory '*' \
    && flutter config --no-analytics --enable-linux-desktop \
    && flutter precache --linux

WORKDIR /app
