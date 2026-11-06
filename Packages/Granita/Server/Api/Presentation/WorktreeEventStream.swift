import Foundation
import Hummingbird

import CoreApiDomain

enum WorktreeEventStream {

    static func body(
        snapshots: AsyncStream<WorktreeSnapshot>,
        authorized: @escaping @Sendable () async -> Bool
    ) -> ResponseBody {
        body(snapshots: snapshots, authorized: authorized, heartbeats: scheduledHeartbeats())
    }

    static func body(
        snapshots: AsyncStream<WorktreeSnapshot>,
        authorized: @escaping @Sendable () async -> Bool,
        heartbeats: AsyncStream<Void>
    ) -> ResponseBody {
        ResponseBody { writer in
            let frames = WorktreeEventQueue(capacity: 16)
            let forwarding = Task {
                let ticking = Task {
                    for await _ in heartbeats {
                        guard frames.send(.heartbeat) else { return }
                    }
                }
                for await snapshot in snapshots {
                    guard frames.send(.snapshot(snapshot)) else { break }
                }
                ticking.cancel()
                await ticking.value
                frames.finish()
            }
            defer { forwarding.cancel() }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            for await frame in frames.stream {
                guard await authorized() else {
                    throw ApiError(.unauthorized, message: "this device is no longer paired")
                }
                let text: String
                switch frame {
                case .snapshot(let snapshot):
                    let encoded = try encoder.encode(snapshot)
                    text = "event: snapshot\ndata: \(String(decoding: encoded, as: UTF8.self))\n\n"
                case .heartbeat:
                    text = ": heartbeat\n\n"
                }
                try await writer.write(ByteBuffer(string: text))
            }
            try await writer.finish(nil)
        }
    }

    private static func scheduledHeartbeats() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let ticking = Task {
                while Task.isCancelled == false {
                    do {
                        try await Task.sleep(for: .seconds(20))
                    } catch {
                        continuation.finish()
                        return
                    }
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in ticking.cancel() }
        }
    }
}
