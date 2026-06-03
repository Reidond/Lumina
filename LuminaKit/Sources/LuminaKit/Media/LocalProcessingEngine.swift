import Foundation

/// A unit of on-device work derived from a Cobalt `local-processing` response: the
/// already-downloaded tunnel files plus the desired output.
public struct LocalProcessingJob: Sendable {
    public let kind: LocalProcessingPayload.Kind
    /// Downloaded tunnel files, in the order the instance returned them.
    public let inputs: [URL]
    public let outputURL: URL
    public let outputMIME: String
    public let metadata: [String: String]?

    public init(kind: LocalProcessingPayload.Kind,
                inputs: [URL],
                outputURL: URL,
                outputMIME: String,
                metadata: [String: String]? = nil) {
        self.kind = kind
        self.inputs = inputs
        self.outputURL = outputURL
        self.outputMIME = outputMIME
        self.metadata = metadata
    }

    /// Build a job from a payload and the local files its tunnels were downloaded to.
    public init(payload: LocalProcessingPayload, downloadedInputs: [URL], outputURL: URL) {
        self.init(kind: payload.type,
                  inputs: downloadedInputs,
                  outputURL: outputURL,
                  outputMIME: payload.output.type,
                  metadata: payload.output.metadata)
    }
}

/// A pluggable engine that performs a `LocalProcessingJob`. Lumina ships an
/// `AVFoundationProcessor` (h264/AAC fast path) and an `FFmpegProcessor` (everything
/// else, when the FFmpeg xcframework is linked).
public protocol LocalProcessingEngine: Sendable {
    /// A quick, synchronous capability check (by container/kind), used to pick an engine.
    func canHandle(_ job: LocalProcessingJob) -> Bool
    /// Perform the job, returning the URL of the produced file (== job.outputURL on success).
    func process(_ job: LocalProcessingJob) async throws -> URL
}

/// Tries each engine in order (most-capable first), falling back on failure.
public struct LocalProcessor: Sendable {
    private let engines: [any LocalProcessingEngine]

    public init(engines: [any LocalProcessingEngine] = LocalProcessor.defaultEngines) {
        self.engines = engines
    }

    public static var defaultEngines: [any LocalProcessingEngine] {
        [FFmpegProcessor(), AVFoundationProcessor()]
    }

    public func process(_ job: LocalProcessingJob) async throws -> URL {
        var lastError: Error?
        for engine in engines where engine.canHandle(job) {
            do {
                return try await engine.process(job)
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        throw LuminaError.unsupportedLocalProcessing(
            reason: String(localized: "no engine can process \(job.outputMIME)"))
    }
}

/// Small helpers shared by the engines.
enum MediaContainer {
    /// True when the file extension / MIME is one AVFoundation can mux natively.
    static func isAVFoundationFriendly(_ urlOrMIME: String) -> Bool {
        let s = urlOrMIME.lowercased()
        for token in ["mp4", "m4a", "m4v", "mov", "quicktime", "aac", "mp3", "mpeg-4"] where s.contains(token) {
            return true
        }
        return false
    }
}
