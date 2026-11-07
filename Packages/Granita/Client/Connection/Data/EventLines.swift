import Foundation

/// Foundation's line sequence drops the empty lines that terminate SSE frames.
struct EventLines<Bytes: AsyncSequence & Sendable>: AsyncSequence, Sendable where Bytes.Element == UInt8 {
    typealias Element = String

    let bytes: Bytes

    func makeAsyncIterator() -> Iterator {
        Iterator(bytes: bytes.makeAsyncIterator())
    }

    struct Iterator: AsyncIteratorProtocol {
        private var bytes: Bytes.AsyncIterator
        private var skipsLineFeed = false

        init(bytes: Bytes.AsyncIterator) {
            self.bytes = bytes
        }

        mutating func next() async throws -> String? {
            var line: [UInt8] = []
            while let byte = try await bytes.next() {
                if skipsLineFeed {
                    skipsLineFeed = false
                    if byte == 0x0A { continue }
                }
                if byte == 0x0D {
                    skipsLineFeed = true
                    return String(decoding: line, as: UTF8.self)
                }
                if byte == 0x0A {
                    return String(decoding: line, as: UTF8.self)
                }
                line.append(byte)
            }
            return line.isEmpty ? nil : String(decoding: line, as: UTF8.self)
        }
    }
}
