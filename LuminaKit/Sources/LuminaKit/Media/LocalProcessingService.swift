import Foundation

/// Downloads a `local-processing` response's tunnel streams to disk and runs them through
/// the `LocalProcessor`, producing a single finished file.
public struct LocalProcessingService: Sendable {
    private let session: URLSession
    private let processor: LocalProcessor

    public init(session: URLSession = .shared, processor: LocalProcessor = LocalProcessor()) {
        self.session = session
        self.processor = processor
    }

    /// - Parameters:
    ///   - payload: the decoded `local-processing` response.
    ///   - auth: optional `Authorization` applied to each tunnel GET.
    ///   - directory: a working directory for the inputs and the final output.
    /// - Returns: the URL of the produced file (named after `payload.output.filename`).
    public func process(payload: LocalProcessingPayload,
                        auth: CobaltConfiguration.Auth?,
                        in directory: URL) async throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var inputs: [URL] = []
        for (index, tunnel) in payload.tunnels.enumerated() {
            var request = URLRequest(url: tunnel)
            if let auth { request.setValue(auth.headerValue, forHTTPHeaderField: "Authorization") }
            let destination = directory.appending(path: "input-\(index)")
            do {
                let (tmp, response) = try await session.download(for: request)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw LuminaError.from(httpStatus: http.statusCode)
                }
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: tmp, to: destination)
                inputs.append(destination)
            } catch let error as LuminaError {
                throw error
            } catch let urlError as URLError {
                throw LuminaError.from(urlError: urlError)
            }
        }

        let output = directory.appending(path: payload.output.filename.isEmpty ? "output" : payload.output.filename)
        let job = LocalProcessingJob(payload: payload, downloadedInputs: inputs, outputURL: output)
        let result = try await processor.process(job)

        for input in inputs { try? FileManager.default.removeItem(at: input) }
        return result
    }
}
