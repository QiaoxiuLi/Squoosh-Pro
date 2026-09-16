import Foundation

public enum CodecFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case mozjpeg
    case oxipng
    case webp
    case avif

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .automatic: return "自动"
        case .mozjpeg: return "JPEG"
        case .oxipng: return "PNG"
        case .webp: return "WebP"
        case .avif: return "AVIF"
        }
    }

    public var fileExtension: String {
        switch self {
        case .automatic, .mozjpeg: return "jpg"
        case .oxipng: return "png"
        case .webp: return "webp"
        case .avif: return "avif"
        }
    }
}

public enum CompressionStrategy: String, Codable, CaseIterable, Sendable {
    case fixedQuality
    case targetBytes
}

public enum ResizeMode: String, Codable, CaseIterable, Sendable {
    case original
    case longestEdge
    case fixedWidth
    case fixedHeight
    case fitBox
    case adaptiveWidth
}

public enum MetadataPolicy: String, Codable, CaseIterable, Sendable {
    case stripPrivate
    case stripAll
    case preserveSafe
    case preserveAll
}

public enum ConflictPolicy: String, Codable, CaseIterable, Sendable {
    case rename
    case skip
}

public struct OutputOptions: Codable, Equatable, Sendable {
    public var format: CodecFormat
    public var strategy: CompressionStrategy
    public var quality: Int
    public var targetBytes: Int?
    public var safetyTargetBytes: Int?
    public var minimumQuality: Int
    public var maximumSearchAttempts: Int

    public init(format: CodecFormat, strategy: CompressionStrategy, quality: Int, targetBytes: Int? = nil, safetyTargetBytes: Int? = nil, minimumQuality: Int = 35, maximumSearchAttempts: Int = 8) {
        self.format = format
        self.strategy = strategy
        self.quality = quality
        self.targetBytes = targetBytes
        self.safetyTargetBytes = safetyTargetBytes
        self.minimumQuality = minimumQuality
        self.maximumSearchAttempts = maximumSearchAttempts
    }
}

public struct ResizeOptions: Codable, Equatable, Sendable {
    public var mode: ResizeMode
    public var width: Int?
    public var height: Int?
    public var longestEdge: Int?
    public var candidateWidths: [Int]
    public var allowUpscale: Bool
    public var preserveAspectRatio: Bool

    public init(mode: ResizeMode = .original, width: Int? = nil, height: Int? = nil, longestEdge: Int? = nil, candidateWidths: [Int] = [], allowUpscale: Bool = false, preserveAspectRatio: Bool = true) {
        self.mode = mode
        self.width = width
        self.height = height
        self.longestEdge = longestEdge
        self.candidateWidths = candidateWidths
        self.allowUpscale = allowUpscale
        self.preserveAspectRatio = preserveAspectRatio
    }
}

public struct MetadataOptions: Codable, Equatable, Sendable {
    public var policy: MetadataPolicy
    public var preserveOrientation: Bool
    public var applyOrientationToPixels: Bool

    public init(policy: MetadataPolicy = .stripPrivate, preserveOrientation: Bool = false, applyOrientationToPixels: Bool = true) {
        self.policy = policy
        self.preserveOrientation = preserveOrientation
        self.applyOrientationToPixels = applyOrientationToPixels
    }
}

public struct ColorOptions: Codable, Equatable, Sendable {
    public var outputColorSpace: String
    public init(outputColorSpace: String = "sRGB") { self.outputColorSpace = outputColorSpace }
}

public struct AlphaOptions: Codable, Equatable, Sendable {
    public var jpegBackground: String
    public init(jpegBackground: String = "#FFFFFF") { self.jpegBackground = jpegBackground }
}

public struct NamingOptions: Codable, Equatable, Sendable {
    public var suffix: String
    public var conflictPolicy: ConflictPolicy
    public init(suffix: String = "", conflictPolicy: ConflictPolicy = .rename) {
        self.suffix = suffix
        self.conflictPolicy = conflictPolicy
    }
}

public struct CompressionPreset: Codable, Equatable, Identifiable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var notes: String?
    public var kind: String
    public var output: OutputOptions
    public var resize: ResizeOptions
    public var metadata: MetadataOptions
    public var color: ColorOptions
    public var alpha: AlphaOptions
    public var naming: NamingOptions
    public var formatOptions: [String: Double]

    public init(schemaVersion: Int = 1, id: String, name: String, notes: String? = nil, kind: String = "user", output: OutputOptions, resize: ResizeOptions, metadata: MetadataOptions = .init(), color: ColorOptions = .init(), alpha: AlphaOptions = .init(), naming: NamingOptions = .init(), formatOptions: [String: Double] = [:]) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.notes = notes
        self.kind = kind
        self.output = output
        self.resize = resize
        self.metadata = metadata
        self.color = color
        self.alpha = alpha
        self.naming = naming
        self.formatOptions = formatOptions
    }
}

public extension CompressionPreset {
    static let smart = CompressionPreset(id: "system.smart", name: "智能推荐", kind: "system", output: .init(format: .automatic, strategy: .fixedQuality, quality: 78), resize: .init(mode: .longestEdge, longestEdge: 1920))

