import Foundation
public struct RecoverableSource {
    public let id: UUID
    public let url: URL
    public let securityScopedBookmark: Data?

    public init(id: UUID, url: URL, securityScopedBookmark: Data?) {
        self.id = id
        self.url = url
        self.securityScopedBookmark = securityScopedBookmark
    }
}

public struct RecoveryItemRecord: Codable, Identifiable {
    public let id: UUID
    public var sourceBookmark: Data
    public var fallbackPath: String
    public var fingerprint: SourceFingerprint?
    public var state: FileState
}

public struct JobRecoveryRecord: Codable, Identifiable {
    public let schemaVersion: Int
    public let id: UUID
    public let createdAt: Date
    public var updatedAt: Date
    public var outputDirectoryBookmark: Data
    public var outputDirectoryFallbackPath: String
    public var preset: CompressionPreset
    public var items: [RecoveryItemRecord]

    init(id: UUID, outputDirectoryBookmark: Data, outputDirectory: URL, preset: CompressionPreset, items: [RecoveryItemRecord]) {
        schemaVersion = 1
        self.id = id
        createdAt = Date()
        updatedAt = Date()
        self.outputDirectoryBookmark = outputDirectoryBookmark
        outputDirectoryFallbackPath = outputDirectory.path
        self.preset = preset
        self.items = items
    }
}

public struct ResolvedRecoveryJob {
    public let record: JobRecoveryRecord
    public let outputDirectory: URL
    public let sourceURLs: [UUID: URL]
    public let access: SecurityScopeAccess
}

public final class SecurityScopeAccess {
    private var accessedURLs: [URL] = []

    public init() {}

    public func start(_ url: URL) {
        if url.startAccessingSecurityScopedResource() { accessedURLs.append(url) }
    }

    public func stop() {
        for url in accessedURLs.reversed() { url.stopAccessingSecurityScopedResource() }
        accessedURLs.removeAll()
    }

    deinit { stop() }
}

public struct SecurityScopedRecoveryStore {
    public let store: AtomicJSONStore

    public init(store: AtomicJSONStore) {
        self.store = store
    }

    public func bookmark(for url: URL, readOnly: Bool) throws -> Data {
        var options: URL.BookmarkCreationOptions = [.withSecurityScope]
        if readOnly { options.insert(.securityScopeAllowOnlyReadAccess) }
        return try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    public func makeRecord(jobID: UUID, outputDirectory: URL, preset: CompressionPreset, sources: [RecoverableSource]) throws -> JobRecoveryRecord {
        let outputBookmark = try bookmark(for: outputDirectory, readOnly: false)
        let recoveryItems = try sources.map { source in
            let sourceBookmark = try source.securityScopedBookmark ?? bookmark(for: source.url, readOnly: true)
            return RecoveryItemRecord(id: source.id, sourceBookmark: sourceBookmark, fallbackPath: source.url.path, fingerprint: nil, state: .queued)
        }
        return JobRecoveryRecord(id: jobID, outputDirectoryBookmark: outputBookmark, outputDirectory: outputDirectory, preset: preset, items: recoveryItems)
    }

    public func save(_ record: JobRecoveryRecord) throws {
        var copy = record
        copy.updatedAt = Date()
        try store.save(copy, relativePath: relativePath(record.id))
    }

    public func remove(jobID: UUID) throws {
        let url = store.root.appendingPathComponent(relativePath(jobID))
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    public func records() -> [JobRecoveryRecord] {
        let directory = store.root.appendingPathComponent("Recovery", isDirectory: true)
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(JobRecoveryRecord.self, from: data)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func resolve(_ record: JobRecoveryRecord) throws -> ResolvedRecoveryJob {
        let access = SecurityScopeAccess()
        var refreshed = record
        var needsSave = false
        let output = try resolveBookmark(record.outputDirectoryBookmark, fallbackPath: record.outputDirectoryFallbackPath)
        access.start(output.url)
        if output.stale {
            refreshed.outputDirectoryBookmark = try bookmark(for: output.url, readOnly: false)
            refreshed.outputDirectoryFallbackPath = output.url.path
            needsSave = true
        }

        var sources: [UUID: URL] = [:]
        for index in refreshed.items.indices {
            let item = refreshed.items[index]
            let resolved = try resolveBookmark(item.sourceBookmark, fallbackPath: item.fallbackPath)
            access.start(resolved.url)
            sources[item.id] = resolved.url
            if resolved.stale {
                refreshed.items[index].sourceBookmark = try bookmark(for: resolved.url, readOnly: true)
                refreshed.items[index].fallbackPath = resolved.url.path
                needsSave = true
            }
        }
        if needsSave { try save(refreshed) }
        return ResolvedRecoveryJob(record: refreshed, outputDirectory: output.url, sourceURLs: sources, access: access)
    }

    private func resolveBookmark(_ data: Data, fallbackPath: String) throws -> (url: URL, stale: Bool) {
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            return (url.resolvingSymlinksInPath().standardizedFileURL, stale)
        } catch {
            let fallback = URL(fileURLWithPath: fallbackPath).resolvingSymlinksInPath().standardizedFileURL
            guard FileManager.default.fileExists(atPath: fallback.path) else { throw SquooshProError.permissionDenied }
            return (fallback, true)
        }
    }

    private func relativePath(_ jobID: UUID) -> String {
        "Recovery/\(jobID.uuidString.lowercased()).json"
    }
}
