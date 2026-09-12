import Foundation

import ClientConnectionDomain

public struct ConnectionLogContext: Sendable {

    public let appVersion: String
    public let build: String
    public let systemVersion: String
    public let deviceModel: String

    public init(appVersion: String, build: String, systemVersion: String, deviceModel: String) {
        self.appVersion = appVersion
        self.build = build
        self.systemVersion = systemVersion
        self.deviceModel = deviceModel
    }
}

public struct ConnectionLogError: Sendable {

    public let domain: String
    public let code: Int

    public init(domain: String, code: Int) {
        self.domain = domain
        self.code = code
    }

    public static func chain(for error: any Error) -> [ConnectionLogError] {
        var current: NSError? = error as NSError
        var errors: [ConnectionLogError] = []
        while let failure = current {
            errors.append(ConnectionLogError(domain: failure.domain, code: failure.code))
            current = failure.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return errors
    }
}

public actor ConnectionLogs: DiagnosticReportProviding {

    private let context: ConnectionLogContext
    private let capacity: Int
    private let now: @Sendable () -> Date
    private var entries: [String]

    public init(context: ConnectionLogContext, capacity: Int, now: @escaping @Sendable () -> Date) {
        self.context = context
        self.capacity = capacity
        self.now = now
        entries = []
        entries.reserveCapacity(capacity)
    }

    public func record(_ event: Event) {
        let method: Method
        var endpoint: URLComponents?
        let outcome: String
        switch event {
        case .requestFailed(let verb, let address, let errors):
            method = .http(verb)
            endpoint = URLComponents(url: address, resolvingAgainstBaseURL: false)
            outcome = errors.map { "\($0.domain) (\($0.code))" }.joined(separator: ", ")
        case .requestFinished(let verb, let address, let status):
            method = .http(verb)
            endpoint = URLComponents(url: address, resolvingAgainstBaseURL: false)
            outcome = "HTTP \(status)"
        case .pinnedKeyMatched(let host, let port):
            method = .tls
            endpoint = Self.tlsEndpoint(host: host, port: port)
            outcome = "accepted — pinned key matched"
        case .pinnedKeyMismatched(let host, let port):
            method = .tls
            endpoint = Self.tlsEndpoint(host: host, port: port)
            outcome = "refused — pinned key mismatch"
        case .serverTrustUnavailable(let host, let port):
            method = .tls
            endpoint = Self.tlsEndpoint(host: host, port: port)
            outcome = "refused — server trust unavailable"
        case .publicKeyUnavailable(let host, let port):
            method = .tls
            endpoint = Self.tlsEndpoint(host: host, port: port)
            outcome = "refused — public key unavailable"
        }
        endpoint?.user = nil
        endpoint?.password = nil
        endpoint?.query = nil
        endpoint?.fragment = nil
        entries.append(
            "\(now().ISO8601Format()) \(method.text) "
                + "\(endpoint?.string ?? "<unavailable endpoint>") — \(outcome)"
        )
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    public func report() -> String {
        "Granita \(context.appVersion) (\(context.build))\n"
            + "\(context.systemVersion) — \(context.deviceModel)\n"
            + "Collected: \(now().ISO8601Format())\n"
            + "Current app session · phone-side connection events only\n"
            + "Credentials, query strings, headers, bodies and source text are excluded.\n\n"
            + (entries.isEmpty ? "No connection events recorded" : entries.joined(separator: "\n"))
    }

    private static func tlsEndpoint(host: String, port: Int) -> URLComponents {
        var endpoint = URLComponents()
        endpoint.scheme = "https"
        endpoint.host = host
        endpoint.port = port
        return endpoint
    }

    public enum Event: Sendable {
        case requestFailed(method: HttpRequest.Method, url: URL, errors: [ConnectionLogError])
        case requestFinished(method: HttpRequest.Method, url: URL, statusCode: Int)
        case pinnedKeyMatched(host: String, port: Int)
        case pinnedKeyMismatched(host: String, port: Int)
        case serverTrustUnavailable(host: String, port: Int)
        case publicKeyUnavailable(host: String, port: Int)
    }

    private enum Method {
        case http(HttpRequest.Method)
        case tls

        var text: String {
            switch self {
            case .http(let method): method.rawValue
            case .tls: "TLS"
            }
        }
    }
}
