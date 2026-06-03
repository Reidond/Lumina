#!/bin/bash
#
# build-ffmpeg.sh — build a trimmed, LGPL FFmpeg as an xcframework for Lumina.
#
# Produces ThirdParty/FFmpeg/LuminaFFmpeg.xcframework with arm64 slices for:
#   - iOS device (iphoneos)
#   - iOS simulator (iphonesimulator)
#   - macOS (macosx)
#
# LICENSING: configured with --disable-gpl --disable-nonfree and NO external libraries
# (no libx264/x265/libmp3lame/etc.), so the result is plain LGPL FFmpeg with only its
# native components. This covers Cobalt local-processing of type merge / remux / mute
# (container muxing, stream copy) plus native audio transcode and gif. To add x86_64
# slices (Intel Macs / Rosetta CI), append x86_64 to the ARCH lists below.
#
# Usage:  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/build-ffmpeg.sh
#
set -euo pipefail

FFMPEG_VERSION="7.1"
IOS_MIN="18.0"
MAC_MIN="15.0"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# The xcframework must live inside the LuminaKit SwiftPM package (binary target paths
# cannot escape the package root).
OUT_DIR="$REPO_ROOT/LuminaKit/Frameworks"
WORK_DIR="$OUT_DIR/build"
SRC_DIR="$WORK_DIR/ffmpeg-$FFMPEG_VERSION"
XCFRAMEWORK="$OUT_DIR/LuminaFFmpeg.xcframework"

mkdir -p "$WORK_DIR"

# ---- 1. Fetch source --------------------------------------------------------
if [ ! -d "$SRC_DIR" ]; then
  echo "==> Downloading FFmpeg $FFMPEG_VERSION"
  curl -fL "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" -o "$WORK_DIR/ffmpeg.tar.xz"
  tar -xf "$WORK_DIR/ffmpeg.tar.xz" -C "$WORK_DIR"
fi

# Combined component selection (LGPL, native only).
COMMON_CONFIG=(
  --disable-gpl --disable-nonfree
  --disable-programs --disable-doc --disable-debug
  --disable-avdevice --disable-postproc
  --disable-network --disable-asm
  --enable-static --disable-shared --enable-pic
  --enable-cross-compile --target-os=darwin
)

build_slice() {
  local platform="$1" arch="$2" sdk="$3" minflag="$4"
  local prefix="$WORK_DIR/$platform-$arch"
  local sysroot
  sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"
  local cc="xcrun --sdk $sdk clang"

  echo "==> Configuring $platform/$arch (sdk=$sdk)"
  ( cd "$SRC_DIR" && make distclean >/dev/null 2>&1 || true )
  ( cd "$SRC_DIR" && ./configure \
      --prefix="$prefix" \
      --arch="$arch" \
      --cc="$cc" \
      --sysroot="$sysroot" \
      --extra-cflags="-arch $arch $minflag -isysroot $sysroot -fno-common" \
      --extra-ldflags="-arch $arch $minflag -isysroot $sysroot" \
      "${COMMON_CONFIG[@]}" >/dev/null )

  echo "==> Building $platform/$arch"
  ( cd "$SRC_DIR" && make -j"$(sysctl -n hw.ncpu)" >/dev/null && make install >/dev/null )

  # Merge the individual static libs into one.
  echo "==> Combining libraries for $platform/$arch"
  libtool -static -o "$prefix/libLuminaFFmpeg.a" \
    "$prefix"/lib/libavformat.a \
    "$prefix"/lib/libavcodec.a \
    "$prefix"/lib/libavfilter.a \
    "$prefix"/lib/libswresample.a \
    "$prefix"/lib/libswscale.a \
    "$prefix"/lib/libavutil.a 2>/dev/null

  # Drop a Clang module map next to the headers for SwiftPM import.
  cat > "$prefix/include/module.modulemap" <<'EOF'
module CFFmpeg {
    header "libavformat/avformat.h"
    header "libavcodec/avcodec.h"
    header "libavutil/avutil.h"
    header "libavutil/imgutils.h"
    header "libavutil/opt.h"
    header "libavutil/channel_layout.h"
    header "libavutil/dict.h"
    header "libavutil/frame.h"
    header "libavutil/samplefmt.h"
    header "libavfilter/avfilter.h"
    header "libavfilter/buffersrc.h"
    header "libavfilter/buffersink.h"
    header "libswresample/swresample.h"
    header "libswscale/swscale.h"
    export *
}
EOF
}

# ---- 2. Build each arm64 slice ---------------------------------------------
build_slice "iphoneos"        "arm64" "iphoneos"        "-mios-version-min=$IOS_MIN"
build_slice "iphonesimulator" "arm64" "iphonesimulator" "-mios-simulator-version-min=$IOS_MIN"
build_slice "macosx"          "arm64" "macosx"          "-mmacosx-version-min=$MAC_MIN"

# ---- 3. Assemble the xcframework -------------------------------------------
echo "==> Creating xcframework"
rm -rf "$XCFRAMEWORK"
xcodebuild -create-xcframework \
  -library "$WORK_DIR/iphoneos-arm64/libLuminaFFmpeg.a"        -headers "$WORK_DIR/iphoneos-arm64/include" \
  -library "$WORK_DIR/iphonesimulator-arm64/libLuminaFFmpeg.a" -headers "$WORK_DIR/iphonesimulator-arm64/include" \
  -library "$WORK_DIR/macosx-arm64/libLuminaFFmpeg.a"          -headers "$WORK_DIR/macosx-arm64/include" \
  -output "$XCFRAMEWORK"

echo "==> Done: $XCFRAMEWORK"
du -sh "$XCFRAMEWORK"