    static let websiteJPEG = CompressionPreset(id: "system.website-jpeg", name: "JPEG（JPG）", kind: "system", output: .init(format: .mozjpeg, strategy: .fixedQuality, quality: 75), resize: .init(mode: .longestEdge, longestEdge: 1920), formatOptions: ["progressive": 1, "optimizeCoding": 1, "arithmetic": 0])

    static let webJPEG150KB = CompressionPreset(id: "system.web-jpeg-150kb", name: "网页 JPEG ≤150KB", kind: "system", output: .init(format: .mozjpeg, strategy: .targetBytes, quality: 75, targetBytes: 150_000, safetyTargetBytes: 145_000, minimumQuality: 35, maximumSearchAttempts: 8), resize: .init(mode: .adaptiveWidth, candidateWidths: [1000, 960, 920]), formatOptions: ["progressive": 1, "optimizeCoding": 1, "arithmetic": 0])

    static let losslessPNG = CompressionPreset(id: "system.lossless-png", name: "无损 PNG", kind: "system", output: .init(format: .oxipng, strategy: .fixedQuality, quality: 100), resize: .init(mode: .original), formatOptions: ["level": 2, "interlace": 0])

    static let modernWebP = CompressionPreset(id: "system.modern-webp", name: "现代网站 WebP", kind: "system", output: .init(format: .webp, strategy: .fixedQuality, quality: 78), resize: .init(mode: .original), formatOptions: ["method": 4, "alphaQuality": 100])

    static let compactAVIF = CompressionPreset(id: "system.compact-avif", name: "极致压缩 AVIF", kind: "system", output: .init(format: .avif, strategy: .fixedQuality, quality: 50), resize: .init(mode: .original), formatOptions: ["speed": 6, "alphaQuality": 50])

    static let builtIns: [CompressionPreset] = [smart, websiteJPEG, webJPEG150KB, losslessPNG, modernWebP, compactAVIF]
}

public enum FileState: String, Codable, Sendable {
    case queued, reading, decoding, transforming, encoding, verifying, committing, completed, failed, cancelled
}

public enum JobState: String, Codable, Sendable {
    case draft, ready, running, pausing, paused, cancelling, cancelled, completed, completedWithErrors, failed
}

public struct JobItemRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var sourceFileName: String
    public var state: FileState
    public var outputFileName: String?
    public var inputBytes: Int64
    public var outputBytes: Int64?
    public var errorCode: String?
    public var errorMessage: String?

    public init(id: UUID = UUID(), sourceFileName: String, state: FileState = .queued, inputBytes: Int64 = 0) {
        self.id = id
        self.sourceFileName = sourceFileName
        self.state = state
        self.inputBytes = inputBytes
    }
}

public struct JobManifest: Codable, Identifiable, Sendable {
    public var schemaVersion: Int
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var state: JobState
    public var preset: CompressionPreset
    public var upstreamCommit: String
    public var appVersion: String
    public var outputDirectoryName: String
    public var items: [JobItemRecord]

    public init(id: UUID = UUID(), preset: CompressionPreset, outputDirectoryName: String, items: [JobItemRecord]) {
        self.schemaVersion = 1
        self.id = id
        self.createdAt = Date()
        self.updatedAt = Date()
        self.state = .ready
        self.preset = preset
        self.upstreamCommit = "e8d35e0fb66eb16eff6fe8fc773eabcbb7128de3"
        self.appVersion = "0.1.0"
        self.outputDirectoryName = outputDirectoryName
        self.items = items
    }
}

public enum SquooshProError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedFormat, corruptedInput, decodeFailed, sourceChanged, permissionDenied, diskFull, outputConflict, encodeFailed, verifyFailed, targetNotMet, workerCrashed, cancelled, unsafePath
    case invalidPreset(String)
    case unknown(String)

    public var code: String {
        switch self {
        case .unsupportedFormat: return "unsupportedFormat"
        case .corruptedInput: return "corruptedInput"
        case .decodeFailed: return "decodeFailed"
        case .sourceChanged: return "sourceChanged"
        case .permissionDenied: return "permissionDenied"
        case .diskFull: return "diskFull"
        case .outputConflict: return "outputConflict"
        case .encodeFailed: return "encodeFailed"
        case .verifyFailed: return "verifyFailed"
        case .targetNotMet: return "targetNotMet"
        case .workerCrashed: return "workerCrashed"
        case .cancelled: return "cancelled"
        case .invalidPreset: return "invalidPreset"
        case .unsafePath: return "unsafePath"
        case .unknown: return "unknown"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "不支持这种图片格式"
        case .corruptedInput: return "图片文件不完整或已损坏"
        case .decodeFailed: return "无法读取图片内容"
        case .sourceChanged: return "图片在处理过程中被其他程序修改"
        case .permissionDenied: return "没有读取或写入权限"
        case .diskFull: return "磁盘空间不足"
        case .outputConflict: return "输出位置已经存在同名文件"
        case .encodeFailed: return "压缩器无法处理这张图片"
        case .verifyFailed: return "输出验证失败，未保存损坏文件"
        case .targetNotMet: return "在当前最低质量和尺寸下无法达到目标大小"
        case .workerCrashed: return "压缩组件意外停止，已保护原图"
        case .cancelled: return "已取消"
        case .invalidPreset(let detail): return "预设无效：\(detail)"
        case .unsafePath: return "输出路径不安全"
        case .unknown(let detail): return "出现未预期错误：\(detail)"
        }
    }
}
