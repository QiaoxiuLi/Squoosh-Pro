import Foundation

public enum PathSafety {
    public static func sanitizedFileStem(_ value: String) -> String {
        let normalized = value.precomposedStringWithCanonicalMapping
        let invalid = CharacterSet(charactersIn: "/:\0").union(.newlines).union(.controlCharacters)
        let cleaned = normalized.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "." || trimmed == ".." { return "image" }
        return String(trimmed.prefix(180))
    }

    public static func timestampDirectoryName(date: Date = Date(), existingNames: Set<String> = []) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let base = "result_\(formatter.string(from: date))"
        if !existingNames.contains(base) { return base }
        var index = 2
        while existingNames.contains("\(base)-\(index)") { index += 1 }
        return "\(base)-\(index)"
    }

    public static func uniqueOutputURL(directory: URL, sourceName: String, suffix: String, extension fileExtension: String, fileExists: (String) -> Bool) -> URL {
        let stem = sanitizedFileStem((sourceName as NSString).deletingPathExtension) + suffix
        var name = "\(stem).\(fileExtension)"
        var index = 1
        while fileExists(name) {
            name = "\(stem)-\(index).\(fileExtension)"
            index += 1
        }
        return directory.appendingPathComponent(name, isDirectory: false)
    }

    public static func pathsCollide(_ first: URL, _ second: URL) -> Bool {
        first.resolvingSymlinksInPath().standardizedFileURL == second.resolvingSymlinksInPath().standardizedFileURL
    }

    public static func ensureOutputDoesNotCollide(output: URL, inputs: [URL]) throws {
        let resolved = output.resolvingSymlinksInPath().standardizedFileURL
        if inputs.contains(where: { pathsCollide(resolved, $0) }) { throw SquooshProError.unsafePath }
        guard !resolved.path.contains("/../"), resolved.lastPathComponent != ".." else { throw SquooshProError.unsafePath }
    }
}
