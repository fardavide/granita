import CoreDiffDomain

/// Every Mac this phone has paired with before, and the one live connection to each.
///
/// **It exists because reaching a remembered Mac is three things, none of which a screen may do.**
/// The pairing is in the Keychain, where the Mac *is* has to be asked of Bonjour every time, and the
/// session that carries a request has to be pinned to the key that pairing bought — and all three
/// have to happen before the first byte of the first request. Done in a view they would be a screen
/// that resolves an address; done here they are the front of a repository, so what the reader sees
/// is the worktree list's own spinner and, if it fails, the worktree list's own sentence.
///
/// **One connection per Mac, kept.** A session per request would leak a delegate and a connection
/// pool every time the phone polls, and re-resolving a Bonjour name on every read would put an mDNS
/// round trip in front of each one. What drops a connection is being told contact was lost, which is
/// the only event that can make a resolved address wrong.
///
/// An actor because the screens above it read concurrently — the sidebar and an open diff both make
/// requests — and two of them arriving together must produce one resolution rather than two.
public actor RememberedMacs {

    private let store: any RememberedMacStore
    private let addresses: any ServerAddressResolving

    /// How a pairing becomes something that can be read from. A closure because building one means
    /// naming a session pinned to that Mac's key, which is `Data`'s to know and not this layer's.
    private let connect: @Sendable (PairedMac) -> any GranitaRepository

    /// What that Mac says about itself, asked of a Mac that is demonstrably awake.
    ///
    /// **Only for the backfill below**, and a closure for the same reason `connect` is one: reading
    /// health means an HTTP client, which is `Data`'s to build. Answers nothing when the Mac cannot
    /// be reached or is too old to say, which are the same thing to the caller.
    private let wakeAddressesOf: @Sendable (ServerAddress) async -> [HardwareAddress]

    private var reached: [BonjourInstanceName: any GranitaRepository] = [:]

    /// Macs already backfilled this run, so a Mac with genuinely no addresses is asked once rather
    /// than on every reconnection.
    private var backfilled: Set<BonjourInstanceName> = []

    public init(
        store: any RememberedMacStore,
        addresses: any ServerAddressResolving,
        connect: @escaping @Sendable (PairedMac) -> any GranitaRepository,
        wakeAddressesOf: @escaping @Sendable (ServerAddress) async -> [HardwareAddress]
    ) {
        self.store = store
        self.addresses = addresses
        self.connect = connect
        self.wakeAddressesOf = wakeAddressesOf
    }

    /// Something that can read that Mac, opening a connection to it if there is not one already.
    ///
    /// **A Mac this phone has no pairing for is `unauthorized` rather than an error of its own**, and
    /// that is what makes the state recoverable: the caller forgets it on exactly that answer, and
    /// the next tap on its row goes to the pairing screens instead of here.
    func connection(to server: DiscoveredServer) async throws(ApiFailure) -> any GranitaRepository {
        if let reached = reached[server.id] {
            return reached
        }

        let remembered: RememberedMac?
        do {
            remembered = try await store.remembered(server.id)
        } catch {
            // Switched rather than caught clause by clause: a `catch` per case is not exhaustive to
            // the compiler however many of them there are, so the do block would still rethrow the
            // Keychain's own vocabulary into a signature that speaks the Mac's.
            switch error {
            case .unreadable:
                // Something is filed under this Mac and it is not a pairing, so this phone cannot
                // reach it and cannot be told anything by retrying. Said as "pair again", which is
                // both true and the one thing that clears it.
                throw ApiFailure.unauthorized
            case .refused(let status):
                // Transient far more often than not — `errSecInteractionNotAllowed` is the common
                // one — so it ends in the sentence with *Try Again* under it, not in a re-pairing.
                throw ApiFailure.unreachable(
                    diagnostic: "the Keychain would not hand over this Mac's key (OSStatus \(status))"
                )
            }
        }
        guard let remembered else {
            throw ApiFailure.unauthorized
        }

        let address: ServerAddress
        do {
            address = try await addresses.address(of: server)
        } catch {
            switch error {
            case .unreachable(let diagnostic):
                throw ApiFailure.unreachable(diagnostic: diagnostic)
            case .localNetworkDenied:
                // The one refusal a reader can fix, and the sentence the sidebar draws does not
                // offer to fix it — this is the small print under it, which is where a fact nobody
                // can act on from here belongs. The Mac list is the screen with the Settings button.
                throw ApiFailure.unreachable(diagnostic: "iOS is withholding local network access from Granita")
            }
        }

        let paired = PairedMac(
            instance: server.id,
            name: server.name,
            device: remembered.device,
            address: address,
            fingerprint: remembered.fingerprint,
            wakeAddresses: remembered.wakeAddresses
        )
        let connection = connect(paired)
        reached[server.id] = connection
        await backfillWakeAddresses(of: paired)
        return connection
    }

    /// Learns how to wake a Mac that was paired with before this phone knew how to ask.
    ///
    /// **Every Mac already in the Keychain when 0.6.0 arrived has no address stored**, because the
    /// only thing that ever wrote one was pairing — so without this the first release that can wake
    /// a Mac cannot wake the Mac its reader already uses, and the remedy would be to walk over and
    /// pair again. This is that walk, done by the app, at the one moment it is guaranteed to be
    /// talking to a Mac that is awake: it just reached it.
    ///
    /// **Silent throughout, and deliberately.** A Mac too old to report an address, one that will
    /// not answer health, and a Keychain that refuses the write all end the same way — a Mac that is
    /// simply not wakeable, which is the state this arrived in. None of them is worth a sentence on
    /// a screen whose job is to show worktrees.
    private func backfillWakeAddresses(of paired: PairedMac) async {
        guard paired.wakeAddresses.isEmpty, backfilled.contains(paired.instance) == false else { return }
        backfilled.insert(paired.instance)
        let learned = await wakeAddressesOf(paired.address)
        guard learned.isEmpty == false else { return }
        try? await store.remember(
            PairedMac(
                instance: paired.instance,
                name: paired.name,
                device: paired.device,
                address: paired.address,
                fingerprint: paired.fingerprint,
                wakeAddresses: learned
            )
        )
    }

    /// Throws away where that Mac was, so the next read asks Bonjour again.
    ///
    /// A resolved address is only wrong in one situation — the Mac restarted, slept or moved network
    /// since it was resolved — and that situation is what an unreachable read means. Keeping the
    /// address after one would be an app that stays broken until it is force quit.
    func lostContact(with mac: BonjourInstanceName) {
        reached[mac] = nil
    }

    /// Forgets a Mac entirely, because it no longer honours what this phone holds.
    ///
    /// **Silent on failure, and the failure is survivable.** A Keychain that will not delete leaves a
    /// pairing the Mac has already revoked, which is a row that opens a worktree list that cannot
    /// load — the state the reader is in anyway, and one more tap away from the same place.
    func forget(_ mac: BonjourInstanceName) async {
        reached[mac] = nil
        try? await store.forget(mac)
    }
}

