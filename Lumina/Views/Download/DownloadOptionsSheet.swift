//
//  DownloadOptionsSheet.swift
//  Lumina
//

import SwiftUI
import LuminaKit

/// The options form, reused by the fetch sheet and the Settings "default options" screen.
struct DownloadOptionsForm: View {
    @Binding var options: DownloadOptions

    var body: some View {
        Form {
            Section("Video") {
                picker("Quality", selection: $options.videoQuality, VideoQuality.allCases) { $0.displayName }
                picker("Mode", selection: $options.downloadMode, DownloadMode.allCases) { $0.displayName }
            }
            Section("Audio") {
                picker("Format", selection: $options.audioFormat, AudioFormat.allCases) { $0.displayName }
                picker("Bitrate", selection: $options.audioBitrate, AudioBitrate.allCases) { $0.displayName }
            }
            Section("Files") {
                picker("Filename style", selection: $options.filenameStyle, FilenameStyle.allCases) { $0.displayName }
                Toggle("Strip metadata", isOn: $options.disableMetadata)
                Toggle("Always proxy through instance", isOn: $options.alwaysProxy)
            }
            Section("YouTube") {
                picker("Codec", selection: $options.youtubeVideoCodec, YouTubeVideoCodec.allCases) { $0.displayName }
                picker("Container", selection: $options.youtubeVideoContainer, YouTubeVideoContainer.allCases) { $0.displayName }
                Toggle("Better audio bitrate", isOn: $options.youtubeBetterAudio)
            }
            Section {
                picker("On-device processing", selection: $options.localProcessing, LocalProcessingMode.allCases) { $0.displayName }
                Toggle("Convert GIFs", isOn: $options.convertGif)
                Toggle("Allow H.265 (X/Twitter)", isOn: $options.allowH265)
                Toggle("Full TikTok audio", isOn: $options.tiktokFullAudio)
            } header: {
                Text("Advanced")
            } footer: {
                Text("On-device processing merges separate video/audio streams with the bundled engine.")
            }
        }
        .formStyle(.grouped)
    }

    private func picker<T: CaseIterable & Identifiable & Hashable>(
        _ title: String,
        selection: Binding<T>,
        _ cases: T.AllCases,
        label: @escaping (T) -> String
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(Array(cases)) { value in
                Text(label(value)).tag(value)
            }
        }
    }
}

struct DownloadOptionsSheet: View {
    @Binding var options: DownloadOptions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DownloadOptionsForm(options: $options)
                .navigationTitle("Options")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }
}
