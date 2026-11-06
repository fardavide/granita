import Foundation

actor FakeSuggestedAliases {
    private let pausingInvocation: Int
    private let paused = AsyncStream.makeStream(of: Void.self)
    private let released = AsyncStream.makeStream(of: Void.self)
    private var invocations = 0

    init(pausingInvocation: Int) {
        self.pausingInvocation = pausingInvocation
    }

    func aliases(for records: [(path: String, branch: String?)]) async -> [String: String] {
        invocations += 1
        if invocations == pausingInvocation {
            paused.continuation.yield(())
            var release = released.stream.makeAsyncIterator()
            _ = await release.next()
        }
        return [:]
    }

    func waitUntilPaused() async {
        var pauses = paused.stream.makeAsyncIterator()
        _ = await pauses.next()
    }

    func resume() {
        released.continuation.finish()
    }
}
