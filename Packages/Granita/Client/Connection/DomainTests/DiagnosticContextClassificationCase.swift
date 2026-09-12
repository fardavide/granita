import ClientConnectionDomain
import CorePairingDomain

enum DiagnosticContextClassificationCase: CaseIterable, Sendable {
    case discoveryIdle
    case discoverySearching
    case discoveryNothingFound
    case discoveryFound
    case discoveryDenied
    case discoveryFailed
    case pairingNotStarted
    case pairingWaitingForCamera
    case pairingLooking
    case pairingSawSomethingElse
    case pairingSpending
    case pairingSavingToken
    case pairingPaired
    case pairingCameraRefused
    case pairingCameraRestricted
    case pairingUnreachable
    case pairingNetworkDenied
    case pairingRefused
    case pairingSameContract
    case pairingMacBehind
    case pairingPhoneBehind
    case pairingKeychainRefused
    case pairingKeychainUnreadable
    case pairingContractNeverAnswered
    case pairingCodeNeverAnswered
    case pairingKeyNeverAnswered
    case worktreesWithoutFailure
    case diffWithoutFailure
    case unauthorized
    case pairingExpired
    case rateLimited
    case projectNotVisible
    case worktreeGone
    case worktreeNotDeletable
    case fileGone
    case staleContentHash
    case gitFailure
    case tooLarge
    case badRequest
    case unsupportedApiVersion
    case requestNotBuildable
    case unreachable
    case cancelled
    case notUnderstood

