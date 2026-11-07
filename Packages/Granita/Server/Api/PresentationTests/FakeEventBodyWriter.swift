import Hummingbird

actor FakeEventBodyWriter: ResponseBodyWriter {
    private(set) var frames: [String] = []
    private var firstFrameWaiters: [CheckedContinuation<String, Never>] = []
    private let afterFirstFrame: @Sendable () async throws -> Void

    init(afterFirstFrame: @escaping @Sendable () async throws -> Void = {}) {
        self.afterFirstFrame = afterFirstFrame
    }

    func write(_ buffer: ByteBuffer) async throws {
        let frame = String(decoding: buffer.readableBytesView, as: UTF8.self)
        frames.append(frame)
        for waiter in firstFrameWaiters { waiter.resume(returning: frame) }
        firstFrameWaiters = []
        if frames.count == 1 { try await afterFirstFrame() }
    }

    func firstFrame() async -> String {
        if let first = frames.first { return first }
        return await withCheckedContinuation { firstFrameWaiters.append($0) }
    }

    func finish(_ trailingHeaders: HTTPFields?) async throws {}
}
