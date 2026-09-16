import Foundation

public struct TargetSizeCandidate: Equatable, Sendable {
    public let quality: Int
    public let byteCount: Int
    public let data: Data

    public init(quality: Int, data: Data) {
        self.quality = quality
        self.byteCount = data.count
        self.data = data
    }
}

public enum TargetSizeSearch {
    public static func highestQuality(initialQuality: Int, minimumQuality: Int, maximumQuality: Int = 100, targetBytes: Int, maximumAttempts: Int, encode: (Int) throws -> Data) throws -> TargetSizeCandidate {
        guard minimumQuality <= initialQuality, initialQuality <= maximumQuality, targetBytes > 0, maximumAttempts > 0 else { throw SquooshProError.invalidPreset("严格大小搜索参数无效") }
        var attempts = 0
        var visited = Set<Int>()
        var best: TargetSizeCandidate?

        func measure(_ quality: Int) throws -> TargetSizeCandidate? {
            guard attempts < maximumAttempts, !visited.contains(quality) else { return nil }
            visited.insert(quality)
            attempts += 1
            let candidate = TargetSizeCandidate(quality: quality, data: try encode(quality))
            if candidate.byteCount <= targetBytes, best == nil || quality > best!.quality { best = candidate }
            return candidate
        }

        let first = try measure(initialQuality)
        var low = minimumQuality
        var high = maximumQuality
        if let first {
            if first.byteCount > targetBytes { high = initialQuality - 1 }
            else { low = initialQuality + 1 }
        }
        while low <= high && attempts < maximumAttempts {
            let middle = low + (high - low) / 2
            guard let candidate = try measure(middle) else { break }
            if candidate.byteCount <= targetBytes { low = middle + 1 }
            else { high = middle - 1 }
        }
        if best == nil && attempts < maximumAttempts { _ = try measure(minimumQuality) }
        guard let best else { throw SquooshProError.targetNotMet }
        return best
    }
}
