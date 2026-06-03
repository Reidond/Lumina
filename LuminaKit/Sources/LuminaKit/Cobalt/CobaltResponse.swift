import Foundation

/// A successful Cobalt response. There is intentionally **no** `.error` case: an
/// `"error"` status is decoded into a `CobaltErrorPayload` and thrown during decoding
/// (see `CobaltResponseErrorThrown`), which `CobaltClient` maps to a `LuminaError`.
public enum CobaltResponse: Sendable, Decodable {
    case tunnel(url: URL, filename: String)
    case redirect(url: URL, filename: String)
    case picker(items: [PickerItem], audio: URL?, audioFilename: String?)
    case localProcessing(LocalProcessingPayload)

    private enum CodingKeys: String, CodingKey {
        case status, url, filename, picker, audio, audioFilename
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let status = try c.decode(String.self, forKey: .status)
        switch status {
        case "tunnel":
            self = .tunnel(url: try CobaltDecoding.url(c, .url),
                           filename: try c.decodeIfPresent(String.self, forKey: .filename) ?? "download")
        case "redirect":
            self = .redirect(url: try CobaltDecoding.url(c, .url),
                             filename: try c.decodeIfPresent(String.self, forKey: .filename) ?? "download")
        case "picker":
            self = .picker(items: try c.decode([PickerItem].self, forKey: .picker),
                           audio: CobaltDecoding.optionalURL(c, .audio),
                           audioFilename: try c.decodeIfPresent(String.self, forKey: .audioFilename))
        case "local-processing":
            self = .localProcessing(try LocalProcessingPayload(from: decoder))
        case "error":
            throw CobaltResponseErrorThrown(payload: try CobaltErrorPayload(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .status, in: c, debugDescription: "Unknown status: \(status)")
        }
    }
}

/// A single selectable item from a `picker` response.
public struct PickerItem: Decodable, Sendable, Identifiable, Equatable {
    public enum Kind: String, Decodable, Sendable { case photo, video, gif }

    public let type: Kind
    public let url: URL
    public let thumb: URL?

    public var id: URL { url }

    private enum CodingKeys: String, CodingKey { case type, url, thumb }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = (try? c.decode(Kind.self, forKey: .type)) ?? .video
        self.url = try CobaltDecoding.url(c, .url)
        self.thumb = CobaltDecoding.optionalURL(c, .thumb)
    }

    public init(type: Kind, url: URL, thumb: URL? = nil) {
        self.type = type
        self.url = url
        self.thumb = thumb
    }
}

/// The `error` payload, thrown out of `CobaltResponse` decoding.
public struct CobaltErrorPayload: Decodable, Sendable, Equatable {
    public let code: String
    public let service: String?
    public let limit: Int?

    private enum Root: String, CodingKey { case error }
    private enum ErrorKeys: String, CodingKey { case code, context }
    private enum ContextKeys: String, CodingKey { case service, limit }

    public init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: Root.self)
        let err = try root.nestedContainer(keyedBy: ErrorKeys.self, forKey: .error)
        self.code = try err.decode(String.self, forKey: .code)
        if let ctx = try? err.nestedContainer(keyedBy: ContextKeys.self, forKey: .context) {
            self.service = try? ctx.decodeIfPresent(String.self, forKey: .service)
            self.limit = try? ctx.decodeIfPresent(Int.self, forKey: .limit)
        } else {
            self.service = nil
            self.limit = nil
        }
    }

    public init(code: String, service: String? = nil, limit: Int? = nil) {
        self.code = code
        self.service = service
        self.limit = limit
    }
}

/// Internal error used to surface a decoded `error` payload through `JSONDecoder`.
struct CobaltResponseErrorThrown: Error {
    let payload: CobaltErrorPayload
}
