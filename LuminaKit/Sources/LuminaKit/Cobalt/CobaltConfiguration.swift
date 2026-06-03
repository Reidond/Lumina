import Foundation

/// Everything `CobaltClient` needs to talk to an instance, decoupled from settings/UI.
public struct CobaltConfiguration: Sendable, Equatable {
    public var instanceURL: URL
    public var auth: Auth?
    public var requestTimeout: TimeInterval

    public enum Auth: Sendable, Equatable {
        case apiKey(String)
        case bearer(String)

        /// The value for the `Authorization` header.
        public var headerValue: String {
            switch self {
            case .apiKey(let key): "Api-Key \(key)"
            case .bearer(let token): "Bearer \(token)"
            }
        }
    }

    public init(instanceURL: URL, auth: Auth? = nil, requestTimeout: TimeInterval = 15) {
        self.instanceURL = instanceURL
        self.auth = auth
        self.requestTimeout = requestTimeout
    }
}

/// Supplies the current configuration to the networking actor. Implemented on the app
/// side as a `Sendable` snapshot of the `@MainActor` settings store.
public protocol CobaltConfigurationProviding: Sendable {
    func currentConfiguration() async -> CobaltConfiguration?
}

/// A trivial fixed provider, useful for previews and tests.
public struct StaticConfigurationProvider: CobaltConfigurationProviding {
    public let configuration: CobaltConfiguration?
    public init(_ configuration: CobaltConfiguration?) { self.configuration = configuration }
    public func currentConfiguration() async -> CobaltConfiguration? { configuration }
}
