//
//  LiveActivityController.swift
//  Lumina
//
//  Starts/updates/ends a Live Activity per active download. Uses ActivityKit local updates
//  only (no push, no App Group), so it works on a free team. iOS-only.
//

import Foundation

#if canImport(ActivityKit) && os(iOS)
// Activity is a non-Sendable class whose update/end are nonisolated async; @preconcurrency
// downgrades the cross-isolation Sendable diagnostics for this known ActivityKit friction.
@preconcurrency import ActivityKit

@MainActor
enum LiveActivityController {
    private static var activities: [UUID: Activity<DownloadActivityAttributes>] = [:]

    static func sync(_ progress: DownloadProgress) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let isProcessing: Bool = { if case .processing = progress.state { return true }; return false }()
        let content = ActivityContent(
            state: DownloadActivityAttributes.ContentState(
                filename: progress.filename,
                fraction: progress.fraction ?? -1,
                bytesWritten: progress.bytesWritten,
                totalBytes: progress.totalBytes,
                isProcessing: isProcessing),
            staleDate: nil)

        if progress.isFinished {
            if let activity = activities.removeValue(forKey: progress.id) {
                await activity.end(content, dismissalPolicy: .after(.now + 3))
            }
            return
        }

        if let activity = activities[progress.id] {
            await activity.update(content)
        } else {
            let attributes = DownloadActivityAttributes(title: progress.filename)
            if let activity = try? Activity.request(attributes: attributes, content: content, pushType: nil) {
                activities[progress.id] = activity
            }
        }
    }
}

#else

enum LiveActivityController {
    @MainActor static func sync(_ progress: DownloadProgress) async {}
}

#endif
