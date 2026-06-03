import Foundation

/// Actor that owns all foreground requests to a Cobalt instance. It is the single
/// source of truth for request building, auth headers, rate-limit tracking, and
/// error mapping. Inject a `URLSession` (e.g. a `URLProtocol`-stubbed one) to test.
public actor CobaltClient {
    private let session: URLSession
    private let provider: CobaltConfigurationProviding
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public private(set) var lastRateLimit: RateLimit?

    public init(provider: CobaltConfigurationProviding, session: URLSession = .shared) {
        self.provider = provider
        self.session = session
    }

    /// Submit a download request (`POST /`). Throws a `LuminaError` on any failure.
    public func submit(_ request: CobaltRequest) async throws -> CobaltResponse {
        let config = try await requireConfiguration()
        var urlRequest = URLRequest(url: config.instanceURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = config.requestTimeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let auth = config.auth {
            urlRequest.setValue(auth.headerValue, forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await send(urlRequest)
        let http = response as? HTTPURLResponse
        let reset = updateRateLimit(from: http)

        if let http, !(200..<300).contains(http.statusCode) {
            throw mapError(data: data, status: http.statusCode, reset: reset)
        }

        do {
            return try decoder.decode(CobaltResponse.self, from: data)
        } catch let thrown as CobaltResponseErrorThrown {
            throw LuminaError.from(payload: thrown.payload, httpStatus: http?.statusCode, reset: reset)
        } catch let error as LuminaError {
            throw error
        } catch {
            throw LuminaError.decoding(String(describing: error))
        }
    }

    /// Fetch instance metadata (`GET /`). Used by Settings "Test connection".
    public func fetchInstanceInfo(url: URL) async throws -> InstanceInfo {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 8
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await send(urlRequest)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LuminaError.from(httpStatus: http.statusCode)
        }
        do {
            return try decoder.decode(InstanceInfo.self, from: data)
        } catch {
            throw LuminaError.decoding(String(describing: error))
        }
    }

    // MARK: - Internals

    private func requireConfiguration() async throws -> CobaltConfiguration {
        guard let config = await provider.currentConfiguration() else {
            throw LuminaError.notConfigured
        }
        return config
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            throw LuminaError.from(urlError: urlError)
        } catch {
            throw LuminaError.transport(error.localizedDescription)
        }
    }

    private func updateRateLimit(from http: HTTPURLResponse?) -> Date? {
        guard let http else { return nil }
        if let parsed = RateLimit.parse(headers: http.allHeaderFields) {
            lastRateLimit = parsed
            return parsed.reset
        }
        return nil
    }

    private func mapError(data: Data, status: Int, reset: Date?) -> LuminaError {
        if let payload = try? decoder.decode(CobaltErrorPayload.self, from: data) {
            return LuminaError.from(payload: payload, httpStatus: status, reset: reset)
        }
        return LuminaError.from(httpStatus: status, reset: reset)
    }
}
