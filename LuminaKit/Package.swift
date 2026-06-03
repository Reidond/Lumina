// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LuminaKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "LuminaKit", targets: ["LuminaKit"]),
    ],
    targets: [
        // Vendored LGPL FFmpeg (built by scripts/build-ffmpeg.sh). iOS + macOS arm64 slices.
        .binaryTarget(name: "CFFmpeg", path: "Frameworks/LuminaFFmpeg.xcframework"),
        .target(
            name: "LuminaKit",
            dependencies: ["CFFmpeg"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ],
            linkerSettings: [
                // System dependencies of FFmpeg's static libraries on Apple platforms.
                .linkedLibrary("z"),
                .linkedLibrary("bz2"),
                .linkedLibrary("iconv"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("AudioToolbox"),
            ]
        ),
        .testTarget(
            name: "LuminaKitTests",
            dependencies: ["LuminaKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
