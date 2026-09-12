import ClientConnectionDomain

actor FakeDiagnosticReportProviding: DiagnosticReportProviding {

    private let providedReport: String

    init(report: String) {
        providedReport = report
    }

    func report() async -> String {
        providedReport
    }
}
