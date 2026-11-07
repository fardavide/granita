import Foundation

import ClientConnectionDomain
import CoreApiDomain

struct WorktreeEventDecoder {
    enum Event {
        case none
        case snapshot(WorktreeSnapshot)
    }

    private var name = ""
    private var data: [String] = []

    mutating func receive(_ line: String) throws(ApiFailure) -> Event {
        if line.isEmpty {
            defer {
                name = ""
                data = []
            }
            guard name == "snapshot", data.isEmpty == false else { return .none }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                return .snapshot(try decoder.decode(WorktreeSnapshot.self, from: Data(data.joined(separator: "\n").utf8)))
            } catch {
                throw .notUnderstood(diagnostic: "the worktree event could not be decoded: \(error)")
            }
        }
        if line.hasPrefix("event:") {
            name = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            let payload = line.dropFirst(5)
            data.append(String(payload.first == " " ? payload.dropFirst() : payload))
        }
        return .none
    }
}
