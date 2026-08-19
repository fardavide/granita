import CoreBrandingDomain
import Foundation
import ServerApiPresentation

/// Composition root for the terminal. The menu bar app embeds the same backend in-process; this
/// executable is what makes it build, run and test with `swift run` and `swift test` with no Xcode
/// in the loop — and what recovers a review session when the UI is the thing that is broken.
@main
struct GranitaServer {

    static func main() async {
        let arguments = Arguments(CommandLine.arguments.dropFirst())
        if arguments.wantsHelp {
            print(Arguments.usage)
            return
        }

        let binding: ApiServerBinding = arguments.isInsecureHttp
            ? .hostname("0.0.0.0", port: arguments.port)
            : .bonjourService(name: arguments.serviceName)

        switch binding {
        case .hostname(let host, let port):
            // Off by default and unreachable from the UI. It exists so a TLS problem can never
            // leave code unreviewable.
            log("serving plain HTTP on \(host):\(port) — no TLS, no Bonjour")
        case .bonjourService(let name):
            log("advertising \(Branding.bonjourServiceType) as \"\(name)\"")
        }

        let server = ApiServer.make(
            configuration: ApiServerConfiguration(
                serverVersion: Branding.serverVersion,
                binding: binding
            )
        )

        do {
            try await server.runService()
        } catch {
            log("stopped: \(error)")
            exit(1)
        }
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data("granita-server: \(message)\n".utf8))
    }
}

// MARK: -

/// Deliberately hand-rolled rather than pulling an argument parser in. The flag set is small and
/// fixed, and a dependency the product does not otherwise need is not worth a nicer `--help`.
private struct Arguments {

    let wantsHelp: Bool
    let isInsecureHttp: Bool
    let port: Int
    let serviceName: String

    static let usage = """
        granita-server — serves uncommitted worktree diffs over the local network.

          --insecure-http     Serve plain HTTP instead of advertising over Bonjour with TLS.
                              Off by default and never reachable from the Mac app's UI.
          --port <n>          Port for --insecure-http. Default \(Branding.defaultPort).
          --service-name <s>  Bonjour instance name. Defaults to this machine's name.
          --help              This.
        """

    init(_ arguments: some Sequence<String>) {
        let arguments = Array(arguments)
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        wantsHelp = arguments.contains("--help") || arguments.contains("-h")
        isInsecureHttp = arguments.contains("--insecure-http")
        port = value(after: "--port").flatMap(Int.init) ?? Branding.defaultPort
        serviceName = value(after: "--service-name") ?? ProcessInfo.processInfo.hostName
    }
}
