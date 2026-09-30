import AppKit
import Foundation
import ImageIO

guard (2...4).contains(CommandLine.arguments.count) else {
    FileHandle.standardError.write(Data("Usage: swift check-app-icon.swift <project-root> [app-bundle] [pid]\n".utf8))
    exit(2)
}
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let icons = root.appendingPathComponent("assets/icons")
func require(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAIL \(message)\n".utf8))
        exit(1)
    }
    print("PASS \(message)")
}
func imageSource(_ url: URL) -> CGImageSource {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { fatalError("Cannot decode \(url.path)") }
    return source
}

let png = imageSource(icons.appendingPathComponent("SquooshPro.png"))
let master = CGImageSourceCreateImageAtIndex(png, 0, nil)!
require(master.width == 1024 && master.height == 1024, "1024-pixel master")
require(master.alphaInfo != .none && master.alphaInfo != .noneSkipFirst && master.alphaInfo != .noneSkipLast, "Master preserves transparency")
let icnsURL = icons.appendingPathComponent("SquooshPro.icns")
let icns = imageSource(icnsURL)
let sizes = Set((0..<CGImageSourceGetCount(icns)).map { CGImageSourceCreateImageAtIndex(icns, $0, nil)!.width })
require(Set([16, 32, 64, 128, 256, 512, 1024]).isSubset(of: sizes), "ICNS contains small and Retina representations")

let ico = try Data(contentsOf: icons.appendingPathComponent("SquooshPro.ico"))
func integer(_ offset: Int, _ length: Int) -> Int {
    (0..<length).reduce(0) { $0 | (Int(ico[offset + $1]) << ($1 * 8)) }
}
require(integer(0, 2) == 0 && integer(2, 2) == 1 && integer(4, 2) == 9, "ICO has nine image frames")
var icoSizes = Set<Int>()
for index in 0..<9 {
    let entry = 6 + index * 16
    let size = ico[entry] == 0 ? 256 : Int(ico[entry])
    let length = integer(entry + 8, 4), offset = integer(entry + 12, 4)
    require(offset >= 150 && offset + length <= ico.count, "ICO frame \(size) bounds")
    let data = ico.subdata(in: offset..<(offset + length))
    let source = CGImageSourceCreateWithData(data as CFData, nil)!
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    require(image.width == size && image.height == size, "ICO frame \(size) decodes")
    icoSizes.insert(size)
}
require(icoSizes == Set([16, 20, 24, 32, 40, 48, 64, 128, 256]), "ICO covers common Windows icon scales")

func pixels(_ image: NSImage) -> [UInt8] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 256, bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: 0, y: 0, width: 64, height: 64), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return Array(UnsafeBufferPointer(start: bitmap.bitmapData!, count: 64 * 64 * 4))
}
let expected = pixels(NSImage(contentsOf: icnsURL)!)
func fingerprint(_ values: [UInt8]) -> [UInt8] {
    // macOS adds its own icon inset. Compare the artwork, not that system padding.
    let columns = (0..<64).filter { x in (0..<64).filter { values[($0 * 64 + x) * 4 + 3] > 128 }.count >= 4 }
    let rows = (0..<64).filter { y in (0..<64).filter { values[(y * 64 + $0) * 4 + 3] > 128 }.count >= 4 }
    guard let left = columns.first, let right = columns.last, let top = rows.first, let bottom = rows.last else { return [] }
    return (0..<48).flatMap { y in
        (0..<48).flatMap { x -> [UInt8] in
            let px = left + x * (right - left) / 47, py = top + y * (bottom - top) / 47
            let offset = (py * 64 + px) * 4
            return Array(values[offset..<(offset + 4)])
        }
    }
}
func artworkDifference(_ actual: [UInt8]) -> Double {
    let a = fingerprint(actual), b = fingerprint(expected)
    guard !a.isEmpty && a.count == b.count else { return 1 }
    return zip(a, b).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(a.count * 255)
}
require(artworkDifference(pixels(NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app"))) > 0.12, "Icon comparison rejects an unrelated application")
func checkResolved(_ image: NSImage, _ name: String) {
    let actual = pixels(image)
    let difference = artworkDifference(actual)
    let directory = root.appendingPathComponent("Artifacts/IconValidation", isDirectory: true)
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for (label, values) in [("resolved", actual), ("expected", expected)] {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 256, bitsPerPixel: 32)!
        values.withUnsafeBufferPointer { bitmap.bitmapData!.update(from: $0.baseAddress!, count: values.count) }
        try! bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("\(label).png"))
    }
    require(difference < 0.06, "\(name) resolves the branded icon (difference \(difference))")
}
if CommandLine.arguments.count > 2 {
    let appURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    let bundle = Bundle(url: appURL)!
    require(bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String == "SquooshPro.icns", "Application registers its ICNS")
    let bundled = try Data(contentsOf: appURL.appendingPathComponent("Contents/Resources/SquooshPro.icns"))
    let original = try Data(contentsOf: icnsURL)
    require(bundled == original, "Application contains the exact icon asset")
    checkResolved(NSWorkspace.shared.icon(forFile: appURL.path), "macOS file-system icon")
}
if CommandLine.arguments.count > 3, let pid = Int32(CommandLine.arguments[3]) {
    guard let icon = NSRunningApplication(processIdentifier: pid)?.icon else { fatalError("Running app icon unavailable") }
    checkResolved(icon, "Running application / Dock icon")
}
