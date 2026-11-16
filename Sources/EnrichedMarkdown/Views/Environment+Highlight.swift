import SwiftUI

/// Briefly marks the first occurrence of `text` in the shown document. A new `token` marks again;
/// the same token never re-marks, so a parent that re-evaluates keeps the document still.
public struct MarkdownHighlight: Equatable, Sendable {
    public var text: String
    /// UTF-16 offset in the shown text to start searching from. The first occurrence overall is used when none follows it.
    public var fromUTF16: Int
    public var token: Int

    public init(text: String, fromUTF16: Int = 0, token: Int) {
        self.text = text
        self.fromUTF16 = fromUTF16
        self.token = token
    }

    func range(in shown: String) -> NSRange? {
        guard !text.isEmpty else { return nil }
        let nsShown = shown as NSString
        let start = min(max(0, fromUTF16), nsShown.length)
        let after = nsShown.range(of: text, range: NSRange(location: start, length: nsShown.length - start))
        if after.location != NSNotFound { return after }
        let first = nsShown.range(of: text)
        return first.location == NSNotFound ? nil : first
    }
}

private struct MarkdownHighlightKey: EnvironmentKey {
    static let defaultValue: MarkdownHighlight? = nil
}

public extension EnvironmentValues {
    var markdownHighlight: MarkdownHighlight? {
        get { self[MarkdownHighlightKey.self] }
        set { self[MarkdownHighlightKey.self] = newValue }
    }
}

public extension View {
    /// Marks a part of the shown text for about two seconds. See `MarkdownHighlight`.
    func markdownHighlight(_ highlight: MarkdownHighlight?) -> some View {
        environment(\.markdownHighlight, highlight)
    }
}
