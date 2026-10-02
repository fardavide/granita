import SwiftUI

import CoreComponentsUi
import ServerStoreDomain

public struct MacReaderBlockedView: View {
    private let holder: StoreLockHolder?

    public init(holder: StoreLockHolder?) {
        self.holder = holder
    }

    public var body: some View {
        EmptyState {
            Label("This Mac is in use", systemImage: "lock")
        } description: {
            Text("\(holder?.sentence ?? "Another process") has the settings. Quit that process to read this Mac here.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
