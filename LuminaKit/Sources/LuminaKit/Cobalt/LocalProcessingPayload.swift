import Foundation

/// A `local-processing` response: the client must download `tunnels` and combine them
/// per `type` (merge/mute/audio/gif/remux), writing a single file named `output.filename`.
public struct LocalProcessingPayload: Decodable, Sendable, Equatable {
    public enum Kind: String, Decodable, Sendable {
        case merge, mute, audio, gif, remux
    }

    public let type: Kind
    public let service: String?
    public let tunnels: [URL]
    public let output: Output
    public let audio: AudioSpec?
    public let isHLS: Bool

    public struct Output: Decodable, Sendable, Equatable {
        public let type: String          // MIME type of the result
        public let filename: String
        public let metadata: [String: String]?
        public let subtitles: Bool?
    }

    public struct AudioSpec: Decodable, Sendable, Equatable {
        public let copy: Bool?
        public let format: String?
        public let bitrate: String?
        public let cover: Bool?
        public let cropCover: Bool?
    }

    private enum CodingKeys: String, CodingKey {
        case type, service, tunnel, output, audio, isHLS
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try c.decode(Kind.self, forKey: .type)
        self.service = try? c.decodeIfPresent(String.self, forKey: .service)
        self.tunnels = try CobaltDecoding.urls(c, .tunnel)
        self.output = try c.decode(Output.self, forKey: .output)
        self.audio = try? c.decodeIfPresent(AudioSpec.self, forKey: .audio)
        self.isHLS = (try? c.decodeIfPresent(Bool.self, forKey: .isHLS)) ?? false
    }
}
