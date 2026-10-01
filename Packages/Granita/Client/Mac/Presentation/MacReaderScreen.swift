import SwiftUI

import ClientMacUi
import ClientConnectionDomain
import ServerApiDomain
import ServerStoreDomain

public struct MacReaderScreen<Source: View, Local: View, Remote: View>: View {
    private let model: ClientMacModel
    private let serverState: ServerRunState
    private let holder: StoreLockHolder?
    private let source: () -> Source
    private let local: () -> Local
    private let remote: (DiscoveredServer) -> Remote

    public init(
        model: ClientMacModel,
        serverState: ServerRunState,
        holder: StoreLockHolder?,
        @ViewBuilder source: @escaping () -> Source,
        @ViewBuilder local: @escaping () -> Local,
        @ViewBuilder remote: @escaping (DiscoveredServer) -> Remote
    ) {
        self.model = model
        self.serverState = serverState
        self.holder = holder
        self.source = source
        self.local = local
        self.remote = remote
    }

    public var body: some View {
        Group {
            switch model.selection.source {
            case .thisMac:
                if model.canReadLocal(serverState: serverState) {
                    local()
                } else {
                    HStack(spacing: 0) {
                        VStack {
                            source().padding(12)
                            Spacer()
                        }
                        .frame(width: 260)
                        Divider()
                        MacReaderBlockedView(holder: holder)
                    }
                }
            case .remote(let server):
                remote(server)
            }
        }
        .id(model.selection.source)
    }
}
