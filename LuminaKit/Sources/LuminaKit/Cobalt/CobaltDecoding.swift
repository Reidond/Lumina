import Foundation

/// Helpers for lenient URL decoding. Cobalt tunnel URLs carry query strings and
/// percent-encoding that can trip `JSONDecoder`'s strict `URL` decoding, so we always
/// decode a `String` first and construct the `URL` ourselves.
enum CobaltDecoding {
    static func url<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) throws -> URL {
        let s = try c.decode(String.self, forKey: key)
        guard let url = URL(string: s) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: c, debugDescription: "Invalid URL string: \(s)")
        }
        return url
    }

    static func optionalURL<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> URL? {
        guard let s = try? c.decodeIfPresent(String.self, forKey: key) else { return nil }
        return URL(string: s)
    }

    static func urls<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) throws -> [URL] {
        let strings = try c.decode([String].self, forKey: key)
        return strings.compactMap(URL.init(string:))
    }
}
