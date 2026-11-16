import SwiftUI

/// An app-defined item of the text-selection edit menu. `handler` receives the selected text as shown (plain text).
public struct MarkdownSelectionMenuAction: Equatable, Sendable {
    public var title: String
    public var systemImageName: String
    public var handler: @MainActor (String) -> Void

    public init(title: String, systemImageName: String, handler: @escaping @MainActor (String) -> Void) {
        self.title = title
        self.systemImageName = systemImageName
        self.handler = handler
    }

    // The handler is not compared: a new closure each update must not count as a change.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title && lhs.systemImageName == rhs.systemImageName
    }
}

/// Configuration for the custom items added to the text-selection edit menu.
public struct MarkdownSelectionMenuConfig: Equatable, Sendable {
    public var copyAsMarkdown: Bool
    public var copyImageUrl: Bool
    public var copyAsMarkdownLabel: String
    /// Extra items shown for a non-empty selection, after the built-in ones.
    public var customActions: [MarkdownSelectionMenuAction]

    public init(
        copyAsMarkdown: Bool = true,
        copyImageUrl: Bool = true,
        copyAsMarkdownLabel: String = "Copy as Markdown",
        customActions: [MarkdownSelectionMenuAction] = []
    ) {
        self.copyAsMarkdown = copyAsMarkdown
        self.copyImageUrl = copyImageUrl
        self.copyAsMarkdownLabel = copyAsMarkdownLabel
        self.customActions = customActions
    }
}

private struct MarkdownSelectionMenuKey: EnvironmentKey {
    static let defaultValue = MarkdownSelectionMenuConfig()
}

public extension EnvironmentValues {
    var markdownSelectionMenu: MarkdownSelectionMenuConfig {
        get { self[MarkdownSelectionMenuKey.self] }
        set { self[MarkdownSelectionMenuKey.self] = newValue }
    }
}

public extension View {
    /// Configures the custom edit-menu items ("Copy as Markdown",
    /// "Copy Image URL") shown when text is selected.
    func markdownSelectionMenu(_ config: MarkdownSelectionMenuConfig) -> some View {
        environment(\.markdownSelectionMenu, config)
    }
}
