import CoreGraphics
import Darwin
import Foundation
import ImageIO
import SquooshCore

private var failures = 0

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() { print("PASS \(message)") }
    else { failures += 1; print("FAIL \(message)") }
}

do {
    for preset in CompressionPreset.builtIns { try PresetValidator.validate(preset) }
    check(true, "built-in preset validation")

    let search = try TargetSizeSearch.highestQuality(initialQuality: 75, minimumQuality: 35, targetBytes: 145, maximumAttempts: 8) { Data(repeating: 0, count: $0 * 2) }
    check(search.quality == 72 && search.byteCount == 144, "highest-quality byte search")

    let processor = ImageProcessor()
    let resized = processor.targetDimensions(source: .init(width: 4000, height: 3000), resize: .init(mode: .fixedWidth, width: 1000))
    check(resized == .init(width: 1000, height: 750), "aspect-ratio resize")
    let notUpscaled = processor.targetDimensions(source: .init(width: 640, height: 480), resize: .init(mode: .fixedWidth, width: 1000))
    check(notUpscaled == .init(width: 640, height: 480), "no-upscale rule")

    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SquooshProCheck-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let width = 1200
    let height = 900
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 0.95, green: 0.72, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    for index in 0..<60 {
        let value = CGFloat(index) / 60
        context.setFillColor(CGColor(red: value, green: 0.25, blue: 1 - value, alpha: 0.8))
        context.fillEllipse(in: CGRect(x: (index * 83) % width, y: (index * 47) % height, width: 180, height: 180))
    }
    let image = context.makeImage()!
    let png = try processor.encode(image: image, format: .oxipng, quality: 100)
    let sourceURL = root.appendingPathComponent("generated-input.png")
    try png.write(to: sourceURL, options: .atomic)
    let before = try SourceFingerprint.capture(url: sourceURL)

    let result = try processor.encode(url: sourceURL, preset: .webJPEG150KB)
    check(result.data.count <= 150_000, "strict 150,000-byte output")
    check(result.dimensions.width <= 1000, "adaptive width limit")

    let writer = SafeOutputWriter()
    let outputDirectory = try writer.createTimestampedDirectory(parent: root, date: Date(timeIntervalSince1970: 1_700_000_000))
    let outputURL = writer.nextOutputURL(directory: outputDirectory, sourceName: sourceURL.lastPathComponent, preset: .webJPEG150KB, format: result.format)
    try writer.commit(result, to: outputURL, sourceURLs: [sourceURL], targetBytes: 150_000)
    check(FileManager.default.fileExists(atPath: outputURL.path), "atomic committed output")
    try writer.verify(url: outputURL, expectedFormat: .mozjpeg, expectedDimensions: result.dimensions, targetBytes: 150_000)
    check(true, "output signature, dimensions, decode, and byte verification")
    try before.verifyUnchanged()
    check(true, "source fingerprint unchanged")

    let conflictURL = writer.nextOutputURL(directory: outputDirectory, sourceName: sourceURL.lastPathComponent, preset: .webJPEG150KB, format: result.format)
    check(conflictURL.lastPathComponent.contains("-1"), "existing output conflict rename")

    let transparentContext = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 32 * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    transparentContext.clear(CGRect(x: 0, y: 0, width: 32, height: 32))
    transparentContext.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    transparentContext.fill(CGRect(x: 16, y: 0, width: 16, height: 32))
    let transparentPNG = try processor.encode(image: transparentContext.makeImage()!, format: .oxipng, quality: 100)
    let transparentURL = root.appendingPathComponent("transparent.png")
    try transparentPNG.write(to: transparentURL)
    let flattened = try processor.encode(url: transparentURL, preset: .websiteJPEG)
    var sample = [UInt8](repeating: 0, count: 4)
    let sampleContext = CGContext(data: &sample, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    sampleContext.draw(CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(flattened.data as CFData, nil)!, 0, nil)!, in: CGRect(x: 0, y: 0, width: 2, height: 1))
    check(sample[0] > 220 && sample[1] > 220 && sample[2] > 220, "JPEG alpha flattened onto white background")

    let recoveryPersistence = try AtomicJSONStore(bundleIdentifier: "com.qiaoxiuli.squoosh-pro.check-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: recoveryPersistence.root) }
    let recoveryStore = SecurityScopedRecoveryStore(store: recoveryPersistence)
    let recoveryID = UUID()
    var recoveryRecord = try recoveryStore.makeRecord(
        jobID: recoveryID,
        outputDirectory: outputDirectory,
        preset: .webJPEG150KB,
        sources: [RecoverableSource(id: recoveryID, url: sourceURL, securityScopedBookmark: nil)]
    )
    recoveryRecord.items[0].fingerprint = before
    try recoveryStore.save(recoveryRecord)
    guard let loadedRecovery = recoveryStore.records().first(where: { $0.id == recoveryID }) else {
        throw SquooshProError.verifyFailed
    }
    let resolvedRecovery = try recoveryStore.resolve(loadedRecovery)
    check(resolvedRecovery.sourceURLs[recoveryID]?.path == sourceURL.path, "security-scoped source bookmark restoration")
    check(resolvedRecovery.outputDirectory.path == outputDirectory.path, "security-scoped output bookmark restoration")
    resolvedRecovery.access.stop()
    try recoveryStore.remove(jobID: recoveryID)
    check(recoveryStore.records().isEmpty, "completed recovery record cleanup")

    if ProcessInfo.processInfo.environment["SQUOOSH_RUN_48MP_AVIF"] == "1" {
        let largeWidth = 8000
        let largeHeight = 6000
        guard processor.supportsNativeEncoding(.avif),
              let largeContext = CGContext(
                data: nil,
                width: largeWidth,
                height: largeHeight,
                bitsPerComponent: 8,
                bytesPerRow: largeWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { throw SquooshProError.unsupportedFormat }
        for stripe in 0..<120 {
            let fraction = CGFloat(stripe) / 119
            largeContext.setFillColor(CGColor(red: fraction, green: 0.8 - fraction * 0.5, blue: 1 - fraction, alpha: 1))
            largeContext.fill(CGRect(x: 0, y: stripe * 50, width: largeWidth, height: 50))
        }
        guard let largeImage = largeContext.makeImage() else { throw SquooshProError.decodeFailed }
        let avif = try processor.encode(image: largeImage, format: .avif, quality: 50)
        try writer.verify(data: avif, expectedFormat: .avif, expectedDimensions: .init(width: largeWidth, height: largeHeight), targetBytes: nil)
        check(true, "native AVIF 48MP encode, signature, decode, and dimensions (\(avif.count) bytes)")
    }
} catch {
    failures += 1
    print("FAIL unexpected error: \(error)")
}

if failures > 0 {
    print("\(failures) core check(s) failed")
    exit(1)
}
print("All core checks passed")
