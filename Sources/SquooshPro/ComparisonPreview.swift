import AppKit
import SwiftUI
import SquooshCore

@MainActor
final class PreviewNavigation: ObservableObject {
    @Published var command = 0
    @Published var action = Action.fit
    @Published var percent = 100
    enum Action { case fit, actual, zoomIn, zoomOut }
    func perform(_ action: Action) { self.action = action; command += 1 }
}

struct ComparisonPreview: NSViewRepresentable {
    let source: NSImage
    let output: NSImage?
    let dimensions: ImageDimensions?
    @ObservedObject var navigation: PreviewNavigation

    func makeNSView(context: Context) -> ComparisonCanvas { ComparisonCanvas() }
    func updateNSView(_ view: ComparisonCanvas, context: Context) {
        view.update(source: source, output: output, dimensions: dimensions)
        view.zoomChanged = { [weak navigation] value in
            guard navigation?.percent != value else { return }
            DispatchQueue.main.async { navigation?.percent = value }
        }
        if view.command != navigation.command {
            view.command = navigation.command
            view.perform(navigation.action)
        }
    }
}

// Layer transforms keep image decoding and SwiftUI layout out of the pointer hot path.
@MainActor
final class ComparisonCanvas: NSView {
    private let originalLayer = CALayer()
    private let outputLayer = CALayer()
    private let outputContainer = CALayer()
    private let outputMask = CALayer()
    private let dividerLayer = CALayer()
    private let handleLayer = CALayer()
    private let arrows = CATextLayer()
    private var sourceIdentity: ObjectIdentifier?
    private var outputIdentity: ObjectIdentifier?
    private var pixels = CGSize(width: 1, height: 1)
    private var scale: CGFloat = 1
    private var offset = CGPoint.zero
    private var split: CGFloat = 0.5
    private var fitting = true
    private var dividing = false
    private var lastPoint = CGPoint.zero
    var command = 0
    var zoomChanged: ((Int) -> Void)?
    var renderedImageFrame: CGRect { originalLayer.frame }
    var dividerPosition: CGFloat { split }
    var displayedPercent: Int { Int((scale * backing * 100).rounded()) }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        originalLayer.contentsGravity = .resize
        outputLayer.contentsGravity = .resize
        layer?.addSublayer(originalLayer)
        outputContainer.addSublayer(outputLayer)
        outputContainer.mask = outputMask
        outputMask.backgroundColor = NSColor.white.cgColor
        layer?.addSublayer(outputContainer)
        dividerLayer.backgroundColor = NSColor.white.cgColor
        dividerLayer.shadowColor = NSColor.black.cgColor
        dividerLayer.shadowOpacity = 0.4
        dividerLayer.shadowRadius = 2
        layer?.addSublayer(dividerLayer)
        handleLayer.backgroundColor = NSColor.white.cgColor
        handleLayer.cornerRadius = 22
        handleLayer.shadowOpacity = 0.25
        handleLayer.shadowRadius = 4
        layer?.addSublayer(handleLayer)
        arrows.string = "↔"
        arrows.fontSize = 22
        arrows.alignmentMode = .center
        arrows.foregroundColor = NSColor.black.cgColor
        handleLayer.addSublayer(arrows)
        setAccessibilityElement(true)
        setAccessibilityRole(.slider)
        setAccessibilityMinValue(2)
        setAccessibilityMaxValue(98)
        setAccessibilityIdentifier("preview.comparison")
        setAccessibilityLabel("拖动分界线对比原图和输出，放大后拖动画面")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(source: NSImage, output: NSImage?, dimensions: ImageDimensions?) {
        if sourceIdentity != ObjectIdentifier(source) {
            sourceIdentity = ObjectIdentifier(source)
            let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
            originalLayer.contents = cg
            pixels = CGSize(width: cg?.width ?? 1, height: cg?.height ?? 1)
            fitting = true
            offset = .zero
        }
        let identity = output.map(ObjectIdentifier.init)
        if outputIdentity != identity {
            outputIdentity = identity
            outputLayer.contents = output?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        if let dimensions { pixels = CGSize(width: dimensions.width, height: dimensions.height) }
        positionLayers()
    }
    override func layout() { super.layout(); positionLayers() }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); positionLayers() }
    private var fitScale: CGFloat { min(bounds.width / max(1, pixels.width), bounds.height / max(1, pixels.height)) }
    private var backing: CGFloat { window?.backingScaleFactor ?? 2 }
    func perform(_ action: PreviewNavigation.Action) {
        switch action {
        case .fit: fitting = true; offset = .zero
        case .actual: fitting = false; scale = 1 / backing; offset = .zero
        case .zoomIn: zoom(1.25)
        case .zoomOut: zoom(1 / 1.25)
        }
        positionLayers()
    }
    private func zoom(_ factor: CGFloat, anchor: CGPoint? = nil) {
        let previous = fitting ? fitScale : scale
        fitting = false
        scale = min(8 / backing, max(min(fitScale, 0.05), previous * factor))
        let p = anchor ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let ratio = scale / max(0.0001, previous)
        offset.x = (offset.x - p.x + bounds.midX) * ratio + p.x - bounds.midX
        offset.y = (offset.y - p.y + bounds.midY) * ratio + p.y - bounds.midY
        positionLayers()
    }
    private func positionLayers() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        if fitting { scale = fitScale }
        let size = CGSize(width: pixels.width * scale, height: pixels.height * scale)
        let dx = max(0, (size.width - bounds.width) / 2)
        let dy = max(0, (size.height - bounds.height) / 2)
        offset.x = min(dx, max(-dx, offset.x)); offset.y = min(dy, max(-dy, offset.y))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let frame = CGRect(x: (bounds.width - size.width) / 2 + offset.x, y: (bounds.height - size.height) / 2 + offset.y, width: size.width, height: size.height)
        originalLayer.frame = frame
        outputContainer.frame = bounds
        outputLayer.frame = frame
        let x = bounds.width * split
        outputMask.frame = CGRect(x: x, y: 0, width: bounds.width - x, height: bounds.height)
        dividerLayer.frame = CGRect(x: x - 1, y: 0, width: 2, height: bounds.height)
        handleLayer.frame = CGRect(x: min(bounds.width - 44, max(0, x - 22)), y: bounds.midY - 22, width: 44, height: 44)
        arrows.contentsScale = backing
        arrows.frame = CGRect(x: 0, y: 7, width: 44, height: 30)
        CATransaction.commit()
        setAccessibilityValue(Double(split * 100))
        setAccessibilityValueDescription("分割位置 \(Int(split * 100))%，缩放 \(Int((scale * backing * 100).rounded()))%")
        zoomChanged?(Int((scale * backing * 100).rounded()))
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastPoint = convert(event.locationInWindow, from: nil)
        dividing = abs(lastPoint.x - bounds.width * split) < 24
    }
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if dividing { split = min(0.98, max(0.02, point.x / max(1, bounds.width))) }
        else if !fitting { offset.x += point.x - lastPoint.x; offset.y += point.y - lastPoint.y }
        lastPoint = point
        positionLayers()
    }
    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) || !event.hasPreciseScrollingDeltas {
            zoom(event.scrollingDeltaY > 0 ? 1.1 : 1 / 1.1, anchor: convert(event.locationInWindow, from: nil))
        } else if !fitting {
            offset.x -= event.scrollingDeltaX; offset.y -= event.scrollingDeltaY
            positionLayers()
        }
    }
    override func magnify(with event: NSEvent) { zoom(1 + event.magnification, anchor: convert(event.locationInWindow, from: nil)) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 123 { split = max(0.02, split - 0.05) }
        else if event.keyCode == 124 { split = min(0.98, split + 0.05) }
        else { super.keyDown(with: event); return }
        positionLayers()
    }
    override func accessibilityPerformIncrement() -> Bool { split = min(0.98, split + 0.05); positionLayers(); return true }
    override func accessibilityPerformDecrement() -> Bool { split = max(0.02, split - 0.05); positionLayers(); return true }
}
