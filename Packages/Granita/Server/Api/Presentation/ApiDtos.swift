import Foundation
import Hummingbird

import CoreApiDomain
import CoreDiffDomain

// The domain models are the wire contract, so they are what the routes return. Conformance is
// added here rather than in the domain because `ResponseEncodable` is Hummingbird's, and a Domain
// module that imported a web framework would be the first crack in the rule that keeps it testable
// without one.
extension Project: ResponseEncodable {}
extension Worktree: ResponseEncodable {}
extension FileDiff: ResponseEncodable {}
extension WorktreeChanges: ResponseEncodable {}
extension FileLines: ResponseEncodable {}
extension HealthResponse: ResponseEncodable {}
extension PairResponse: ResponseEncodable {}
