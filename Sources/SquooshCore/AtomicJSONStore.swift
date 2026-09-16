import Foundation

public struct AtomicJSONStore {
    public let root: URL

    public init(bundleIdentifier: String = "com.qiaoxiuli.squoosh-pro") throws {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { throw SquooshProError.permissionDenied }
        root = support.appendingPathComponent(bundleIdentifier, isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Presets", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Jobs", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Recovery", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Logs", isDirectory: true), withIntermediateDirectories: true)
    }

    public func save<T: Encodable>(_ value: T, relativePath: String) throws {
        guard !relativePath.hasPrefix("/"), !relativePath.contains("..") else { throw SquooshProError.unsafePath }
        let destination = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")
        try data.write(to: temporary, options: .withoutOverwriting)
        defer { try? FileManager.default.removeItem(at: temporary) }
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
    }

    public func load<T: Decodable>(_ type: T.Type, relativePath: String) throws -> T {
        guard !relativePath.hasPrefix("/"), !relativePath.contains("..") else { throw SquooshProError.unsafePath }
        let data = try Data(contentsOf: root.appendingPathComponent(relativePath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    public func jobManifests() -> [JobManifest] {
        let jobs = root.appendingPathComponent("Jobs", isDirectory: true)
        let urls = (try? FileManager.default.contentsOfDirectory(at: jobs, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(JobManifest.self, from: data)
        }.sorted { $0.createdAt > $1.createdAt }
    }
}
