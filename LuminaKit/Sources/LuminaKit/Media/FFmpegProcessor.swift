import Foundation

#if canImport(CFFmpeg)
import CFFmpeg

/// FFmpeg-backed engine. Performs container muxing (merge / remux / mute / audio) by
/// stream-copying packets with libavformat — no re-encoding, so it handles VP9 / AV1 /
/// Opus / webm / mkv that AVFoundation can't. `gif` (which needs a filter graph) is not
/// yet implemented and falls through.
public struct FFmpegProcessor: LocalProcessingEngine {
    public init() {}

    public func canHandle(_ job: LocalProcessingJob) -> Bool {
        switch job.kind {
        case .merge, .mute, .remux, .audio: true
        case .gif: false
        }
    }

    public func process(_ job: LocalProcessingJob) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try FFmpegMuxer.run(job)
        }.value
    }
}

/// Synchronous libavformat stream-copy muxer.
enum FFmpegMuxer {
    static func run(_ job: LocalProcessingJob) throws -> URL {
        try? FileManager.default.removeItem(at: job.outputURL)

        var outCtx: UnsafeMutablePointer<AVFormatContext>?
        guard job.outputURL.path.withCString({ avformat_alloc_output_context2(&outCtx, nil, nil, $0) }) >= 0,
              let outCtx else {
            throw LuminaError.unsupportedLocalProcessing(reason: "could not create output for \(job.outputMIME)")
        }
        defer {
            if (Int32(outCtx.pointee.oformat.pointee.flags) & AVFMT_NOFILE) == 0 {
                avio_closep(&outCtx.pointee.pb)
            }
            avformat_free_context(outCtx)
        }

        var inputs: [UnsafeMutablePointer<AVFormatContext>?] = []
        var streamMaps: [[Int32: Int32]] = []
        defer { for var ctx in inputs { avformat_close_input(&ctx) } }

        for (index, url) in job.inputs.enumerated() {
            var inCtx: UnsafeMutablePointer<AVFormatContext>?
            guard url.path.withCString({ avformat_open_input(&inCtx, $0, nil, nil) }) == 0, let inCtx else {
                throw LuminaError.unsupportedLocalProcessing(reason: "could not open input \(url.lastPathComponent)")
            }
            inputs.append(inCtx)
            guard avformat_find_stream_info(inCtx, nil) >= 0 else {
                throw LuminaError.unsupportedLocalProcessing(reason: "could not read streams in \(url.lastPathComponent)")
            }

            var map: [Int32: Int32] = [:]
            for s in 0..<Int(inCtx.pointee.nb_streams) {
                guard let stream = inCtx.pointee.streams[s] else { continue }
                let type = stream.pointee.codecpar.pointee.codec_type
                guard include(kind: job.kind, inputIndex: index, totalInputs: job.inputs.count, type: type) else { continue }
                guard let outStream = avformat_new_stream(outCtx, nil) else {
                    throw LuminaError.unsupportedLocalProcessing(reason: "could not allocate output stream")
                }
                guard avcodec_parameters_copy(outStream.pointee.codecpar, stream.pointee.codecpar) >= 0 else {
                    throw LuminaError.unsupportedLocalProcessing(reason: "could not copy codec parameters")
                }
                outStream.pointee.codecpar.pointee.codec_tag = 0
                map[Int32(s)] = outStream.pointee.index
            }
            streamMaps.append(map)
        }

        if let metadata = job.metadata {
            for (key, value) in metadata {
                key.withCString { ck in value.withCString { cv in
                    av_dict_set(&outCtx.pointee.metadata, ck, cv, 0)
                } }
            }
        }

        if (Int32(outCtx.pointee.oformat.pointee.flags) & AVFMT_NOFILE) == 0 {
            guard job.outputURL.path.withCString({ avio_open(&outCtx.pointee.pb, $0, AVIO_FLAG_WRITE) }) >= 0 else {
                throw LuminaError.unsupportedLocalProcessing(reason: "could not open output file")
            }
        }
        guard avformat_write_header(outCtx, nil) >= 0 else {
            throw LuminaError.unsupportedLocalProcessing(reason: "could not write \(job.outputMIME) header")
        }

        guard let pkt = av_packet_alloc() else {
            throw LuminaError.unsupportedLocalProcessing(reason: "out of memory")
        }
        defer { var p: UnsafeMutablePointer<AVPacket>? = pkt; av_packet_free(&p) }

        for (index, inCtx) in inputs.enumerated() {
            guard let inCtx else { continue }
            let map = streamMaps[index]
            while av_read_frame(inCtx, pkt) >= 0 {
                let inIndex = pkt.pointee.stream_index
                guard let outIndex = map[inIndex],
                      let inStream = inCtx.pointee.streams[Int(inIndex)],
                      let outStream = outCtx.pointee.streams[Int(outIndex)] else {
                    av_packet_unref(pkt)
                    continue
                }
                pkt.pointee.stream_index = outIndex
                av_packet_rescale_ts(pkt, inStream.pointee.time_base, outStream.pointee.time_base)
                pkt.pointee.pos = -1
                _ = av_interleaved_write_frame(outCtx, pkt)
                av_packet_unref(pkt)
            }
        }

        guard av_write_trailer(outCtx) >= 0 else {
            throw LuminaError.unsupportedLocalProcessing(reason: "could not finalize \(job.outputMIME)")
        }
        return job.outputURL
    }

    private static func include(kind: LocalProcessingPayload.Kind, inputIndex: Int, totalInputs: Int, type: AVMediaType) -> Bool {
        switch kind {
        case .remux:
            type == AVMEDIA_TYPE_VIDEO || type == AVMEDIA_TYPE_AUDIO || type == AVMEDIA_TYPE_SUBTITLE
        case .mute:
            type == AVMEDIA_TYPE_VIDEO || type == AVMEDIA_TYPE_SUBTITLE
        case .audio:
            type == AVMEDIA_TYPE_AUDIO
        case .merge:
            totalInputs >= 2
                ? (inputIndex == 0 ? (type == AVMEDIA_TYPE_VIDEO || type == AVMEDIA_TYPE_SUBTITLE) : type == AVMEDIA_TYPE_AUDIO)
                : (type == AVMEDIA_TYPE_VIDEO || type == AVMEDIA_TYPE_AUDIO || type == AVMEDIA_TYPE_SUBTITLE)
        case .gif:
            false
        }
    }
}

#else

/// Stub used when the FFmpeg xcframework isn't linked into this build.
public struct FFmpegProcessor: LocalProcessingEngine {
    public init() {}
    public func canHandle(_ job: LocalProcessingJob) -> Bool { false }
    public func process(_ job: LocalProcessingJob) async throws -> URL {
        throw LuminaError.unsupportedLocalProcessing(
            reason: String(localized: "on-device processing isn’t available in this build"))
    }
}

#endif
