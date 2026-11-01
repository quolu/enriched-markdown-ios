import UIKit

/// Finished renders, so a view can show its document on its first layout
/// instead of growing when the async render lands.
///
/// shortcut: one document keeps only its last config, so the same text shown
/// at two font sizes re-renders on each switch. Key by config if that shows up.
final class MarkdownRenderCache: @unchecked Sendable {
    static let shared = MarkdownRenderCache()

    private final class Entry {
        let config: MarkdownStyleConfig
        let flags: Md4cFlags
        let text: NSAttributedString

        init(config: MarkdownStyleConfig, flags: Md4cFlags, text: NSAttributedString) {
            self.config = config
            self.flags = flags
            self.text = text
        }
    }

    // NSCache is thread-safe and drops entries under memory pressure.
    private let entries = NSCache<NSString, Entry>()

    func text(for markdown: String, config: MarkdownStyleConfig, flags: Md4cFlags) -> NSAttributedString? {
        guard let entry = entries.object(forKey: markdown as NSString),
              entry.flags == flags, entry.config == config else { return nil }
        return entry.text
    }

    func store(_ text: NSAttributedString, for markdown: String, config: MarkdownStyleConfig, flags: Md4cFlags) {
        entries.setObject(Entry(config: config, flags: flags, text: text), forKey: markdown as NSString)
    }

    func removeAll() {
        entries.removeAllObjects()
    }
}
