import Foundation

/// Decoded `GET /` instance metadata. Decoding is resilient per-field — instances vary in
/// what they return and in field types (e.g. `startTime` may be a string or a number), and
/// this is display-only, so a single odd field should never fail the whole probe.
public struct InstanceInfo: Decodable, Sendable, Equatable {
    public let cobalt: Cobalt?
    public let git: Git?

    public struct Cobalt: Decodable, Sendable, Equatable {
        public let version: String?
        public let url: String?
        public let startTime: String?
        public let turnstileSitekey: String?
        public let services: [String]?

        private enum CodingKeys: String, CodingKey {
            case version, url, startTime, turnstileSitekey, services
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = (try? c.decodeIfPresent(String.self, forKey: .version)) ?? nil
            url = (try? c.decodeIfPresent(String.self, forKey: .url)) ?? nil
            startTime = Self.flexibleString(c, .startTime)
            turnstileSitekey = (try? c.decodeIfPresent(String.self, forKey: .turnstileSitekey)) ?? nil
            services = (try? c.decodeIfPresent([String].self, forKey: .services)) ?? nil
        }

        /// Decode a value that may arrive as a string or a number.
        private static func flexibleString(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
            if let s = (try? c.decodeIfPresent(String.self, forKey: key)) ?? nil { return s }
            if let n = (try? c.decodeIfPresent(Int64.self, forKey: key)) ?? nil { return String(n) }
            if let d = (try? c.decodeIfPresent(Double.self, forKey: key)) ?? nil { return String(d) }
            return nil
        }
    }

    public struct Git: Decodable, Sendable, Equatable {
        public let commit: String?
        public let branch: String?
        public let remote: String?

        private enum CodingKeys: String, CodingKey { case commit, branch, remote }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            commit = (try? c.decodeIfPresent(String.self, forKey: .commit)) ?? nil
            branch = (try? c.decodeIfPresent(String.self, forKey: .branch)) ?? nil
            remote = (try? c.decodeIfPresent(String.self, forKey: .remote)) ?? nil
        }
    }

    private enum CodingKeys: String, CodingKey { case cobalt, git }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cobalt = (try? c.decodeIfPresent(Cobalt.self, forKey: .cobalt)) ?? nil
        git = (try? c.decodeIfPresent(Git.self, forKey: .git)) ?? nil
    }

    /// Whether this instance gates requests behind a Cloudflare Turnstile challenge.
    public var requiresTurnstile: Bool {
        cobalt?.turnstileSitekey?.isEmpty == false
    }
}
