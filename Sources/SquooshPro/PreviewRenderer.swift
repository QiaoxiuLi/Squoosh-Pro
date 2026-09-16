import AppKit
import CoreImage
import ImageIO
import Metal

final class PreviewRenderer: @unchecked Sendable {
    let usesHardwareAcceleration: Bool

    private let context: CIContext
    private let maximumPixelSize = 2_560

    init(requestHardwareAcceleration: Bool) {
        if requestHardwareAcceleration, let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(
                mtlDevice: device,
                options: [
                    .cacheIntermediates: false,
                    .priorityRequestLow: false,
                ]
            )
            usesHardwareAcceleration = true
        } else {
            context = CIContext(options: [
                .useSoftwareRenderer: true,
                .cacheIntermediates: false,
            ])
            usesHardwareAcceleration = false
        }
    }

    func render(url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else {
            throw PreviewRendererError.unreadableImage
        }
        return try render(source: source)
    }

    func render(data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else {
            throw PreviewRendererError.unreadableImage
        }
        return try render(source: source)
    }

    private func render(source: CGImageSource) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PreviewRendererError.unreadableImage
        }

        let image = CIImage(cgImage: thumbnail)
        guard let rendered = context.createCGImage(image, from: image.extent) else {
            throw PreviewRendererError.renderFailed
        }
        return rendered
    }
}

private enum PreviewRendererError: LocalizedError {
    case unreadableImage
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "无法读取图片预览"
        case .renderFailed: return "无法显示图片预览"
        }
    }
}
