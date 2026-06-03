#!/bin/bash
#
# make-appicon.sh — render Lumina's app icon (a download glyph on an indigo→blue gradient)
# at 1024px with CoreGraphics, then downscale for the macOS sizes and write Contents.json.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$REPO_ROOT/Lumina/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"

cat > "$TMP/render.swift" <<'SWIFT'
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let s = CGFloat(size)
let space = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                    bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Background gradient (indigo -> blue), top to bottom.
let top = CGColor(red: 0.36, green: 0.30, blue: 0.92, alpha: 1)
let bottom = CGColor(red: 0.16, green: 0.52, blue: 0.96, alpha: 1)
let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

// White download glyph. CoreGraphics origin is bottom-left, so convert from a top-down model.
func y(_ td: CGFloat) -> CGFloat { s - td * s }
let cx = s / 2
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(s * 0.085)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

// Arrow stem + chevron (pointing down).
ctx.move(to: CGPoint(x: cx, y: y(0.27)))
ctx.addLine(to: CGPoint(x: cx, y: y(0.58)))
ctx.move(to: CGPoint(x: cx - s * 0.15, y: y(0.44)))
ctx.addLine(to: CGPoint(x: cx, y: y(0.58)))
ctx.addLine(to: CGPoint(x: cx + s * 0.15, y: y(0.44)))
ctx.strokePath()

// Tray bracket underneath.
ctx.move(to: CGPoint(x: s * 0.28, y: y(0.66)))
ctx.addLine(to: CGPoint(x: s * 0.28, y: y(0.74)))
ctx.addLine(to: CGPoint(x: s * 0.72, y: y(0.74)))
ctx.addLine(to: CGPoint(x: s * 0.72, y: y(0.66)))
ctx.strokePath()

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("png write failed") }
SWIFT

echo "==> Rendering 1024 master"
swift "$TMP/render.swift" "$ICONSET/icon-1024.png"

scale() { sips -z "$1" "$1" "$ICONSET/icon-1024.png" --out "$ICONSET/icon-$1.png" >/dev/null; }
echo "==> Downscaling macOS sizes"
for px in 16 32 64 128 256 512; do scale "$px"; done

echo "==> Writing Contents.json"
cat > "$ICONSET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "filename" : "icon-16.png",  "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon-32.png",  "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon-32.png",  "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon-64.png",  "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon-128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon-256.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon-256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon-512.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon-512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon-1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "==> Done"
ls -1 "$ICONSET"
rm -rf "$TMP"
