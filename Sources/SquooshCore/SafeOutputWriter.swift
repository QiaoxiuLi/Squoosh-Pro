import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct SafeOutputWriter {
    public init() {}

    public func createTimestampedDirectory(parent: URL, date: Date = Date()) throws -> URL {
        let names = Set((try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? [])
        let name = PathSafety.timestampDirectoryName(date: date, existingNames: names)
        let directory = parent.appendingPathComponent(name, isDirectory: true)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false) }
        catch { throw SquooshProError.permissionDenied }
        return directory
    }

    public func nextOutputURL(directory: URL, sourceName: String, preset: CompressionPreset, format: CodecFormat) -> URL {
        PathSafety.uniqueOutputURL(directory: directory, sourceName: sourceName, suffix: preset.naming.suffix, extension: format.fileExtension) {
            FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
    }

    public func commit(_ result: EncodedImageResult, to finalURL: URL, sourceURLs: [URL], targetBytes: Int? = nil) throws {
        try PathSafety.ensureOutputDoesNotCollide(output: finalURL, inputs: sourceURLs)
        try verify(data: result.data, expectedFormat: result.format, expectedDimensions: result.dimensions, targetBytes: targetBytes)
        let tempName = ".\(finalURL.lastPathComponent).sqbtmp-\(UUID().uuidString)"
        let tempURL = finalURL.deletingLastPathComponent().appendingPathComponent(tempName)
        let descriptor = open(tempURL.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw errno == ENOSPC ? SquooshProError.diskFull : SquooshProError.permissionDenied }
        var shouldRemoveTemp = true
        defer {
            close(descriptor)
            if shouldRemoveTemp { try? FileManager.default.removeItem(at: tempURL) }
        }
        do {
            try result.data.withUnsafeBytes { rawBuffer in
                guard let base = rawBuffer.baseAddress else { return }
                var offset = 0
                while offset < rawBuffer.count {
                    let written = Darwin.write(descriptor, base.advanced(by: offset), rawBuffer.count - offset)
                    guard written > 0 else { throw errno == ENOSPC ? SquooshProError.diskFull : SquooshProError.permissionDenied }
                    offset += written
                }
            }
            guard fsync(descriptor) == 0 else { throw SquooshProError.permissionDenied }
            try verify(url: tempURL, expectedFormat: result.format, expectedDimensions: result.dimensions, targetBytes: targetBytes)
            guard link(tempURL.path, finalURL.path) == 0 else {
                throw errno == EEXIST ? SquooshProError.outputConflict : SquooshProError.permissionDenied
            }
            guard unlink(tempURL.path) == 0 else { throw SquooshProError.permissionDenied }
            shouldRemoveTemp = false
        } catch {
            throw error
        }
    }

    public func verify(data: Data, expectedFormat: CodecFormat, expectedDimensions: ImageDimensions, targetBytes: Int?) throws {
        if let targetBytes, data.count > targetBytes { throw SquooshProError.targetNotMet }
        guard matchesSignature(data: data, format: expectedFormat),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width == expectedDimensions.width,
              image.height == expectedDimensions.height else { throw SquooshProError.verifyFailed }
    }

    public func verify(url: URL, expectedFormat: CodecFormat, expectedDimensions: ImageDimensions, targetBytes: Int?) throws {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { throw SquooshProError.verifyFailed }
        try verify(data: data, expectedFormat: expectedFormat, expectedDimensions: expectedDimensions, targetBytes: targetBytes)
    }

    private func matchesSignature(data: Data, format: CodecFormat) -> Bool {
        let bytes = [UInt8](data.prefix(16))
        switch format {
        case .automatic, .mozjpeg: return bytes.count >= 3 && bytes[0...2] == [0xff, 0xd8, 0xff]
        case .oxipng: return bytes.count >= 8 && Array(bytes[0..<8]) == [137, 80, 78, 71, 13, 10, 26, 10]
        case .webp: return bytes.count >= 12 && String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF" && String(bytes: bytes[8..<12], encoding: .ascii) == "WEBP"
        case .avif: return bytes.count >= 12 && String(bytes: bytes[4..<8], encoding: .ascii) == "ftyp" && String(bytes: bytes[8..<12], encoding: .ascii)?.contains("avif") == true
        }
    }
}
