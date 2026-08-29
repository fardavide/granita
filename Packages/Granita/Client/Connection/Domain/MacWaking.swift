/// Sends the packet that wakes a sleeping Mac.
///
/// **The phone is the sleep proxy now.** macOS 15 compiled the Bonjour Sleep Proxy client out of
/// mDNSResponder, so a sleeping Mac withdraws its advertisement rather than leaving it with the
/// Apple TV that used to answer for it — and with nothing on the network holding its name, nothing
/// causes it to wake either. The packet the proxy would have sent still works, and this is what
/// sends it.
///
/// **Answering is not a promise that anything woke.** A magic packet is a datagram broadcast into
/// the void: nothing acknowledges it, a Mac with *Wake for network access* switched off ignores it,
/// and one that is fully powered down never sees it. So this returns nothing and throws nothing —
/// the only evidence that it worked is the Mac turning up in the browse a few seconds later, which
/// is a thing the screens above already draw.
public protocol MacWaking: Sendable {

    /// Broadcasts a wake to each of those, and answers once they have gone out.
    ///
    /// Given none, it sends none — a Mac paired with before this existed has no address stored, and
    /// that is an ordinary state rather than a caller's mistake.
    func wake(_ addresses: [HardwareAddress]) async
}
