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

public actor ConnectionLogs: DiagnosticReportProviding, ConnectionTimingRecording {

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
        case .requestStarted(let verb, let address):
            method = .httpTiming(verb)
            endpoint = URLComponents(url: address, resolvingAgainstBaseURL: false)
            outcome = "started"
        case .requestTimed(let verb, let address, let duration, let result):
            method = .httpTiming(verb)
            endpoint = URLComponents(url: address, resolvingAgainstBaseURL: false)
            outcome = Self.timingOutcome(duration: duration, outcome: result)
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
        append("\(method.text) \(endpoint?.string ?? "<unavailable endpoint>") — \(outcome)")
    }

    public func report() -> String {
        "Granita \(context.appVersion) (\(context.build))\n"
            + "\(context.systemVersion) — \(context.deviceModel)\n"
            + "Collected: \(now().ISO8601Format())\n"
            + "Current app session · phone-side connection events only\n"
            + "Credentials, query strings, headers, bodies and source text are excluded.\n\n"
            + (entries.isEmpty ? "No connection events recorded" : entries.joined(separator: "\n"))
    }

    public func record(_ event: ConnectionTimingEvent) {
        let stage: ConnectionStage
        let outcome: String
        switch event {
        case .started(let starting):
            stage = starting
            outcome = "started"
        case .finished(let finished, let duration, let result):
            stage = finished
            outcome = Self.timingOutcome(duration: duration, outcome: result)
        }
        let label: String
        switch stage {
        case .localDiscovery: label = "LOCAL DISCOVERY"
        case .tailnetVerification: label = "TAILNET VERIFICATION"
        case .localVerification: label = "LOCAL VERIFICATION"
        }
        append("\(label) — \(outcome)")
    }

    private func append(_ message: String) {
        entries.append("\(now().ISO8601Format()) \(message)")
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    private static func tlsEndpoint(host: String, port: Int) -> URLComponents {
        var endpoint = URLComponents()
        endpoint.scheme = "https"
        endpoint.host = host
        endpoint.port = port
        return endpoint
    }

    private static func timingOutcome(duration: Duration, outcome: ConnectionStageOutcome) -> String {
        let result: String
        switch outcome {
        case .succeeded: result = "succeeded"
        case .failed: result = "failed"
        case .cancelled: result = "cancelled"
        case .skipped: result = "skipped"
        }
        let components = duration.components
        let milliseconds = components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000
        return "\(result) — \(milliseconds) ms"
    }

    public enum Event: Sendable {
        case requestStarted(method: HttpRequest.Method, url: URL)
        case requestTimed(method: HttpRequest.Method, url: URL, duration: Duration, outcome: ConnectionStageOutcome)
        case requestFailed(method: HttpRequest.Method, url: URL, errors: [ConnectionLogError])
        case requestFinished(method: HttpRequest.Method, url: URL, statusCode: Int)
        case pinnedKeyMatched(host: String, port: Int)
        case pinnedKeyMismatched(host: String, port: Int)
        case serverTrustUnavailable(host: String, port: Int)
        case publicKeyUnavailable(host: String, port: Int)
    }

    private enum Method {
        case http(HttpRequest.Method)
        case httpTiming(HttpRequest.Method)
        case tls

        var text: String {
            switch self {
            case .http(let method): method.rawValue
            case .httpTiming(let method): "REQUEST \(method.rawValue)"
            case .tls: "TLS"
            }
        }
    }
}
