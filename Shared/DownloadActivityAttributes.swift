//
//  DownloadActivityAttributes.swift
//  Shared between the Lumina app and the LuminaWidgets extension (compiled into both).
//

#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

struct DownloadActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var filename: String
        var fraction: Double      // 0...1, or negative when indeterminate
        var bytesWritten: Int64
        var totalBytes: Int64
        var isProcessing: Bool
    }

    var title: String
}
#endif
