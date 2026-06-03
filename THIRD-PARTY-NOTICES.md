# Third-Party Notices

Lumina bundles the following third-party software.

## FFmpeg

Lumina includes libraries from the **FFmpeg** project (https://ffmpeg.org), used for
on-device media processing (Cobalt `local-processing`: merge / remux / mute / audio).

- **Version:** 7.1
- **License:** GNU Lesser General Public License, version 2.1 or later (LGPL-2.1-or-later)
- **Configuration:** built with `--disable-gpl --disable-nonfree` and **no external
  libraries** (no libx264, libx265, libmp3lame, libfdk-aac, etc.). The result contains
  only FFmpeg's own LGPL-licensed components. No GPL or non-free code is included.
- **Build recipe:** the exact configuration used to produce the bundled binaries is in
  [`scripts/build-ffmpeg.sh`](scripts/build-ffmpeg.sh). Run it to reproduce or to relink
  against a modified FFmpeg.
- **Source:** the corresponding source is available at https://ffmpeg.org/releases/ and is
  selected by `FFMPEG_VERSION` in the build script.

The full text of the LGPL-2.1 license is distributed with the FFmpeg source.

> Note on Apple platforms: because iOS apps are statically linked and cannot relink at
> runtime, LGPL compliance is satisfied by (a) shipping only LGPL components, (b) providing
> the build recipe above so the library can be rebuilt/relinked, and (c) this attribution.
> Review with your own counsel before App Store submission. FFmpeg can be excluded from a
> build by removing the `CFFmpeg` dependency from `LuminaKit/Package.swift`; the app then
> falls back to the AVFoundation engine (h264/AAC only).
