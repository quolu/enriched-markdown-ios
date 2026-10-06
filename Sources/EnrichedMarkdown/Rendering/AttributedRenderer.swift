import UIKit

final class AttributedRenderer {
    private let config: MarkdownStyleConfig
    private let factory: RendererFactory
    /// Root-level plugin block node types and the margins each declares.
    private let rootBlockMargins: [NodeType: BlockMargins]

    init(
        config: MarkdownStyleConfig,
        imageRequestHeaders: [String: String] = [:],
        plugins: [any MarkdownRenderPlugin] = []
    ) {
        self.config = config
        self.factory = RendererFactory(
            config: config,
            imageRequestHeaders: imageRequestHeaders,
            plugins: plugins
        )
        self.rootBlockMargins = plugins.reduce(into: [:]) { margins, plugin in
            for type in plugin.rootBlockNodeTypes where margins[type] == nil {
                margins[type] = plugin.blockMargins(for: type, config: config)
            }
        }
    }

    func renderRoot(_ root: MarkdownASTNode) -> NSMutableAttributedString {
        let context = RenderContext()
        let output = NSMutableAttributedString()

        let paragraphFont = config.paragraph.font ?? UIFont.preferredFont(forTextStyle: .body)
        let paragraphColor = config.paragraph.foregroundColor ?? UIColor.label
        context.setBlockStyle(font: paragraphFont, color: paragraphColor)

        for child in root.children {
            // A synthetic paragraph gives bare plugin block nodes their
            // block margins and alignment.
            if let margins = rootBlockMargins[child.type] {
                context.pluginBlockMargins = margins
                let paragraph = MarkdownASTNode(type: .paragraph, children: [child])
                factory.renderer(for: .paragraph).render(node: paragraph, into: output, context: context)
                context.pluginBlockMargins = nil
                continue
            }
            factory.renderer(for: child.type).render(node: child, into: output, context: context)
        }

        context.clearBlockStyle()
        if !config.allowTrailingMargin { removeTrailingSpacing(from: output) }
        BaselineShiftRenderer.applyShifts(to: output, config: config)
        SpoilerConcealment.conceal(output, in: NSRange(location: 0, length: output.length))
        return output
    }

    /// 段落間の余白は残し、文書末尾の段落区切りと余白だけを除く。
    /// コード枠の内側の下余白は保持し、背景の終端に高さ1ptの区切りを残す。
    private func removeTrailingSpacing(from output: NSMutableAttributedString) {
        let lastContent = (output.string as NSString).rangeOfCharacter(
            from: CharacterSet.newlines.inverted, options: .backwards
        )
        guard lastContent.location != NSNotFound else { return }
        let isCode = output.attribute(MarkdownAttribute.codeBlock, at: lastContent.location, effectiveRange: nil) != nil
        var codeRange = NSRange()
        var logicalEnd = NSMaxRange(lastContent)
        if isCode {
            _ = output.attribute(MarkdownAttribute.codeBlock, at: lastContent.location,
                                 longestEffectiveRange: &codeRange, in: NSRange(location: 0, length: output.length))
            if NSMaxRange(codeRange) == output.length { output.append(ParagraphStyleHelpers.newline) }
            logicalEnd = NSMaxRange(codeRange) + 1
        }
        if logicalEnd < output.length {
            output.deleteCharacters(in: NSRange(location: logicalEnd, length: output.length - logicalEnd))
        }
        if isCode {
            let tail = NSRange(location: NSMaxRange(codeRange), length: 1)
            output.removeAttribute(MarkdownAttribute.codeBlock, range: tail)
            let style = ParagraphStyleHelpers.getOrCreateParagraphStyle(in: output, at: tail.location)
            style.paragraphSpacing = 0
            style.paragraphSpacingBefore = 0
            style.minimumLineHeight = 1
            style.maximumLineHeight = 1
            output.addAttribute(.paragraphStyle, value: style, range: tail)
        } else {
            var range = NSRange()
            if let style = output.attribute(.paragraphStyle, at: lastContent.location,
                                            effectiveRange: &range) as? NSParagraphStyle,
               let finalStyle = style.mutableCopy() as? NSMutableParagraphStyle {
                finalStyle.paragraphSpacing = 0
                output.addAttribute(.paragraphStyle, value: finalStyle,
                                    range: NSIntersectionRange(range, NSRange(location: 0, length: output.length)))
            }
        }
    }
}
