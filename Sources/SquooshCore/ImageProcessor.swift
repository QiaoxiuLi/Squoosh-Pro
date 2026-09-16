import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ImageDimensions: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct EncodedImageResult: Sendable {
    public let data: Data
    public let format: CodecFormat
    public let dimensions: ImageDimensions
    public let quality: Int

    public init(data: Data, format: CodecFormat, dimensions: ImageDimensions, quality: Int) {
        self.data = data
        self.format = format
        self.dimensions = dimensions
        self.quality = quality
    }
}

public struct DecodedImage {
    public let image: CGImage
    public let sourceDimensions: ImageDimensions
    public let hasAlpha: Bool
}

public struct ImageProcessor {
    public init() {}

    public func supportsNativeEncoding(_ format: CodecFormat) -> Bool {
        let identifier: String
        switch format {
        case .automatic, .mozjpeg: identifier = UTType.jpeg.identifier
        case .oxipng: identifier = UTType.png.identifier
        case .avif: identifier = "public.avif"
        case .webp: identifier = "org.webmproject.webp"
        }
        let destinations = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return destinations.contains(identifier)
    }

    public func inspect(url: URL) throws -> ImageDimensions {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let rawWidth = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let rawHeight = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            throw SquooshProError.decodeFailed
        }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        if [5, 6, 7, 8].contains(orientation) {
            return ImageDimensions(width: rawHeight.intValue, height: rawWidth.intValue)
        }
        return ImageDimensions(width: rawWidth.intValue, height: rawHeight.intValue)
    }

    public func decode(url: URL, resize: ResizeOptions, overrideWidth: Int? = nil, jpegBackground: String = "#FFFFFF", flattenAlpha: Bool = false) throws -> DecodedImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary), CGImageSourceGetCount(source) > 0 else {
            throw SquooshProError.corruptedInput
        }
        let sourceDimensions = try inspect(url: url)
        guard sourceDimensions.width > 0, sourceDimensions.height > 0,
              Int64(sourceDimensions.width) * Int64(sourceDimensions.height) <= 200_000_000 else {
            throw SquooshProError.decodeFailed
        }
        let target = targetDimensions(source: sourceDimensions, resize: resize, overrideWidth: overrideWidth)
        let maxPixel = max(sourceDimensions.width, sourceDimensions.height)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let oriented = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw SquooshProError.decodeFailed
        }
        let alphaInfo = oriented.alphaInfo
        let hasAlpha = alphaInfo == .premultipliedFirst || alphaInfo == .premultipliedLast || alphaInfo == .first || alphaInfo == .last || alphaInfo == .alphaOnly
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: target.width, height: target.height, bitsPerComponent: 8, bytesPerRow: target.width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw SquooshProError.decodeFailed
        }
        if flattenAlpha, let components = Self.rgbComponents(hex: jpegBackground) {
            context.setFillColor(red: components.0, green: components.1, blue: components.2, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: target.width, height: target.height))
        }
        context.interpolationQuality = .high
        context.draw(oriented, in: CGRect(x: 0, y: 0, width: target.width, height: target.height))
        guard let rendered = context.makeImage() else { throw SquooshProError.decodeFailed }
        return DecodedImage(image: rendered, sourceDimensions: sourceDimensions, hasAlpha: hasAlpha)
    }

    public func encode(url: URL, preset: CompressionPreset) throws -> EncodedImageResult {
        try PresetValidator.validate(preset)
        let metadata = try outputMetadata(url: url, policy: preset.metadata.policy)
        var format = preset.output.format
        if format == .automatic {
            let decoded = try decode(url: url, resize: preset.resize, jpegBackground: preset.alpha.jpegBackground)
            format = decoded.hasAlpha ? .oxipng : .mozjpeg
        }

        if preset.output.strategy == .targetBytes {
            guard format == .mozjpeg else { throw SquooshProError.invalidPreset("严格大小模式当前仅支持 JPEG") }
            let target = preset.output.targetBytes ?? 0
            let safety = min(preset.output.safetyTargetBytes ?? target, target)
            let widths = preset.resize.candidateWidths.isEmpty ? [preset.resize.width].compactMap { $0 } : preset.resize.candidateWidths
            let candidates = widths.isEmpty ? [try inspect(url: url).width] : widths
            for width in candidates {
                let decoded = try decode(url: url, resize: preset.resize, overrideWidth: width, jpegBackground: preset.alpha.jpegBackground, flattenAlpha: true)
                do {
                    let candidate = try TargetSizeSearch.highestQuality(
                        initialQuality: preset.output.quality,
                        minimumQuality: preset.output.minimumQuality,
                        targetBytes: safety,
                        maximumAttempts: preset.output.maximumSearchAttempts
                    ) { quality in
                        try encode(image: decoded.image, format: .mozjpeg, quality: quality, formatOptions: preset.formatOptions, metadata: metadata)
                    }
                    guard candidate.data.count <= target else { continue }
                    return EncodedImageResult(data: candidate.data, format: .mozjpeg, dimensions: .init(width: decoded.image.width, height: decoded.image.height), quality: candidate.quality)
                } catch SquooshProError.targetNotMet {
                    continue
                }
            }
            throw SquooshProError.targetNotMet
        }

        let decoded = try decode(url: url, resize: preset.resize, jpegBackground: preset.alpha.jpegBackground, flattenAlpha: format == .mozjpeg)
        let data = try encode(image: decoded.image, format: format, quality: preset.output.quality, formatOptions: preset.formatOptions, metadata: metadata)
        return EncodedImageResult(data: data, format: format, dimensions: .init(width: decoded.image.width, height: decoded.image.height), quality: preset.output.quality)
    }

    public func rgbaBytes(from image: CGImage) throws -> Data {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { throw SquooshProError.decodeFailed }
        var data = Data(count: image.width * image.height * 4)
        let created = data.withUnsafeMutableBytes { pointer -> Bool in
            guard let base = pointer.baseAddress,
                  let context = CGContext(data: base, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard created else { throw SquooshProError.decodeFailed }
        return data
    }

    public func encode(image: CGImage, format: CodecFormat, quality: Int, formatOptions: [String: Double] = [:], metadata: [CFString: Any] = [:]) throws -> Data {
        let typeIdentifier: String
        switch format {
        case .automatic, .mozjpeg: typeIdentifier = UTType.jpeg.identifier
        case .oxipng: typeIdentifier = UTType.png.identifier
        case .avif: typeIdentifier = "public.avif"
        case .webp: typeIdentifier = "org.webmproject.webp"
        }
        guard supportsNativeEncoding(format) else { throw SquooshProError.unsupportedFormat }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, typeIdentifier as CFString, 1, nil) else { throw SquooshProError.encodeFailed }
        var properties = metadata
        if format == .mozjpeg || format == .automatic || format == .avif || format == .webp {
            properties[kCGImageDestinationLossyCompressionQuality] = Double(max(0, min(100, quality))) / 100
        }
        if format == .mozjpeg || format == .automatic {
            if formatOptions["progressive"] == 1 {
                properties[kCGImagePropertyJFIFDictionary] = [kCGImagePropertyJFIFIsProgressive: true]
            }
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination), !output.isEmpty else { throw SquooshProError.encodeFailed }
        return output as Data
    }

    public func targetDimensions(source: ImageDimensions, resize: ResizeOptions, overrideWidth: Int? = nil) -> ImageDimensions {
        let ratio = Double(source.width) / Double(source.height)
        var width = source.width
        var height = source.height
        if let overrideWidth {
            width = overrideWidth
            height = max(1, Int((Double(width) / ratio).rounded()))
        } else {
            switch resize.mode {
            case .original: break
            case .fixedWidth:
                width = resize.width ?? source.width
                height = max(1, Int((Double(width) / ratio).rounded()))
            case .fixedHeight:
                height = resize.height ?? source.height
                width = max(1, Int((Double(height) * ratio).rounded()))
            case .longestEdge:
                let edge = resize.longestEdge ?? max(source.width, source.height)
                let scale = Double(edge) / Double(max(source.width, source.height))
                width = max(1, Int((Double(source.width) * scale).rounded()))
                height = max(1, Int((Double(source.height) * scale).rounded()))
            case .fitBox:
                let maxWidth = resize.width ?? source.width
                let maxHeight = resize.height ?? source.height
                let scale = min(Double(maxWidth) / Double(source.width), Double(maxHeight) / Double(source.height))
                width = max(1, Int((Double(source.width) * scale).rounded()))
                height = max(1, Int((Double(source.height) * scale).rounded()))
            case .adaptiveWidth:
                width = resize.candidateWidths.first ?? source.width
                height = max(1, Int((Double(width) / ratio).rounded()))
            }
        }
        if !resize.allowUpscale && (width > source.width || height > source.height) { return source }
        return ImageDimensions(width: width, height: height)
    }

    private static func rgbComponents(hex: String) -> (CGFloat, CGFloat, CGFloat)? {
        guard hex.count == 7, hex.first == "#", let value = Int(hex.dropFirst(), radix: 16) else { return nil }
        return (CGFloat((value >> 16) & 0xff) / 255, CGFloat((value >> 8) & 0xff) / 255, CGFloat(value & 0xff) / 255)
    }

    private func outputMetadata(url: URL, policy: MetadataPolicy) throws -> [CFString: Any] {
        guard policy != .stripAll,
              let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let raw = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return [:] }

        let filtered: [String: Any]
        switch policy {
        case .stripAll:
            return [:]
        case .stripPrivate:
            let allowed = ["ColorModel", "ProfileName", "DPIWidth", "DPIHeight", "Depth"]
            filtered = raw.filter { allowed.contains($0.key) }
        case .preserveSafe:
            filtered = scrubPrivateMetadata(raw)
        case .preserveAll:
            filtered = raw
        }
        var output = filtered.reduce(into: [CFString: Any]()) { result, entry in result[entry.key as CFString] = entry.value }
        output[kCGImagePropertyOrientation] = 1
        return output
    }

    private func scrubPrivateMetadata(_ dictionary: [String: Any]) -> [String: Any] {
        let blocked = ["gps", "location", "serial", "owner", "artist", "maker", "hostcomputer"]
        return dictionary.reduce(into: [String: Any]()) { result, entry in
            let lower = entry.key.lowercased()
            guard !blocked.contains(where: lower.contains) else { return }
            if let nested = entry.value as? [String: Any] { result[entry.key] = scrubPrivateMetadata(nested) }
            else if let nested = entry.value as? NSDictionary, let bridged = nested as? [String: Any] { result[entry.key] = scrubPrivateMetadata(bridged) }
            else { result[entry.key] = entry.value }
        }
    }
}
