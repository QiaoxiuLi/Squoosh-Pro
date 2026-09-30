import AppKit
import SquooshCore
import XCTest
import SwiftUI
@testable import SquooshPro

final class ComparisonPreviewTests: XCTestCase {
    @MainActor
    func testOriginalPreviewInvalidatesAfterFileChanges() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SquooshPreviewChange-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("source.png")
        try NSBitmapImageRep(data: XCTUnwrap(image(.red).tiffRepresentation))?.representation(using: .png, properties: [:])?.write(to: input)
        let model = AppModel(validationOnly: true)
        defer { model.shutdown() }
        model.selectedPreset = .losslessPNG
        model.addURLs([input])
        for _ in 0..<300 {
            if !model.isPreviewing { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let previous = try XCTUnwrap(model.sourcePreview)
        try NSBitmapImageRep(data: XCTUnwrap(image(.blue).tiffRepresentation))?.representation(using: .png, properties: [:])?.write(to: input)
        model.schedulePreview()
        for _ in 0..<300 {
            if !model.isPreviewing { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertNil(model.previewError)
        XCTAssertNotNil(model.outputPreview)
        XCTAssertFalse(previous === model.sourcePreview)
    }
    @MainActor
    func testLivePreviewLatestSelectionCacheAndExport() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SquooshPreviewValidation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("original-red.png")
        let second = root.appendingPathComponent("original-blue.png")
        try NSBitmapImageRep(data: XCTUnwrap(image(.red).tiffRepresentation))?.representation(using: .png, properties: [:])?.write(to: first)
        try NSBitmapImageRep(data: XCTUnwrap(image(.blue).tiffRepresentation))?.representation(using: .png, properties: [:])?.write(to: second)
        let fingerprint = try SourceFingerprint.capture(url: second)
        let model = AppModel(validationOnly: true, validationStore: try AtomicJSONStore(root: root.appendingPathComponent("validation-store")))
        model.selectedPreset = .losslessPNG
        model.addURLs([first, second])
        model.selectItem(model.items[1].id)
        for _ in 0..<300 {
            if !model.isPreviewing { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertNil(model.previewError)
        XCTAssertNotNil(model.sourcePreview)
        XCTAssertNotNil(model.outputPreview)
        XCTAssertEqual(model.selectedItemID, model.items[1].id)
        XCTAssertTrue(model.cachedItemIDs.contains(model.items[1].id))
        model.selectPreset(.webJPEG150KB)
        for _ in 0..<600 {
            if !model.isPreviewing { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertNil(model.previewError)
        XCTAssertNotNil(model.outputPreview)
        XCTAssertLessThanOrEqual(try XCTUnwrap(model.previewBytes), 150_000)
        model.outputParent = root.appendingPathComponent("exports")
        try FileManager.default.createDirectory(at: try XCTUnwrap(model.outputParent), withIntermediateDirectories: true)
        model.startBatch()
        for _ in 0..<600 {
            if model.completedCount + model.failedCount == 2 { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(model.completedCount, 2)
        XCTAssertEqual(model.failedCount, 0)
        XCTAssertTrue(model.cachedItemIDs.isEmpty)
        for item in model.items {
            let output = try XCTUnwrap(item.outputURL)
            XCTAssertLessThanOrEqual(try Data(contentsOf: output).count, 150_000)
        }
        try fingerprint.verifyUnchanged()
        model.shutdown()
    }
    @MainActor
    func testRealSwiftUIWorkspaceAtWideCompactAndShortSizes() throws {
        _ = NSApplication.shared
        let artifacts = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Artifacts/PreviewValidation")
        try FileManager.default.createDirectory(at: artifacts, withIntermediateDirectories: true)
        let model = AppModel(validationOnly: true)
        let item = ImageQueueItem(url: artifacts.appendingPathComponent("synthetic.png"))
        model.items = [item]
        model.selectedItemID = item.id
        model.sourcePreview = image(.systemTeal)
        model.outputPreview = image(.systemBlue)
        model.previewDimensions = ImageDimensions(width: 1000, height: 500)
        model.previewBytes = 120_000
        for size in [CGSize(width: 1400, height: 900), CGSize(width: 960, height: 680), CGSize(width: 720, height: 480), CGSize(width: 1400, height: 480)] {
            let host = NSHostingView(rootView: ContentView().environmentObject(model))
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = host
            host.frame = CGRect(origin: .zero, size: size)
            host.layoutSubtreeIfNeeded()
            window.makeKeyAndOrderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            host.layoutSubtreeIfNeeded()
            let comparisons = descendants(host).compactMap { $0 as? ComparisonCanvas }
            XCTAssertEqual(comparisons.count, 1, "\(size)")
            for canvas in comparisons {
                XCTAssertGreaterThan(canvas.bounds.width, 250, "\(size)")
                XCTAssertGreaterThan(canvas.bounds.height, 150, "\(size)")
                XCTAssertTrue(host.bounds.contains(canvas.convert(canvas.bounds, to: host)), "Preview must stay in the workspace")
            }
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to: artifacts.appendingPathComponent("macos-workspace-\(Int(size.width))x\(Int(size.height)).png"))
            window.close()
        }
    }

    @MainActor private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap { descendants($0) } }
    @MainActor
    func testFitActualZoomAndResizeUseSharedImageGeometry() throws {
        _ = NSApplication.shared
        let canvas = ComparisonCanvas(frame: CGRect(x: 0, y: 0, width: 800, height: 500))
        let window = NSWindow(contentRect: canvas.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = canvas
        canvas.update(source: image(.red), output: image(.blue), dimensions: ImageDimensions(width: 1000, height: 500))
        XCTAssertEqual(canvas.renderedImageFrame.width, 800, accuracy: 1)
        XCTAssertEqual(canvas.renderedImageFrame.height, 400, accuracy: 1)
        canvas.perform(.actual)
        XCTAssertEqual(canvas.displayedPercent, 100)
        XCTAssertEqual(canvas.renderedImageFrame.width, 1000 / window.backingScaleFactor, accuracy: 1)
        canvas.perform(.zoomIn)
        XCTAssertEqual(canvas.displayedPercent, 125)
        canvas.perform(.zoomOut)
        XCTAssertEqual(canvas.displayedPercent, 100)
        canvas.frame.size = CGSize(width: 420, height: 260)
        canvas.perform(.fit)
        XCTAssertEqual(canvas.renderedImageFrame.width, 420, accuracy: 1)
        XCTAssertEqual(canvas.renderedImageFrame.height, 210, accuracy: 1)
        XCTAssertTrue(canvas.accessibilityPerformIncrement())
        XCTAssertEqual(canvas.dividerPosition, 0.55, accuracy: 0.001)
        XCTAssertTrue(canvas.accessibilityPerformDecrement())
        XCTAssertEqual(canvas.dividerPosition, 0.5, accuracy: 0.001)
        window.close()
    }

    @MainActor
    func testComparisonReallyRendersOriginalLeftAndOutputRight() throws {
        _ = NSApplication.shared
        let canvas = ComparisonCanvas(frame: CGRect(x: 0, y: 0, width: 600, height: 300))
        canvas.update(source: image(.red), output: image(.blue), dimensions: ImageDimensions(width: 1000, height: 500))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(data: nil, width: 600, height: 300, bitsPerComponent: 8, bytesPerRow: 2400, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        canvas.layer?.render(in: context)
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let left = (150 * 600 + 100) * 4
        let right = (150 * 600 + 500) * 4
        XCTAssertGreaterThan(bytes[left], 200)
        XCTAssertLessThan(bytes[left + 2], 50)
        XCTAssertGreaterThan(bytes[right + 2], 200)
        XCTAssertLessThan(bytes[right], 50)
        let artifacts = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Artifacts/PreviewValidation")
        try FileManager.default.createDirectory(at: artifacts, withIntermediateDirectories: true)
        let rendered = try XCTUnwrap(context.makeImage())
        try NSBitmapImageRep(cgImage: rendered).representation(using: .png, properties: [:])?.write(to: artifacts.appendingPathComponent("macos-layer-comparison.png"))
    }

    @MainActor
    func testPortraitAndWideImagesRemainInsideViewport() {
        for size in [ImageDimensions(width: 400, height: 1600), ImageDimensions(width: 1600, height: 400)] {
            let canvas = ComparisonCanvas(frame: CGRect(x: 0, y: 0, width: 420, height: 260))
            canvas.update(source: image(.red), output: image(.blue), dimensions: size)
            XCTAssertLessThanOrEqual(canvas.renderedImageFrame.width, 420)
            XCTAssertLessThanOrEqual(canvas.renderedImageFrame.height, 260)
            XCTAssertTrue(canvas.renderedImageFrame.minX >= 0 && canvas.renderedImageFrame.minY >= 0)
        }
    }

    @MainActor
    private func image(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 1000, height: 500), flipped: true) { rect in
            color.setFill(); rect.fill(); return true
        }
    }
}
