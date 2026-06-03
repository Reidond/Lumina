import Foundation

/// Parsed `RateLimit-*` / `Retry-After` headers (per the IETF RateLimit Header Fields
/// draft). `reset` is normalized to an absolute `Date`.
public struct RateLimit: Sendable, Equatable {
    public let limit: Int?
    public let remaining: Int?
    public let reset: Date?

    public init(limit: Int?, remaining: Int?, reset: Date?) {
        self.limit = limit
        self.remaining = remaining
        self.reset = reset
    }

    public var isExhausted: Bool { (remaining ?? 1) <= 0 }

    /// Parse from a response's header dictionary. `RateLimit-Reset` / `Retry-After` are
    /// treated as delta-seconds from `now`.
    public static func parse(headers: [AnyHashable: Any], now: Date = Date()) -> RateLimit? {
        func value(_ name: String) -> String? {
            for (k, v) in headers {
                if let ks = k as? String, ks.caseInsensitiveCompare(name) == .orderedSame {
                    return (v as? String) ?? (v as? CustomStringConvertible)?.description
                }
            }
            return nil
        }
        let limit = value("RateLimit-Limit").flatMap { Int($0) }
        let remaining = value("RateLimit-Remaining").flatMap { Int($0) }
        let resetSeconds = value("RateLimit-Reset").flatMap { Int($0) }
            ?? value("Retry-After").flatMap { Int($0) }
        let reset = resetSeconds.map { now.addingTimeInterval(TimeInterval($0)) }

        if limit == nil, remaining == nil, reset == nil { return nil }
        return RateLimit(limit: limit, remaining: remaining, reset: reset)
    }
}
