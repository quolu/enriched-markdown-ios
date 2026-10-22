import UIKit

enum MarkdownDecorationPass {
    case background
    case foreground
}

final class MarkdownViewportDecorator {
    private weak var backgroundView: MarkdownDecorationView?
    private weak var foregroundView: MarkdownDecorationView?
    private var config = BlockDecorationConfig(styleConfig: .baseline())

    init(backgroundView: MarkdownDecorationView, foregroundView: MarkdownDecorationView) {
        self.backgroundView = backgroundView
        self.foregroundView = foregroundView
    }

    func updateStyleConfig(_ styleConfig: MarkdownStyleConfig) {
        config = BlockDecorationConfig(styleConfig: styleConfig)
    }

    func setNeedsDisplay() {
        backgroundView?.setNeedsDisplay()
        foregroundView?.setNeedsDisplay()
    }

    func draw(in context: CGContext, textView: UITextView, pass: MarkdownDecorationPass) {
        guard let textLayoutManager = textView.textLayoutManager,
              let textContentStorage = textLayoutManager.textContentManager as? NSTextContentStorage,
              let textStorage = textContentStorage.textStorage,
              textStorage.length > 0 else {
            return
        }

        let contentManager: NSTextContentManager = textContentStorage
        let containerWidth = textView.textContainer.size.width
        let origin = CGPoint(x: 0, y: -textView.contentOffset.y)
        let visibleRange = visibleCharacterRange(
            textLayoutManager: textLayoutManager,
            contentManager: contentManager
        )

        switch pass {
        case .background:
            let drawContext = BlockDrawContext(
                context: context,
                textStorage: textStorage,
                textLayoutManager: textLayoutManager,
                contentManager: contentManager,
                containerWidth: containerWidth,
                origin: origin,
                visibleCharacterRange: visibleRange,
                decorationConfig: config
            )
            CodeBlockBackgroundDrawer.draw(in: drawContext)
            BlockquoteBorderDrawer.drawBackgrounds(in: drawContext)
        case .foreground:
            let drawContext = BlockDrawContext(
                context: context,
                textStorage: textStorage,
                textLayoutManager: textLayoutManager,
                contentManager: contentManager,
                containerWidth: containerWidth,
                origin: origin,
                visibleCharacterRange: visibleRange,
                decorationConfig: config
            )
            BlockquoteBorderDrawer.drawBorders(in: drawContext)
            ParagraphMarkerDrawer.draw(
                in: MarkerDrawContext(
                    context: context,
                    textStorage: textStorage,
                    textLayoutManager: textLayoutManager,
                    contentManager: contentManager,
                    origin: origin,
                    visibleCharacterRange: visibleRange,
                    decorationConfig: config
                )
            )
        }
    }

    private func visibleCharacterRange(
        textLayoutManager: NSTextLayoutManager,
        contentManager: NSTextContentManager
    ) -> NSRange {
        guard let viewportRange = textLayoutManager.textViewportLayoutController.viewportRange,
              let range = TextLayoutHelpers.nsRange(viewportRange, in: contentManager) else {
            // 初回やスクロールしない表示ではTextKit 2の表示範囲が未確定のことがある。
            // その時は文書全体を描き、初回からブロックの装飾を表示する。
            return TextLayoutHelpers.nsRange(contentManager.documentRange, in: contentManager)
                ?? NSRange(location: 0, length: 0)
        }
        return range
    }
}

final class MarkdownDecorationView: UIView {
    weak var textView: UITextView?
    var viewportDecorator: MarkdownViewportDecorator?
    var pass: MarkdownDecorationPass = .background

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let textView,
              let viewportDecorator else {
            return
        }
        viewportDecorator.draw(in: context, textView: textView, pass: pass)
    }
}
