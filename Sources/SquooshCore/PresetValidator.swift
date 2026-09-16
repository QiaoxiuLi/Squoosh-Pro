import Foundation

public enum PresetValidator {
    public static func validate(_ preset: CompressionPreset) throws {
        guard preset.schemaVersion == 1 else { throw SquooshProError.invalidPreset("不支持的 schemaVersion") }
        guard !preset.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SquooshProError.invalidPreset("ID 和名称不能为空")
        }
        guard (0...100).contains(preset.output.quality) else {
            throw SquooshProError.invalidPreset("质量必须在 0 到 100 之间")
        }
        guard (1...16).contains(preset.output.maximumSearchAttempts) else { throw SquooshProError.invalidPreset("搜索次数必须为 1...16") }
        if preset.output.strategy == .targetBytes {
            guard (0...100).contains(preset.output.minimumQuality) else {
                throw SquooshProError.invalidPreset("最低质量必须在 0 到 100 之间")
            }
            guard preset.output.minimumQuality <= preset.output.quality else {
                throw SquooshProError.invalidPreset("最低质量不能高于初始质量")
            }
            guard let target = preset.output.targetBytes, target > 0 else { throw SquooshProError.invalidPreset("严格大小模式需要正数 targetBytes") }
            let safety = preset.output.safetyTargetBytes ?? target
            guard safety > 0, safety <= target else { throw SquooshProError.invalidPreset("safetyTargetBytes 必须大于 0 且不超过 targetBytes") }
        }
        for value in preset.resize.candidateWidths {
            guard value > 0 && value <= 100_000 else { throw SquooshProError.invalidPreset("候选宽度超出安全范围") }
        }
        if let width = preset.resize.width, width <= 0 { throw SquooshProError.invalidPreset("宽度必须大于 0") }
        if let height = preset.resize.height, height <= 0 { throw SquooshProError.invalidPreset("高度必须大于 0") }
        if let edge = preset.resize.longestEdge, edge <= 0 { throw SquooshProError.invalidPreset("最长边必须大于 0") }
        guard preset.alpha.jpegBackground.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil else { throw SquooshProError.invalidPreset("JPEG 背景颜色必须是 #RRGGBB") }
    }

    public static func decode(_ data: Data) throws -> CompressionPreset {
        do {
            let preset = try JSONDecoder().decode(CompressionPreset.self, from: data)
            try validate(preset)
            return preset
        } catch let error as SquooshProError {
            throw error
        } catch {
            throw SquooshProError.invalidPreset(error.localizedDescription)
        }
    }

    public static func encode(_ preset: CompressionPreset) throws -> Data {
        try validate(preset)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(preset)
    }
}
