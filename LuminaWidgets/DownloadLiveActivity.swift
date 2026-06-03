//
//  DownloadLiveActivity.swift
//  LuminaWidgets
//
//  Lock Screen + Dynamic Island presentation for an in-progress download.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct DownloadLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            LockScreenLiveActivityView(state: context.state)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.4))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: icon(context.state)).foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(percent(context.state)).font(.caption).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.filename).font(.caption).lineLimit(1)
                        progressView(context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: icon(context.state)).foregroundStyle(.tint)
            } compactTrailing: {
                Text(percent(context.state)).font(.caption2).monospacedDigit()
            } minimal: {
                Image(systemName: "arrow.down").foregroundStyle(.tint)
            }
        }
    }

    private func icon(_ state: DownloadActivityAttributes.ContentState) -> String {
        state.isProcessing ? "gearshape.2.fill" : "arrow.down.circle.fill"
    }

    private func percent(_ state: DownloadActivityAttributes.ContentState) -> String {
        guard state.fraction >= 0 else { return "" }
        return "\(Int(state.fraction * 100))%"
    }

    @ViewBuilder
    private func progressView(_ state: DownloadActivityAttributes.ContentState) -> some View {
        if state.isProcessing || state.fraction < 0 {
            ProgressView().progressViewStyle(.linear)
        } else {
            ProgressView(value: state.fraction)
        }
    }
}

struct LockScreenLiveActivityView: View {
    let state: DownloadActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.isProcessing ? "gearshape.2.fill" : "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(state.filename)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if state.isProcessing {
                    Text("Processing on device…").font(.caption).foregroundStyle(.secondary)
                } else if state.fraction >= 0 {
                    ProgressView(value: state.fraction)
                } else {
                    ProgressView().progressViewStyle(.linear)
                }
            }
            Spacer()
        }
    }
}
