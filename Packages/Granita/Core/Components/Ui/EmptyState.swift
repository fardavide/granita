import SwiftUI

/// Pins the hierarchy that iOS 27's unavailable-content view no longer supplies.
public struct EmptyState<Title: View, Description: View, Actions: View>: View {

    private let title: Title
    private let description: Description
    private let actions: Actions

    public init(
        @ViewBuilder title: () -> Title,
        @ViewBuilder description: () -> Description,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title()
        self.description = description()
        self.actions = actions()
    }

    public var body: some View {
        ContentUnavailableView {
            title.font(.title2.bold())
        } description: {
            description.font(.body)
        } actions: {
            actions
        }
    }
}

extension EmptyState where Actions == EmptyView {

    public init(
        @ViewBuilder title: () -> Title,
        @ViewBuilder description: () -> Description
    ) {
        self.init(title: title, description: description, actions: { EmptyView() })
    }
}
