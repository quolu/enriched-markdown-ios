import SwiftUI
import UIKit

private let prerenderQueue = DispatchQueue(label: "com.swmansion.enriched.markdown.prerender", qos: .userInitiated)

private struct RenderedDocument {
    let text: NSAttributedString
    let source: RenderedSource
}

public struct EnrichedMarkdownText: View {
    private let markdown: String
    private let flags: Md4cFlags

    @Environment(\.markdownThemeLayers) private var themeLayers
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.markdownLinkPressHandler) private var onLinkPress
    @Environment(\.markdownLinkLongPressHandler) private var onLinkLongPress
    @Environment(\.markdownSelectionMenu) private var selectionMenuConfig
    @Environment(\.markdownSelectable) private var isSelectionEnabled
    @Environment(\.markdownSelectionColor) private var selectionColor
    @Environment(\.markdownImageRequestHeaders) private var imageRequestHeaders
    @Environment(\.markdownRenderPlugins) private var renderPlugins
    @Environment(\.markdownTaskListItemPressHandler) private var onTaskListItemPress
    @Environment(\.markdownTaskListItemToggleEnabled) private var isTaskListToggleEnabled
    @Environment(\.markdownSpoilerOverlay) private var spoilerOverlay
    @Environment(\.markdownAccessibilityLabels) private var accessibilityLabels
    @Environment(\.markdownHighlight) private var highlight
    @StateObject private var renderStore = MarkdownRenderStore()

    public init(_ markdown: String, flags: Md4cFlags = .commonMark) {
        self.markdown = markdown
        self.flags = flags
    }

    private var styleConfig: MarkdownStyleConfig {
        Self.styleConfig(
            themeLayers: themeLayers,
            plugins: renderPlugins,
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    private static func styleConfig(
        themeLayers: [MarkdownTheme],
        plugins: [any MarkdownRenderPlugin],
        colorScheme: ColorScheme,
        dynamicTypeSize: DynamicTypeSize
    ) -> MarkdownStyleConfig {
        let traitCollection = ThemeResolver.traitCollection(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize
        )
        // Plugin defaults go above `MarkdownTheme.default` (the environment's
        // first layer) and below the app's themes.
        var layers = themeLayers
        layers.insert(contentsOf: plugins.compactMap(\.defaultTheme), at: min(1, layers.count))
        return MarkdownStyleConfig.resolve(layers: layers, traitCollection: traitCollection)
    }

    /// Renders `markdowns` off the main thread, so a view created later with
    /// the same document shows it on its first layout, at its final height.
    /// Pass the environment the views will inherit, and the theme they add with
    /// `markdownTheme`. Documents already rendered are skipped. A theme color
    /// left on `tintColor` resolves by the ambient view, so it can differ here
    /// and miss the cache: set it explicitly in `theme`.
    @MainActor
    public static func prerender(
        _ markdowns: [String],
        flags: Md4cFlags = .commonMark,
        theme: MarkdownTheme,
        environment: EnvironmentValues
    ) async {
        // Same limit as `MarkdownRenderStore.schedule`: these are not in the cache key.
        guard environment.markdownImageRequestHeaders.isEmpty, environment.markdownRenderPlugins.isEmpty else { return }
        let config = styleConfig(
            themeLayers: environment.markdownThemeLayers + [theme],
            plugins: [],
            colorScheme: environment.colorScheme,
            dynamicTypeSize: environment.dynamicTypeSize
        )
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            prerenderQueue.async {
                for markdown in markdowns
                where MarkdownRenderCache.shared.text(for: markdown, config: config, flags: flags) == nil {
                    let text = MarkdownRenderer.render(markdown, config: config, flags: flags)
                    MarkdownRenderCache.shared.store(text, for: markdown, config: config, flags: flags)
                }
                continuation.resume()
            }
        }
    }

    private func prerendered(config: MarkdownStyleConfig) -> RenderedDocument? {
        guard !renderStore.holds(markdown), imageRequestHeaders.isEmpty, renderPlugins.isEmpty else { return nil }
        return MarkdownRenderCache.shared.text(for: markdown, config: config, flags: flags).map {
            RenderedDocument(text: $0, source: RenderedSource(markdown: markdown, flags: flags))
        }
    }

    public var body: some View {
        // Resolved once: `styleConfig` rebuilds the whole config on each read,
        // and the representable and every `onChange` below read it.
        let config = styleConfig
        let prerendered = prerendered(config: config)
        return MarkdownTextViewRepresentable(
            attributedText: prerendered?.text ?? renderStore.attributedText,
            source: prerendered?.source ?? renderStore.source,
            styleConfig: config,
            onLinkPress: onLinkPress,
            onLinkLongPress: onLinkLongPress,
            selectionMenuConfig: selectionMenuConfig,
            isSelectionEnabled: isSelectionEnabled,
            selectionColor: selectionColor,
            onTaskListItemTap: isTaskListToggleEnabled ? { hit in
                let checked = !hit.checked
                renderStore.applyTaskListToggle(index: hit.index, checked: checked, config: config)
                onTaskListItemPress?(
                    TaskListItemPressEvent(index: hit.index, checked: checked, text: hit.itemText)
                )
            } : nil,
            spoilerOverlay: spoilerOverlay,
            onSpoilerTap: { range in
                renderStore.revealSpoiler(in: range)
            },
            accessibilityLabels: accessibilityLabels,
            highlight: highlight
        )
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            renderStore.schedule(
                markdown: markdown,
                config: config,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders,
                plugins: renderPlugins
            )
        }
        // The onChange closures run against the previous view value, so the
        // changed value must come from the closure parameter — reading the
        // view property would render one update behind.
        .onChange(of: markdown) { newValue in
            renderStore.schedule(
                markdown: newValue,
                config: config,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders,
                plugins: renderPlugins
            )
        }
        .onChange(of: config) { newValue in
            renderStore.schedule(
                markdown: markdown,
                config: newValue,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders,
                plugins: renderPlugins
            )
        }
        .onChange(of: flags) { newValue in
            renderStore.schedule(
                markdown: markdown,
                config: config,
                flags: newValue,
                imageRequestHeaders: imageRequestHeaders,
                plugins: renderPlugins
            )
        }
        .onChange(of: imageRequestHeaders) { newValue in
            renderStore.schedule(
                markdown: markdown,
                config: config,
                flags: flags,
                imageRequestHeaders: newValue,
                plugins: renderPlugins
            )
        }
        .onDisappear {
            renderStore.invalidate()
        }
    }
}

#if DEBUG
private let previewMarkdown = """
# Enriched Markdown

Paragraphs support **bold**, *italic*, `inline code`, and [links](https://swmansion.com).

## Lists

- First item
- Second item
  1. Nested ordered item
  2. Another one

> Blockquotes render with a border and background.

```swift
let answer = 42
```

---

Final paragraph after a thematic break.
"""

#Preview("Default theme") {
    ScrollView {
        EnrichedMarkdownText(previewMarkdown)
            .padding()
    }
}

#Preview("Default theme, dark") {
    ScrollView {
        EnrichedMarkdownText(previewMarkdown)
            .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("Custom theme") {
    ScrollView {
        EnrichedMarkdownText(previewMarkdown)
            .padding()
    }
    .markdownTheme(
        MarkdownTheme {
            Heading(1)
                .foregroundStyle(.purple)
            Link()
                .foregroundStyle(.teal)
                .underline(true)
            Blockquote()
                .borderColor(.orange)
                .borderWidth(4)
        }
    )
}
#endif
