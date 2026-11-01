import SwiftUI
import XCTest
@testable import EnrichedMarkdown

@MainActor
final class MarkdownRenderCacheTests: XCTestCase {
    private let config = MarkdownStyleConfig.resolve(layers: [.default], traitCollection: UITraitCollection())

    override func setUp() async throws {
        MarkdownRenderCache.shared.removeAll()
    }

    func testPrerenderedDocumentIsAppliedWithoutWaitingForARender() async {
        await EnrichedMarkdownText.prerender(["# 見出し"], theme: MarkdownTheme {}, environment: EnvironmentValues())
        let store = MarkdownRenderStore()
        let environment = EnvironmentValues()
        let config = MarkdownStyleConfig.resolve(
            layers: environment.markdownThemeLayers + [MarkdownTheme {}],
            traitCollection: ThemeResolver.traitCollection(
                colorScheme: environment.colorScheme,
                dynamicTypeSize: environment.dynamicTypeSize
            )
        )
        store.schedule(markdown: "# 見出し", config: config)
        XCTAssertEqual(store.attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines), "見出し")
    }

    func testOtherConfigOrFlagsMiss() {
        let text = NSAttributedString(string: "本文")
        MarkdownRenderCache.shared.store(text, for: "本文", config: config, flags: .commonMark)
        XCTAssertTrue(MarkdownRenderCache.shared.text(for: "本文", config: config, flags: .commonMark) === text)
        XCTAssertNil(MarkdownRenderCache.shared.text(for: "本文", config: config, flags: Md4cFlags(hardSoftBreaks: true)))
        let other = MarkdownStyleConfig.resolve(
            layers: [.default, MarkdownTheme { Paragraph().fontSize(40) }],
            traitCollection: UITraitCollection()
        )
        XCTAssertNil(MarkdownRenderCache.shared.text(for: "本文", config: other, flags: .commonMark))
    }

    func testFinishedRenderIsCachedForTheNextView() {
        let first = MarkdownRenderStore()
        first.schedule(markdown: "再利用", config: config)
        let rendered = expectation(for: NSPredicate { _, _ in first.source != nil }, evaluatedWith: nil)
        wait(for: [rendered], timeout: 5)

        let second = MarkdownRenderStore()
        second.schedule(markdown: "再利用", config: config)
        XCTAssertTrue(second.attributedText === first.attributedText)
    }
}
