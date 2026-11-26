import ClientConnectionDomain
import ServerGitDomain

public struct MacReaderDiagnosticReport: DiagnosticReportProviding {
    private let connections: any DiagnosticReportProviding
    private let gitFailures: GitFailureJournal

    public init(connections: any DiagnosticReportProviding, gitFailures: GitFailureJournal) {
        self.connections = connections
        self.gitFailures = gitFailures
    }

    public func report() async -> String {
        let connectionReport = await connections.report()
        let gitReport = await gitFailures.report()
        return connectionReport + "\n\n" + gitReport
    }
}
