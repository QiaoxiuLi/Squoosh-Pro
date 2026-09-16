import Foundation

public enum FileDiscovery {
    public static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "avif", "heic", "heif"]

    public static func discover(_ urls: [URL], recursive: Bool) -> [URL] {
        var found: [URL] = []
        var seen = Set<String>()
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]

        func appendFile(_ url: URL) {
            let resolved = url.resolvingSymlinksInPath().standardizedFileURL
            let key = resolved.path
            guard supportedExtensions.contains(resolved.pathExtension.lowercased()), !seen.contains(key) else { return }
            guard let values = try? resolved.resourceValues(forKeys: keys), values.isRegularFile == true else { return }
            seen.insert(key)
            found.append(resolved)
        }

        for url in urls {
            let values = try? url.resourceValues(forKeys: keys)
            if values?.isRegularFile == true {
                appendFile(url)
            } else if values?.isDirectory == true {
                let options: FileManager.DirectoryEnumerationOptions = recursive ? [.skipsHiddenFiles, .skipsPackageDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
                let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: options)
                while let candidate = enumerator?.nextObject() as? URL { appendFile(candidate) }
            }
        }
        return found.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
