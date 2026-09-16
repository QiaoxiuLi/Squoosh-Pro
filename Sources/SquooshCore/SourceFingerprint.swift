import CryptoKit
import Foundation

public struct SourceFingerprint: Codable, Equatable, Sendable {
    public let standardizedPath: String
    public let fileResourceIdentifier: String
    public let byteCount: Int64
    public let modificationDate: Date
    public let sha256: String

    public static func capture(url: URL) throws -> SourceFingerprint {
        let standardized = url.resolvingSymlinksInPath().standardizedFileURL
        let values = try standardized.resourceValues(forKeys: [.fileResourceIdentifierKey, .fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw SquooshProError.corruptedInput }
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: standardized) }
        catch { throw SquooshProError.permissionDenied }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return SourceFingerprint(
            standardizedPath: standardized.path,
            fileResourceIdentifier: values.fileResourceIdentifier.map { String(describing: $0) } ?? "unknown",
            byteCount: Int64(values.fileSize ?? 0),
            modificationDate: values.contentModificationDate ?? .distantPast,
            sha256: digest
        )
    }

    public func verifyUnchanged() throws {
        let current = try SourceFingerprint.capture(url: URL(fileURLWithPath: standardizedPath))
        guard current == self else { throw SquooshProError.sourceChanged }
    }
}
