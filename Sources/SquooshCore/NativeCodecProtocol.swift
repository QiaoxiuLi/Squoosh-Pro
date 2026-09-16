import Foundation

public struct NativeCodecWorkerRequest: Codable, Sendable {
    public let sourcePath: String
    public let preset: CompressionPreset

    public init(sourcePath: String, preset: CompressionPreset) {
        self.sourcePath = sourcePath
        self.preset = preset
    }
}
