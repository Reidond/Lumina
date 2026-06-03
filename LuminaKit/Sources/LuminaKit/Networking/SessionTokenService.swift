import Foundation

/// Exchanges a solved Cloudflare Turnstile response for a Bearer token via `POST /session`.
public struct SessionTokenService: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public struct Token: Sendable, Equatable {
        public let value: String
        public let expiry: Date
    }

    public func mintToken(instanceURL: URL, turnstileResponse: String) async throws -> Token {
        var request = URLRequest(url: instanceURL.appending(path: "session"))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(turnstileResponse, forHTTPHeaderField: "cf-turnstile-response")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw LuminaError.from(urlError: urlError)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let payload = try? JSONDecoder().decode(CobaltErrorPayload.self, from: data) {
                throw LuminaError.from(payload: payload, httpStatus: http.statusCode)
            }
            throw LuminaError.from(httpStatus: http.statusCode)
        }

        guard let decoded = try? JSONDecoder().decode(SessionResponse.self, from: data) else {
            throw LuminaError.decoding("invalid /session response")
        }
        return Token(value: decoded.token, expiry: decoded.expiryDate)
    }

    private struct SessionResponse: Decodable {
        let token: String
        let exp: Double

        /// `exp` is a token lifetime in seconds for small values, or an absolute Unix epoch
        /// for large ones — handle both.
        var expiryDate: Date {
            exp > 1_000_000_000 ? Date(timeIntervalSince1970: exp) : Date().addingTimeInterval(exp)
        }
    }
}
