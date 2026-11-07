import Foundation
import Testing

@testable import ClientConnectionData

@Suite("Native session requests")
struct SessionRequestsTests {
    @Test(.timeLimit(.minutes(1)))
    func `given a native session response when requesting data then its bytes and response are preserved`() async throws {
        // given
        let scenario = Scenario()
        defer { scenario.session.invalidateAndCancel() }
        var request = URLRequest(url: try #require(URL(string: "https://session-fixture.invalid/data")))
        request.setValue(Data("prepared inventory".utf8).base64EncodedString(), forHTTPHeaderField: "X-Fixture-Response-Base64")

        // when
        let (data, response) = try await scenario.sut.data(for: request)

        // then
        #expect(data == Data("prepared inventory".utf8))
        #expect(response.url == request.url)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }

    @Test(.timeLimit(.minutes(1)), arguments: LineFraming.allCases)
    func `given native streamed bytes when requesting event lines then frame separators and order are preserved`(framing: LineFraming) async throws {
        // given
        let fixture: (body: String, lines: [String]) = switch framing {
        case .lineFeed:
            ("event: snapshot\ndata: prepared inventory\n\n", ["event: snapshot", "data: prepared inventory", ""])
        case .carriageReturnLineFeed:
            ("event: snapshot\r\ndata: prepared inventory\r\n\r\n", ["event: snapshot", "data: prepared inventory", ""])
        case .carriageReturn:
            ("event: snapshot\rdata: prepared inventory\r\r", ["event: snapshot", "data: prepared inventory", ""])
        case .unicode:
            ("event: snapshot\ndata: café 🍧\n\n", ["event: snapshot", "data: café 🍧", ""])
        case .finalLineWithoutTerminator:
            ("event: snapshot\ndata: last frame", ["event: snapshot", "data: last frame"])
        case .empty:
            ("", [])
        }
        let scenario = Scenario()
        defer { scenario.session.invalidateAndCancel() }
        var request = URLRequest(url: try #require(URL(string: "https://session-fixture.invalid/events")))
        request.setValue(
            Data(fixture.body.utf8).base64EncodedString(),
            forHTTPHeaderField: "X-Fixture-Response-Base64"
        )

        // when
        let (lines, response) = try await scenario.sut.lines(for: request)
        var received: [String] = []
        for try await line in lines { received.append(line) }

        // then
        #expect(received == fixture.lines)
        #expect(response.url == request.url)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }

    enum LineFraming: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case lineFeed = "line-feed"
        case carriageReturnLineFeed = "carriage-return-line-feed"
        case carriageReturn = "carriage-return"
        case unicode
        case finalLineWithoutTerminator = "final-line-without-terminator"
        case empty

        var testDescription: String { rawValue }
    }

    private struct Scenario {
        let sut: UrlSessionRequests
        let session: URLSession

        init() {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [FakeUrlProtocol.self]
            session = URLSession(configuration: configuration)
            sut = UrlSessionRequests(session: session)
        }
    }
}
