#if canImport(UIKit)
import UIKit
#endif

import ClientConnectionDomain

public struct UiKitDiagnosticPasteboard: DiagnosticPasteboard {
    public init() {}

    public func copy(_ text: String) async throws(DiagnosticCopyFailure) {
        #if canImport(UIKit)
        await MainActor.run {
            UIPasteboard.general.string = text
        }
        #else
        // The Mac shell never constructs the phone's diagnostics control.
        throw .unavailable
        #endif
    }
}
