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
        let method: HttpRequest.Method
        let url: URL
        let outcome: String
        switch event {
        case .requestFailed(let verb, let address, let errors):
            method = verb
            url = address
            outcome = errors.map { "\($0.domain) (\($0.code))" }.joined(separator: ", ")
        case .requestFinished(let verb, let address, let status):
            method = verb
            url = address
            outcome = "HTTP \(status)"
        }
        var endpoint = URLComponents(url: url, resolvingAgainstBaseURL: false)
        endpoint?.user = nil
        endpoint?.password = nil
        endpoint?.query = nil
        endpoint?.fragment = nil
        entries.append(
            "\(now().ISO8601Format()) \(method.rawValue) "
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

    public enum Event: Sendable {
        case requestFailed(method: HttpRequest.Method, url: URL, errors: [ConnectionLogError])
        case requestFinished(method: HttpRequest.Method, url: URL, statusCode: Int)
    }
}