// MARK: -

/// The read API of a Mac this phone paired with at some point in the past.
///
/// Every call goes through the connection above, which is opened on the first one — so the wait for
/// a Keychain read and an mDNS lookup lands inside the worktree list's own loading state rather than
/// on a screen invented to hold it. **That is the whole reason this type exists**: the alternative
/// is a screen between the Mac list and the worktrees, and design §5 is explicit that a Mac already
/// paired with belongs straight in its worktrees.
///
/// **Two failures change what this phone believes, and they are the reason each call is wrapped.** A
/// refusal means the Mac revoked this pairing, so it is forgotten and the row goes back to offering
/// the pairing screens; being unreachable means the address is stale, so it is dropped and the next
/// read resolves again. Everything else is passed up untouched.
public struct RememberedMacRepository: GranitaRepository {

    private let server: DiscoveredServer
    private let macs: RememberedMacs

    public init(reading server: DiscoveredServer, through macs: RememberedMacs) {
        self.server = server
        self.macs = macs
    }

    public func projects() async throws(ApiFailure) -> [Project] {
        do {
            return try await macs.connection(to: server).projects()
        } catch {
            throw await noted(error)
        }
    }

    public func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] {
        do {
            return try await macs.connection(to: server).worktrees(inProject: project)
        } catch {
            throw await noted(error)
        }
    }

    public func update(
        _ worktree: WorktreeID,
        with patch: WorktreePatch
    ) async throws(ApiFailure) -> Worktree {
        do {
            return try await macs.connection(to: server).update(worktree, with: patch)
        } catch {
            throw await noted(error)
        }
    }

    public func delete(_ worktree: WorktreeID) async throws(ApiFailure) {
        do {
            try await macs.connection(to: server).delete(worktree)
        } catch {
            throw await noted(error)
        }
    }

    public func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges {
        do {
            return try await macs.connection(to: server).changes(in: worktree)
        } catch {
            throw await noted(error)
        }
    }

    public func diffs(
        of files: [FileID],
        in worktree: WorktreeID,
        contextLines: Int
    ) async throws(ApiFailure) -> [FileDiff] {
        do {
            return try await macs.connection(to: server)
                .diffs(of: files, in: worktree, contextLines: contextLines)
        } catch {
            throw await noted(error)
        }
    }

    public func lines(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide,
        start: Int,
        count: Int
    ) async throws(ApiFailure) -> FileLines {
        do {
            return try await macs.connection(to: server)
                .lines(of: file, in: worktree, side: side, start: start, count: count)
        } catch {
            throw await noted(error)
        }
    }

    public func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in worktree: WorktreeID
    ) async throws(ApiFailure) {
        do {
            try await macs.connection(to: server)
                .markViewed(viewed, file: file, contentHash: contentHash, in: worktree)
        } catch {
            throw await noted(error)
        }
    }

    /// What a failure means to what this phone remembers, handing the failure straight back.
    ///
    /// **It returns rather than throwing, and the `throw` stays at each of the seven call sites.** A
    /// `-> Never` version reads more tidily and is a worse thing to own: the compiler treats the line
    /// after an unreachable call as dead, so llvm-cov reports every one of those `catch` arms as a
    /// region with no coverage even while a test is running through it — seven arms this project's
    /// ratchet would charge for and no test could ever pay off. Returning the value keeps the
    /// measurement honest, and a rethrow spelled out seven times is visible when one is missing.
    private func noted(_ failure: ApiFailure) async -> ApiFailure {
        switch failure {
        case .unauthorized:
            // The Mac withdrew this pairing — the Devices tab has a Revoke button and this is what
            // pressing it looks like from here. Nothing this phone holds is worth anything any more,
            // so it stops pretending it is paired and the row goes back to offering the two
            // credentials.
            await macs.forget(server.id)
        case .unreachable:
            await macs.lostContact(with: server.id)
        // Answers rather than faults, and a cancellation is not even that: none of them says
        // anything about where the Mac is or whether this phone may still talk to it.
        case .pairingExpired, .rateLimited, .projectNotVisible, .worktreeGone, .worktreeNotDeletable,
             .fileGone, .staleContentHash, .gitFailure, .tooLarge, .badRequest,
             .unsupportedApiVersion, .requestNotBuildable, .cancelled, .notUnderstood:
            break
        }
        return failure
    }
}
