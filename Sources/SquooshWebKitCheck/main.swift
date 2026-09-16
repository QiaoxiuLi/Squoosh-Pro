import AppKit
import Foundation
import SquooshCodecHost
import SquooshCore

@main
struct SquooshWebKitCheck {
    @MainActor
    static func main() async {
        _ = NSApplication.shared
        NSApplication.shared.setActivationPolicy(.prohibited)
        let host = SquooshWasmCodecHost()
        let writer = SafeOutputWriter()

        do {
            let capabilities = try await host.capabilities()
            guard Set(capabilities) == Set(["mozjpeg", "oxipng", "webp", "avif"]) else {
                throw SquooshProError.workerCrashed
            }
            print("PASS WKWebView loaded all four local codecs")

            guard try await host.networkIsolationProbe() else { throw SquooshProError.verifyFailed }
            print("PASS codec page CSP blocked external fetch")

            let width = 100
            let height = 100
            let rgba = fixture(width: width, height: height)
            for format in [CodecFormat.mozjpeg, .oxipng, .webp, .avif] {
                let requestID = UUID()
                let data = try await host.encodeRGBA(
                    rgba,
                    width: width,
                    height: height,
                    format: format,
                    options: options(for: format),
                    requestID: requestID
                )
                try writer.verify(data: data, expectedFormat: format, expectedDimensions: .init(width: width, height: height), targetBytes: nil)
                print("PASS WKWebView \(format.rawValue) encode, signature, decode, and dimensions")
            }

            let cancellationRequest = UUID()
            let large = fixture(width: 2400, height: 1800)
            let task = Task {
                try await host.encodeRGBA(
                    large,
                    width: 2400,
                    height: 1800,
                    format: .webp,
                    options: options(for: .webp),
                    requestID: cancellationRequest
                )
            }
            try await Task.sleep(nanoseconds: 20_000_000)
            task.cancel()
            await host.cancel(requestID: cancellationRequest)
            do {
                _ = try await task.value
                throw SquooshProError.verifyFailed
            } catch let error as SquooshProError where error == .cancelled {
                print("PASS in-progress codec call was interrupted")
            } catch {
                throw error
            }

            _ = try await host.capabilities()
            let rebuilt = try await host.encodeRGBA(
                rgba,
                width: width,
                height: height,
                format: .mozjpeg,
                options: options(for: .mozjpeg),
                requestID: UUID()
            )
            try writer.verify(data: rebuilt, expectedFormat: .mozjpeg, expectedDimensions: .init(width: width, height: height), targetBytes: nil)
            print("PASS codec host rebuilt after interruption and encoded again")
            await host.shutdown()
            print("All WKWebView checks passed")
        } catch {
            await host.shutdown()
            fputs("FAIL WKWebView check: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func fixture(width: Int, height: Int) -> Data {
        var data = Data(count: width * height * 4)
        data.withUnsafeMutableBytes { rawBuffer in
            guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * 4
                    bytes[offset] = UInt8((x * 255) / max(1, width - 1))
                    bytes[offset + 1] = UInt8((y * 255) / max(1, height - 1))
                    bytes[offset + 2] = UInt8((x + y) % 256)
                    bytes[offset + 3] = 255
                }
            }
        }
        return data
    }

    private static func options(for format: CodecFormat) -> [String: Double] {
        switch format {
        case .mozjpeg: return ["quality": 75, "progressive": 1, "optimizeCoding": 1]
        case .oxipng: return ["level": 2, "interlace": 0]
        case .webp: return ["quality": 78, "method": 4]
        case .avif: return ["quality": 50, "speed": 8]
        case .automatic: return [:]
        }
    }
}
