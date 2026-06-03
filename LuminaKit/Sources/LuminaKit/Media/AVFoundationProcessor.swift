import Foundation
import AVFoundation

/// Fast-path engine for the common h264 + AAC case: merges separate video/audio into an
/// mp4/m4a, mutes (drops the audio track), or remuxes (passthrough). Cannot handle
/// webm/VP9/AV1/Opus/mkv or gif/audio-transcode — those fall through to `FFmpegProcessor`.
public struct AVFoundationProcessor: LocalProcessingEngine {
    public init() {}

    public func canHandle(_ job: LocalProcessingJob) -> Bool {
        guard MediaContainer.isAVFoundationFriendly(job.outputMIME)
                || MediaContainer.isAVFoundationFriendly(job.outputURL.lastPathComponent) else {
            return false
        }
        switch job.kind {
        case .merge, .mute, .remux:
            return job.inputs.allSatisfy { input in
                let ext = input.pathExtension.lowercased()
                return ext.isEmpty || ["mp4", "m4v", "mov", "m4a", "aac", "mp3", "caf"].contains(ext)
            }
        case .audio, .gif:
            return false
        }
    }

    public func process(_ job: LocalProcessingJob) async throws -> URL {
        switch job.kind {
        case .merge: return try await merge(job)
        case .mute: return try await mute(job)
        case .remux: return try await remux(job)
        case .audio, .gif:
            throw LuminaError.unsupportedLocalProcessing(reason: "AVFoundation cannot perform \(job.kind)")
        }
    }

    // MARK: - Operations

    private func merge(_ job: LocalProcessingJob) async throws -> URL {
        guard let first = job.inputs.first else {
            throw LuminaError.unsupportedLocalProcessing(reason: "merge needs at least one input")
        }
        let videoAsset = AVURLAsset(url: first)
        let composition = AVMutableComposition()

        if let vTrack = try await videoAsset.loadTracks(withMediaType: .video).first {
            let dur = try await videoAsset.load(.duration)
            let compV = composition.addMutableTrack(withMediaType: .video,
                                                    preferredTrackID: kCMPersistentTrackID_Invalid)
            try compV?.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: vTrack, at: .zero)
            compV?.preferredTransform = try await vTrack.load(.preferredTransform)
        }

        // Audio comes from the second input when present, else the first.
        let audioAsset = job.inputs.count >= 2 ? AVURLAsset(url: job.inputs[1]) : videoAsset
        if let aTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
            let dur = try await audioAsset.load(.duration)
            let compA = composition.addMutableTrack(withMediaType: .audio,
                                                    preferredTrackID: kCMPersistentTrackID_Invalid)
            try compA?.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: aTrack, at: .zero)
        }

        return try await export(composition, to: job.outputURL, mime: job.outputMIME)
    }

    private func mute(_ job: LocalProcessingJob) async throws -> URL {
        guard let first = job.inputs.first else {
            throw LuminaError.unsupportedLocalProcessing(reason: "mute needs an input")
        }
        let asset = AVURLAsset(url: first)
        let composition = AVMutableComposition()
        guard let vTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw LuminaError.unsupportedLocalProcessing(reason: "no video track to keep")
        }
        let dur = try await asset.load(.duration)
        let compV = composition.addMutableTrack(withMediaType: .video,
                                                preferredTrackID: kCMPersistentTrackID_Invalid)
        try compV?.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: vTrack, at: .zero)
        compV?.preferredTransform = try await vTrack.load(.preferredTransform)
        return try await export(composition, to: job.outputURL, mime: job.outputMIME)
    }

    private func remux(_ job: LocalProcessingJob) async throws -> URL {
        guard let first = job.inputs.first else {
            throw LuminaError.unsupportedLocalProcessing(reason: "remux needs an input")
        }
        return try await export(AVURLAsset(url: first), to: job.outputURL, mime: job.outputMIME)
    }

    // MARK: - Export

    private func export(_ asset: AVAsset, to url: URL, mime: String) async throws -> URL {
        // Passthrough = stream copy (no re-encode), which is what merge/mute/remux need.
        // If the tracks aren't passthrough-compatible the export throws and the caller
        // falls through to the FFmpeg engine.
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw LuminaError.unsupportedLocalProcessing(reason: "passthrough export unavailable")
        }
        try? FileManager.default.removeItem(at: url)
        do {
            try await session.export(to: url, as: fileType(for: mime, url: url))
        } catch {
            throw LuminaError.unsupportedLocalProcessing(reason: error.localizedDescription)
        }
        return url
    }

    private func fileType(for mime: String, url: URL) -> AVFileType {
        let ext = url.pathExtension.lowercased()
        if mime.contains("m4a") || ext == "m4a" { return .m4a }
        if mime.contains("quicktime") || ext == "mov" { return .mov }
        return .mp4
    }
}