    func fixture(privatePayload: String) -> (DiagnosticContext, String) {
        let privateMac = PairedMac(
            instance: BonjourInstanceName(rawValue: privatePayload),
            name: privatePayload,
            device: PairedDevice(
                token: PairingToken(rawValue: privatePayload),
                deviceId: DeviceId(rawValue: privatePayload),
                serverInstanceId: ServerInstanceId(rawValue: privatePayload)
            ),
            address: ServerAddress(host: privatePayload, port: 8737),
            fallbackAddress: ServerAddress(host: privatePayload, port: 8737),
            fingerprint: SpkiFingerprint(rawValue: privatePayload),
            wakeAddresses: []
        )
        switch self {
        case .discoveryIdle:
            return (.discovery(.idle), "Current screen: discovery\nState: idle")
        case .discoverySearching:
            return (.discovery(.searching), "Current screen: discovery\nState: searching")
        case .discoveryNothingFound:
            return (.discovery(.found([])), "Current screen: discovery\nFailure: nothingFound")
        case .discoveryFound:
            return (
                .discovery(.found([DiscoveredServer(
                    id: BonjourInstanceName(rawValue: privatePayload),
                    name: privatePayload
                )])),
                "Current screen: discovery\nState: found"
            )
        case .discoveryDenied:
            return (.discovery(.localNetworkDenied), "Current screen: discovery\nFailure: localNetworkDenied")
        case .discoveryFailed:
            return (.discovery(.failed(diagnostic: privatePayload)), "Current screen: discovery\nFailure: failed")
        case .pairingNotStarted:
            return (.pairing(.notStarted), "Current screen: pairing\nState: notStarted")
        case .pairingWaitingForCamera:
            return (.pairing(.waitingForCameraAccess), "Current screen: pairing\nState: waitingForCameraAccess")
        case .pairingLooking:
            return (.pairing(.looking), "Current screen: pairing\nState: looking")
        case .pairingSawSomethingElse:
            return (.pairing(.sawSomethingElse), "Current screen: pairing\nState: sawSomethingElse")
        case .pairingSpending:
            return (.pairing(.spending), "Current screen: pairing\nState: spending")
        case .pairingSavingToken:
            return (.pairing(.savingToken), "Current screen: pairing\nState: savingToken")
        case .pairingPaired:
            return (.pairing(.finished(.paired(privateMac))), "Current screen: pairing\nState: paired")
        case .pairingCameraRefused:
            return (.pairing(.cameraRefused), "Current screen: pairing\nFailure: cameraRefused")
        case .pairingCameraRestricted:
            return (.pairing(.cameraRestricted), "Current screen: pairing\nFailure: cameraRestricted")
        case .pairingUnreachable:
            return (.pairing(.notReached(.unreachable(diagnostic: privatePayload))), "Current screen: pairing\nFailure: unreachable")
        case .pairingNetworkDenied:
            return (.pairing(.notReached(.localNetworkDenied)), "Current screen: pairing\nFailure: localNetworkDenied")
        case .pairingRefused:
            return (.pairing(.finished(.refused(.rateLimited))), "Current screen: pairing\nFailure: rateLimited")
        case .pairingSameContract:
            return (.pairing(.finished(.wrongContract(.sameContract))), "Current screen: pairing\nFailure: wrongContract\nCompatibility: sameContract")
        case .pairingMacBehind:
            return (.pairing(.finished(.wrongContract(.macIsBehind(serving: 7)))), "Current screen: pairing\nFailure: wrongContract\nCompatibility: macIsBehind\nServing API version: 7")
        case .pairingPhoneBehind:
            return (.pairing(.finished(.wrongContract(.phoneIsBehind(serving: 9)))), "Current screen: pairing\nFailure: wrongContract\nCompatibility: phoneIsBehind\nServing API version: 9")
        case .pairingKeychainRefused:
            return (.pairing(.finished(.tokenNotStored(privateMac, .refused(status: -25_308)))), "Current screen: pairing\nFailure: tokenNotStored\nKeychain status: -25308")
        case .pairingKeychainUnreadable:
            return (.pairing(.finished(.tokenNotStored(privateMac, .unreadable))), "Current screen: pairing\nFailure: tokenNotStored\nStore failure: unreadable")
        case .pairingContractNeverAnswered:
            return (.pairing(.finished(.neverAnswered(.readingTheContract))), "Current screen: pairing\nFailure: neverAnswered\nPairing step: readingTheContract")
        case .pairingCodeNeverAnswered:
            return (.pairing(.finished(.neverAnswered(.spendingTheCode))), "Current screen: pairing\nFailure: neverAnswered\nPairing step: spendingTheCode")
        case .pairingKeyNeverAnswered:
            return (.pairing(.finished(.neverAnswered(.writingTheKey(privateMac)))), "Current screen: pairing\nFailure: neverAnswered\nPairing step: writingTheKey")
        case .worktreesWithoutFailure:
            return (.worktrees(nil), "Current screen: worktrees")
        case .diffWithoutFailure:
            return (.diff(nil), "Current screen: diff")
        case .unauthorized:
            return (.worktrees(.unauthorized), "Current screen: worktrees\nFailure: unauthorized")
        case .pairingExpired:
            return (.worktrees(.pairingExpired), "Current screen: worktrees\nFailure: pairingExpired")
        case .rateLimited:
            return (.worktrees(.rateLimited), "Current screen: worktrees\nFailure: rateLimited")
        case .projectNotVisible:
            return (.worktrees(.projectNotVisible), "Current screen: worktrees\nFailure: projectNotVisible")
        case .worktreeGone:
            return (.worktrees(.worktreeGone), "Current screen: worktrees\nFailure: worktreeGone")
        case .worktreeNotDeletable:
            return (.worktrees(.worktreeNotDeletable(message: privatePayload)), "Current screen: worktrees\nFailure: worktreeNotDeletable")
        case .fileGone:
            return (.diff(.fileGone), "Current screen: diff\nFailure: fileGone")
        case .staleContentHash:
            return (.diff(.staleContentHash), "Current screen: diff\nFailure: staleContentHash")
        case .gitFailure:
            return (.diff(.gitFailure(message: privatePayload)), "Current screen: diff\nFailure: gitFailure")
        case .tooLarge:
            return (.diff(.tooLarge), "Current screen: diff\nFailure: tooLarge")
        case .badRequest:
            return (.diff(.badRequest(message: privatePayload)), "Current screen: diff\nFailure: badRequest")
        case .unsupportedApiVersion:
            return (.diff(.unsupportedApiVersion), "Current screen: diff\nFailure: unsupportedApiVersion")
        case .requestNotBuildable:
            return (.diff(.requestNotBuildable(diagnostic: privatePayload)), "Current screen: diff\nFailure: requestNotBuildable")
        case .unreachable:
            return (.diff(.unreachable(diagnostic: privatePayload)), "Current screen: diff\nFailure: unreachable")
        case .cancelled:
            return (.diff(.cancelled), "Current screen: diff\nFailure: cancelled")
        case .notUnderstood:
            return (.diff(.notUnderstood(diagnostic: privatePayload)), "Current screen: diff\nFailure: notUnderstood")
        }
    }
}
