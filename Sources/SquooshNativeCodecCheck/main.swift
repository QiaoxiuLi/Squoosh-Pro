import CoreGraphics
import Foundation
import SquooshCore
import SquooshNativeCodecHost

@main
struct SquooshNativeCodecCheck {
    @MainActor
    static func main() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SquooshNativeCodecCheck-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let sourceURL = root.appendingPathComponent("48mp-source.png")
            try makeFixture().write(to: sourceURL, options: .atomic)
            let before = try SourceFingerprint.capture(url: sourceURL)
            let host = NativeAVIFCodecHost()

            let cancellationID = UUID()
            let cancelledTask = Task {
                try await host.encode(sourceURL: sourceURL, preset: .compactAVIF, requestID: cancellationID)
            }
            try await Task.sleep(nanoseconds: 20_000_000)
            cancelledTask.cancel()
            await host.cancel(requestID: cancellationID)
            do {
                _ = try await cancelledTask.value
                throw SquooshProError.verifyFailed
            } catch let error as SquooshProError where error == .cancelled {
                print("PASS native AVIF helper was interrupted without terminating the caller")
            } catch {
                throw error
            }

            let data = try await host.encode(sourceURL: sourceURL, preset: .compactAVIF, requestID: UUID())
            try SafeOutputWriter().verify(data: data, expectedFormat: .avif, expectedDimensions: .init(width: 8000, height: 6000), targetBytes: nil)
            try before.verifyUnchanged()
            print("PASS native AVIF helper 48MP encode, signature, decode, dimensions, and source preservation (\(data.count) bytes)")
            await host.shutdown()
            print("All native codec helper checks passed")
        } catch {
            fputs("FAIL native codec helper check: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func makeFixture() throws -> Data {
        let width = 8000
        let height = 6000
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw SquooshProError.decodeFailed
        }
        for stripe in 0..<120 {
            let fraction = CGFloat(stripe) / 119
            context.setFillColor(CGColor(red: fraction, green: 0.8 - fraction * 0.5, blue: 1 - fraction, alpha: 1))
            context.fill(CGRect(x: 0, y: stripe * 50, width: width, height: 50))
        }
        guard let image = context.makeImage() else { throw SquooshProError.decodeFailed }
        return try ImageProcessor().encode(image: image, format: .oxipng, quality: 100)
    }
}
