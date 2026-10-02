import SwiftUI

public struct ReaderInspectorAction {
    public let isPresented: Bool
    public let toggle: () -> Void

    public init(isPresented: Bool, toggle: @escaping () -> Void) {
        self.isPresented = isPresented
        self.toggle = toggle
    }
}

private struct ReaderSidebarRefreshKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct ReaderDiffRefreshKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct ReaderInspectorKey: FocusedValueKey {
    typealias Value = ReaderInspectorAction
}

extension FocusedValues {
    public var readerSidebarRefresh: (() -> Void)? {
        get { self[ReaderSidebarRefreshKey.self] }
        set { self[ReaderSidebarRefreshKey.self] = newValue }
    }

    public var readerDiffRefresh: (() -> Void)? {
        get { self[ReaderDiffRefreshKey.self] }
        set { self[ReaderDiffRefreshKey.self] = newValue }
    }

    public var readerInspector: ReaderInspectorAction? {
        get { self[ReaderInspectorKey.self] }
        set { self[ReaderInspectorKey.self] = newValue }
    }
}
