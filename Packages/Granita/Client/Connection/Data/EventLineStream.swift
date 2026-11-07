import Foundation

enum EventLineStream {
    static func buffer<Source: AsyncSequence & Sendable>(
        _ source: Source,
        capacity: Int,
        onTermination: @escaping @Sendable () -> Void
    ) -> AsyncThrowingStream<String, any Error> where Source.Element == String {
        // Preserve a contiguous prefix until the overflow failure is delivered. Dropping an older
        // SSE separator can instead merge valid frames and turn reconnect into a terminal parse error.
        AsyncThrowingStream(bufferingPolicy: .bufferingOldest(capacity)) { continuation in
            let reading = Task {
                do {
                    for try await line in source {
                        switch continuation.yield(line) {
                        case .enqueued: break
                        case .dropped:
                            throw URLError(.dataLengthExceedsMaximum)
                        case .terminated: return
                        @unknown default:
                            throw URLError(.cannotDecodeContentData)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                reading.cancel()
                onTermination()
            }
        }
    }
}
