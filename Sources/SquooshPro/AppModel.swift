import AppKit
import CoreGraphics
import Foundation
import ImageIO
import OSLog
import SquooshCodecHost
import SquooshCore
import SquooshNativeCodecHost
import UniformTypeIdentifiers

enum SidebarSection: String, CaseIterable, Identifiable {
    case compress = "压缩"
    case presets = "预设"
    case history = "历史记录"
    case settings = "设置"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .compress: return "square.stack.3d.up"
        case .presets: return "slider.horizontal.3"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

struct ImageQueueItem: Identifiable {
    let id: UUID
    let url: URL
    let securityScopedBookmark: Data?
    var state: FileState
    var thumbnail: NSImage?
    var outputURL: URL?
    var outputBytes: Int?
    var errorMessage: String?

    init(id: UUID = UUID(), url: URL, securityScopedBookmark: Data? = nil) {
        self.id = id
        self.url = url
        self.securityScopedBookmark = securityScopedBookmark
        state = .queued
    }
}

private struct ResumeContext {
    var manifest: JobManifest
    var recovery: JobRecoveryRecord
    let outputDirectory: URL
    let access: SecurityScopeAccess
}

private struct PreviewCacheEntry {
    let result: EncodedImageResult
    let fingerprint: SourceFingerprint
    let preset: CompressionPreset
    var lastAccess: Date
}

private struct PreviewResultCache {
    private(set) var entries: [UUID: PreviewCacheEntry] = [:]
    private let maximumEntryCount = 24
    private let maximumByteCount = 128 * 1_000_000

    var itemIDs: Set<UUID> { Set(entries.keys) }

    mutating func result(
        for itemID: UUID,
        preset: CompressionPreset,
        fingerprint: SourceFingerprint
    ) -> EncodedImageResult? {
        guard var entry = entries[itemID], entry.preset == preset, entry.fingerprint == fingerprint else {
            entries.removeValue(forKey: itemID)
            return nil
        }
        entry.lastAccess = Date()
        entries[itemID] = entry
        return entry.result
    }

    mutating func insert(
        _ result: EncodedImageResult,
        for itemID: UUID,
        preset: CompressionPreset,
        fingerprint: SourceFingerprint
    ) {
        guard result.data.count <= maximumByteCount else { return }
        entries[itemID] = PreviewCacheEntry(result: result, fingerprint: fingerprint, preset: preset, lastAccess: Date())
        trimIfNeeded()
    }

    mutating func remove(for itemID: UUID) {
        entries.removeValue(forKey: itemID)
    }

    mutating func removeAll() {
        entries.removeAll(keepingCapacity: false)
    }

    private mutating func trimIfNeeded() {
        while entries.count > maximumEntryCount || entries.values.reduce(0, { $0 + $1.result.data.count }) > maximumByteCount {
            guard let oldest = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key else { return }
            entries.removeValue(forKey: oldest)
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    private let logger = Logger(subsystem: "com.qiaoxiuli.squoosh-pro", category: "AppModel")

    @Published var section: SidebarSection? = .compress
    @Published var items: [ImageQueueItem] = []
    @Published var selectedItemID: UUID?
    @Published var selectedPreset = CompressionPreset.webJPEG150KB
    @Published var userPresets: [CompressionPreset] = []
    @Published var history: [JobManifest] = []
    @Published var sourcePreview: NSImage?
    @Published var outputPreview: NSImage?
    @Published var previewBytes: Int?
    @Published var previewDimensions: ImageDimensions?
    @Published var previewQuality: Int?
    @Published var previewError: String?
    @Published var isPreviewing = false
    @Published var recursiveFolders = true
    @Published var showAdvanced = false
    @Published var outputParent: URL?
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var cancelRequested = false
    @Published var completedCount = 0
    @Published var failedCount = 0
    @Published var currentOutputDirectory: URL?
    @Published var workerStatus = "正在准备图片编码器"
    @Published var recoveredJobCount = 0
    @Published var recoveryMessage: String?
    @Published private(set) var cachedItemIDs: Set<UUID> = []
    @Published private(set) var hardwareAccelerationEnabled: Bool
    @Published private(set) var hardwareAccelerationStatus: String

    let systemPresets = CompressionPreset.builtIns
    private let processor = ImageProcessor()
    private let writer = SafeOutputWriter()
    private let codecHost = SquooshWasmCodecHost()
    private let nativeCodecHost = NativeAVIFCodecHost()
    private let coordinator = JobCoordinator()
    private var previewTask: Task<Void, Never>?
    private var batchTask: Task<Void, Never>?
    private var currentWorkerRequest: UUID?
    private var store: AtomicJSONStore?
    private var recoveryStore: SecurityScopedRecoveryStore?
    private var outputParentBookmark: Data?
    private var previewCache = PreviewResultCache()
    private var previewRenderer: PreviewRenderer
    private var startupGuardTask: Task<Void, Never>?

    private static let hardwareAccelerationPreferenceKey = "preview.hardwareAccelerationEnabled"
    private static let hardwareAccelerationStartupMarkerKey = "preview.hardwareAccelerationStartupInProgress"

    init() {
        let acceleration = Self.makeStartupPreviewRenderer()
        hardwareAccelerationEnabled = acceleration.enabled
        hardwareAccelerationStatus = acceleration.status
        previewRenderer = acceleration.renderer
        store = try? AtomicJSONStore()
        if let store { recoveryStore = SecurityScopedRecoveryStore(store: store) }
        reloadPersistence()
        if acceleration.enabled { armHardwareAccelerationStartupGuard() }
        Task {
            do {
                let codecs = try await codecHost.capabilities()
                workerStatus = codecs.isEmpty ? "部分图片格式暂不可用" : "所有图片格式均可使用"
            } catch {
                logger.error("Failed to initialize bundled codecs: \(error.localizedDescription, privacy: .public)")
                workerStatus = "JPEG 和 PNG 可用，部分现代格式暂不可用"
            }
        }
    }

    var selectedItem: ImageQueueItem? { items.first { $0.id == selectedItemID } }
    var totalInputBytes: Int64 {
        items.reduce(0) { value, item in value + Int64((try? item.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
    var totalOutputBytes: Int64 { items.reduce(0) { $0 + Int64($1.outputBytes ?? 0) } }
    var progress: Double { items.isEmpty ? 0 : Double(completedCount + failedCount) / Double(items.count) }

    func selectPreset(_ preset: CompressionPreset) {
        guard !isRunning else { return }
        selectedPreset = preset
        settingsDidChange()
    }

    func chooseImages() {
        let panel = NSOpenPanel()
        panel.title = "选择图片"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK { addURLs(panel.urls) }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择图片文件夹"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK { addURLs(panel.urls) }
    }

    func chooseOutputParent() {
        let panel = NSOpenPanel()
        panel.title = "选择输出位置"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            let access = SecurityScopeAccess()
            access.start(url)
            defer { access.stop() }
            outputParent = url
            outputParentBookmark = try? recoveryStore?.bookmark(for: url, readOnly: false)
        }
    }

    func addURLs(_ urls: [URL]) {
        let access = SecurityScopeAccess()
        urls.forEach { access.start($0) }
        defer { access.stop() }
        let discovered = FileDiscovery.discover(urls, recursive: recursiveFolders)
        let existing = Set(items.map { $0.url.resolvingSymlinksInPath().path })
        let additions = discovered.filter { !existing.contains($0.resolvingSymlinksInPath().path) }.map { url in
            ImageQueueItem(url: url, securityScopedBookmark: try? recoveryStore?.bookmark(for: url, readOnly: true))
        }
        guard !additions.isEmpty else { return }
        items.append(contentsOf: additions)
        if selectedItemID == nil { selectItem(items[0].id) }
        for addition in additions { loadThumbnail(for: addition.id) }
    }

    func selectItem(_ id: UUID?) {
        selectedItemID = id
        sourcePreview = nil
        outputPreview = nil
        previewBytes = nil
        previewDimensions = nil
        previewQuality = nil
        previewError = nil
        schedulePreview()
    }

    func clear() {
        guard !isRunning else { return }
        previewTask?.cancel()
        clearPreviewCache()
        isPreviewing = false
        items.removeAll()
        selectedItemID = nil
        sourcePreview = nil
        outputPreview = nil
        previewBytes = nil
        previewError = nil
        completedCount = 0
        failedCount = 0
    }

    func settingsDidChange() {
        guard !isRunning else { return }
        clearPreviewCache()
        schedulePreview()
    }

    func setHardwareAccelerationEnabled(_ enabled: Bool) {
        guard !isRunning else { return }
        startupGuardTask?.cancel()
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: Self.hardwareAccelerationPreferenceKey)
        defaults.set(false, forKey: Self.hardwareAccelerationStartupMarkerKey)

        if enabled {
            defaults.set(true, forKey: Self.hardwareAccelerationStartupMarkerKey)
            let renderer = PreviewRenderer(requestHardwareAcceleration: true)
            if renderer.usesHardwareAcceleration {
                previewRenderer = renderer
                hardwareAccelerationEnabled = true
                hardwareAccelerationStatus = "使用此 Mac 的图形处理器加速预览"
                armHardwareAccelerationStartupGuard()
            } else {
                previewRenderer = PreviewRenderer(requestHardwareAcceleration: false)
                hardwareAccelerationEnabled = false
                hardwareAccelerationStatus = "此 Mac 不支持图形加速，已使用兼容模式"
                defaults.set(false, forKey: Self.hardwareAccelerationPreferenceKey)
                defaults.set(false, forKey: Self.hardwareAccelerationStartupMarkerKey)
            }
        } else {
            previewRenderer = PreviewRenderer(requestHardwareAcceleration: false)
            hardwareAccelerationEnabled = false
            hardwareAccelerationStatus = "使用兼容模式渲染预览"
        }
        settingsDidChange()
    }

    func schedulePreview() {
        previewTask?.cancel()
        guard !isRunning else {
            isPreviewing = false
            return
        }
        guard let item = selectedItem else {
            isPreviewing = false
            return
        }
        let itemID = item.id
        let url = item.url
        let preset = selectedPreset
        let renderer = previewRenderer
        isPreviewing = true
        previewError = nil
        previewTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            do {
                async let sourceImage = Task.detached(priority: .userInitiated) { try renderer.render(url: url) }.value
                async let sourceFingerprint = Task.detached(priority: .utility) { try SourceFingerprint.capture(url: url) }.value
                let renderedSource = try await sourceImage
                guard !Task.isCancelled, selectedItemID == itemID else { return }
                sourcePreview = NSImage(cgImage: renderedSource, size: .zero)

                let fingerprint = try await sourceFingerprint
                guard !Task.isCancelled else { return }
                let result: EncodedImageResult
                if let cached = cachedResult(for: itemID, preset: preset, fingerprint: fingerprint) {
                    result = cached
                } else {
                    result = try await encode(url: url, preset: preset)
                    try await Task.detached(priority: .utility) { try fingerprint.verifyUnchanged() }.value
                    cache(result, for: itemID, preset: preset, fingerprint: fingerprint)
                }
                let renderedOutput = try await Task.detached(priority: .userInitiated) { try renderer.render(data: result.data) }.value
                guard !Task.isCancelled, selectedItemID == itemID, selectedPreset == preset else { return }
                outputPreview = NSImage(cgImage: renderedOutput, size: .zero)
                previewBytes = result.data.count
                previewDimensions = result.dimensions
                previewQuality = result.quality
            } catch is CancellationError {
            } catch {
                guard selectedItemID == itemID, selectedPreset == preset else { return }
                previewError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                outputPreview = nil
            }
            if selectedItemID == itemID, selectedPreset == preset { isPreviewing = false }
        }
    }

    func startBatch(retryFailedOnly: Bool = false) {
        guard !isRunning, !items.isEmpty else { return }
        previewTask?.cancel()
        isPreviewing = false
        batchTask = Task { await runBatch(retryFailedOnly: retryFailedOnly) }
    }

    func pauseOrResume() {
        guard isRunning else { return }
        isPaused.toggle()
        Task {
            if isPaused { try? await coordinator.pause() }
            else { try? await coordinator.resume() }
        }
    }

    func cancel() {
        guard isRunning else { return }
        cancelRequested = true
        Task { try? await coordinator.cancel() }
        batchTask?.cancel()
        if let request = currentWorkerRequest {
            Task {
                await codecHost.cancel(requestID: request)
                await nativeCodecHost.cancel(requestID: request)
            }
        }
    }

    func shutdown() {
        previewTask?.cancel()
        batchTask?.cancel()
        startupGuardTask?.cancel()
        UserDefaults.standard.set(false, forKey: Self.hardwareAccelerationStartupMarkerKey)
        clearPreviewCache()
        Task {
            await codecHost.shutdown()
            await nativeCodecHost.shutdown()
        }
    }

    func retryFailures() {
        for index in items.indices where items[index].state == .failed {
            items[index].state = .queued
            items[index].errorMessage = nil
        }
        startBatch(retryFailedOnly: true)
    }

    func canResume(_ jobID: UUID) -> Bool {
        recoveryStore?.records().contains(where: { $0.id == jobID }) == true
    }

    func resume(_ jobID: UUID) {
        guard !isRunning,
              let recoveryStore,
              let record = recoveryStore.records().first(where: { $0.id == jobID }),
              let manifest = history.first(where: { $0.id == jobID }) else {
            recoveryMessage = "找不到可恢复的任务记录"
            return
        }
        do {
            let resolved = try recoveryStore.resolve(record)
            guard FileManager.default.fileExists(atPath: resolved.outputDirectory.path) else {
                throw SquooshProError.permissionDenied
            }
            var restoredItems: [ImageQueueItem] = []
            for itemRecord in resolved.record.items {
                guard let url = resolved.sourceURLs[itemRecord.id],
                      let manifestItem = manifest.items.first(where: { $0.id == itemRecord.id }) else {
                    throw SquooshProError.permissionDenied
                }
                var item = ImageQueueItem(id: itemRecord.id, url: url, securityScopedBookmark: itemRecord.sourceBookmark)
                let outputURL = manifestItem.outputFileName.map { resolved.outputDirectory.appendingPathComponent($0) }
                if manifestItem.state == .completed, let outputURL, FileManager.default.fileExists(atPath: outputURL.path) {
                    item.state = .completed
                    item.outputURL = outputURL
                    item.outputBytes = manifestItem.outputBytes.map(Int.init)
                } else {
                    item.state = .queued
                }
                if let expected = itemRecord.fingerprint, try SourceFingerprint.capture(url: url) != expected {
                    item.state = .failed
                    item.errorMessage = SquooshProError.sourceChanged.errorDescription
                }
                restoredItems.append(item)
            }
            guard !restoredItems.isEmpty else { throw SquooshProError.permissionDenied }
            items = restoredItems
            selectedPreset = resolved.record.preset
            selectedItemID = restoredItems.first?.id
            currentOutputDirectory = resolved.outputDirectory
            completedCount = restoredItems.filter { $0.state == .completed }.count
            failedCount = restoredItems.filter { $0.state == .failed }.count
            restoredItems.forEach { loadThumbnail(for: $0.id) }
            selectItem(selectedItemID)
            previewTask?.cancel()
            isPreviewing = false
            recoveryMessage = "已恢复任务，继续处理未完成文件"
            let context = ResumeContext(manifest: manifest, recovery: resolved.record, outputDirectory: resolved.outputDirectory, access: resolved.access)
            batchTask = Task { await runBatch(retryFailedOnly: true, resume: context) }
        } catch {
            recoveryMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func revealOutput() {
        guard let directory = currentOutputDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    func saveUserPreset(name: String, notes: String = "") throws {
        var copy = selectedPreset
        copy.id = "user.\(UUID().uuidString.lowercased())"
        copy.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "自定义预设" : name
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        copy.kind = "user"
        try PresetValidator.validate(copy)
        try store?.save(copy, relativePath: "Presets/\(copy.id).json")
        userPresets.append(copy)
        userPresets.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func importPreset() throws {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data = try Data(contentsOf: url)
        let presets: [CompressionPreset]
        if let batch = try? JSONDecoder().decode([CompressionPreset].self, from: data) {
            try batch.forEach(PresetValidator.validate)
            presets = batch
        } else {
            presets = [try PresetValidator.decode(data)]
        }
        for imported in presets {
            var preset = imported
            preset.id = "user.\(UUID().uuidString.lowercased())"
            preset.kind = "user"
            try store?.save(preset, relativePath: "Presets/\(preset.id).json")
        }
        reloadPersistence()
    }

    func exportUserPresets() throws {
        guard !userPresets.isEmpty else {
            throw SquooshProError.invalidPreset("还没有可导出的自定义预设")
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Squoosh-Pro-我的预设.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(userPresets).write(to: url, options: .withoutOverwriting)
    }

    private func runBatch(retryFailedOnly: Bool, resume: ResumeContext? = nil) async {
        let batchPreset = resume?.recovery.preset ?? selectedPreset
        let access = resume?.access ?? SecurityScopeAccess()
        if resume == nil {
            items.forEach { access.start($0.url) }
            if let outputParent { access.start(outputParent) }
        }
        defer { access.stop() }
        isRunning = true
        try? await coordinator.start()
        isPaused = false
        cancelRequested = false
        if !retryFailedOnly {
            completedCount = 0
            failedCount = 0
            for index in items.indices {
                items[index].state = .queued
                items[index].outputURL = nil
                items[index].outputBytes = nil
                items[index].errorMessage = nil
            }
        } else {
            completedCount = items.filter { $0.state == .completed }.count
            failedCount = 0
        }

        let candidates = items.indices.filter { retryFailedOnly ? items[$0].state == .queued : true }
        let sourceURLs = items.map(\.url)
        let parent = outputParent ?? sourceURLs.first!.deletingLastPathComponent()
        let outputDirectory: URL
        var manifest: JobManifest
        var recovery: JobRecoveryRecord?
        do {
            if let resume {
                outputDirectory = resume.outputDirectory
                manifest = resume.manifest
                recovery = resume.recovery
            } else {
                outputDirectory = try writer.createTimestampedDirectory(parent: parent)
                manifest = JobManifest(preset: batchPreset, outputDirectoryName: outputDirectory.lastPathComponent, items: items.map {
                    JobItemRecord(id: $0.id, sourceFileName: $0.url.lastPathComponent, inputBytes: Int64((try? $0.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0))
                })
                guard let recoveryStore else { throw SquooshProError.permissionDenied }
                recovery = try recoveryStore.makeRecord(
                    jobID: manifest.id,
                    outputDirectory: outputDirectory,
                    preset: batchPreset,
                    sources: items.map { RecoverableSource(id: $0.id, url: $0.url, securityScopedBookmark: $0.securityScopedBookmark) }
                )
            }
            currentOutputDirectory = outputDirectory
        } catch {
            failedCount = candidates.count
            for index in candidates { items[index].state = .failed; items[index].errorMessage = error.localizedDescription }
            recoveryMessage = "无法创建可恢复任务：\(error.localizedDescription)"
            isRunning = false
            return
        }

        manifest.state = .running
        persist(&manifest)
        persistRecovery(&recovery)

        for index in candidates {
            if Task.isCancelled || cancelRequested { break }
            while isPaused && !Task.isCancelled {
                manifest.state = .paused
                persist(&manifest)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            if Task.isCancelled || cancelRequested { break }
            do { try await coordinator.waitForPermission() } catch { break }
            let url = items[index].url
            do {
                update(index, manifest: &manifest, recovery: &recovery, state: .reading)
                let fingerprint = try await Task.detached { try SourceFingerprint.capture(url: url) }.value
                if let recoveryIndex = recovery?.items.firstIndex(where: { $0.id == items[index].id }) {
                    if let expected = recovery?.items[recoveryIndex].fingerprint, expected != fingerprint {
                        throw SquooshProError.sourceChanged
                    }
                    recovery?.items[recoveryIndex].fingerprint = fingerprint
                    persistRecovery(&recovery)
                }
                update(index, manifest: &manifest, recovery: &recovery, state: .decoding)
                update(index, manifest: &manifest, recovery: &recovery, state: .transforming)
                update(index, manifest: &manifest, recovery: &recovery, state: .encoding)
                let result: EncodedImageResult
                if let cached = cachedResult(for: items[index].id, preset: batchPreset, fingerprint: fingerprint) {
                    result = cached
                } else {
                    result = try await encode(url: url, preset: batchPreset)
                }
                update(index, manifest: &manifest, recovery: &recovery, state: .verifying)
                try writer.verify(data: result.data, expectedFormat: result.format, expectedDimensions: result.dimensions, targetBytes: batchPreset.output.strategy == .targetBytes ? batchPreset.output.targetBytes : nil)
                try await Task.detached(priority: .utility) { try fingerprint.verifyUnchanged() }.value
                update(index, manifest: &manifest, recovery: &recovery, state: .committing)
                var outputURL = writer.nextOutputURL(directory: outputDirectory, sourceName: url.lastPathComponent, preset: batchPreset, format: result.format)
                while true {
                    do {
                        try writer.commit(result, to: outputURL, sourceURLs: sourceURLs, targetBytes: batchPreset.output.strategy == .targetBytes ? batchPreset.output.targetBytes : nil)
                        break
                    } catch SquooshProError.outputConflict {
                        outputURL = writer.nextOutputURL(directory: outputDirectory, sourceName: url.lastPathComponent, preset: batchPreset, format: result.format)
                    }
                }
                items[index].outputURL = outputURL
                items[index].outputBytes = result.data.count
                manifest.items[index].outputFileName = outputURL.lastPathComponent
                manifest.items[index].outputBytes = Int64(result.data.count)
                update(index, manifest: &manifest, recovery: &recovery, state: .completed)
                removeCachedResult(for: items[index].id)
                completedCount += 1
            } catch {
                let wasCancelled = Task.isCancelled || (error as? SquooshProError) == .cancelled
                items[index].state = wasCancelled ? .cancelled : .failed
                items[index].errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                manifest.items[index].state = items[index].state
                if let recoveryIndex = recovery?.items.firstIndex(where: { $0.id == items[index].id }) {
                    recovery?.items[recoveryIndex].state = items[index].state
                }
                if let typed = error as? SquooshProError { manifest.items[index].errorCode = typed.code }
                manifest.items[index].errorMessage = items[index].errorMessage
                if !wasCancelled { failedCount += 1 }
                persist(&manifest)
                persistRecovery(&recovery)
            }
        }

        if Task.isCancelled || cancelRequested {
            manifest.state = .cancelled
            for index in items.indices where items[index].state != .completed && items[index].state != .failed {
                items[index].state = .cancelled
                manifest.items[index].state = .cancelled
                if let recoveryIndex = recovery?.items.firstIndex(where: { $0.id == items[index].id }) {
                    recovery?.items[recoveryIndex].state = .cancelled
                }
            }
        } else if failedCount > 0 {
            manifest.state = .completedWithErrors
        } else {
            manifest.state = .completed
        }
        if manifest.state == .completed || manifest.state == .completedWithErrors {
            try? await coordinator.finish(hadErrors: manifest.state == .completedWithErrors)
        }
        persist(&manifest)
        if manifest.state == .completed {
            try? recoveryStore?.remove(jobID: manifest.id)
        } else {
            persistRecovery(&recovery)
        }
        isRunning = false
        isPaused = false
        cancelRequested = false
        currentWorkerRequest = nil
        clearPreviewCache()
        reloadPersistence()
    }

    private func cachedResult(
        for itemID: UUID,
        preset: CompressionPreset,
        fingerprint: SourceFingerprint
    ) -> EncodedImageResult? {
        let result = previewCache.result(for: itemID, preset: preset, fingerprint: fingerprint)
        cachedItemIDs = previewCache.itemIDs
        return result
    }

    private func cache(
        _ result: EncodedImageResult,
        for itemID: UUID,
        preset: CompressionPreset,
        fingerprint: SourceFingerprint
    ) {
        previewCache.insert(result, for: itemID, preset: preset, fingerprint: fingerprint)
        cachedItemIDs = previewCache.itemIDs
    }

    private func removeCachedResult(for itemID: UUID) {
        previewCache.remove(for: itemID)
        cachedItemIDs = previewCache.itemIDs
    }

    private func clearPreviewCache() {
        previewCache.removeAll()
        cachedItemIDs = []
    }

    private static func makeStartupPreviewRenderer() -> (renderer: PreviewRenderer, enabled: Bool, status: String) {
        let defaults = UserDefaults.standard
        let requested = (defaults.object(forKey: hardwareAccelerationPreferenceKey) as? Bool) ?? true
        if requested, defaults.bool(forKey: hardwareAccelerationStartupMarkerKey) {
            defaults.set(false, forKey: hardwareAccelerationPreferenceKey)
            defaults.set(false, forKey: hardwareAccelerationStartupMarkerKey)
            return (
                PreviewRenderer(requestHardwareAcceleration: false),
                false,
                "上次启动未正常完成，已自动关闭图形加速"
            )
        }

        guard requested else {
            return (PreviewRenderer(requestHardwareAcceleration: false), false, "使用兼容模式渲染预览")
        }

        defaults.set(true, forKey: hardwareAccelerationStartupMarkerKey)
        let renderer = PreviewRenderer(requestHardwareAcceleration: true)
        guard renderer.usesHardwareAcceleration else {
            defaults.set(false, forKey: hardwareAccelerationPreferenceKey)
            defaults.set(false, forKey: hardwareAccelerationStartupMarkerKey)
            return (PreviewRenderer(requestHardwareAcceleration: false), false, "此 Mac 不支持图形加速，已使用兼容模式")
        }
        return (renderer, true, "使用此 Mac 的图形处理器加速预览")
    }

    private func armHardwareAccelerationStartupGuard() {
        startupGuardTask?.cancel()
        startupGuardTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            UserDefaults.standard.set(false, forKey: Self.hardwareAccelerationStartupMarkerKey)
        }
    }

    private func encode(url: URL, preset: CompressionPreset) async throws -> EncodedImageResult {
        let processor = self.processor
        if preset.output.format == .mozjpeg {
            return try await encodeJPEG(url: url, preset: preset)
        }
        if preset.output.format == .avif, processor.supportsNativeEncoding(.avif) {
            workerStatus = "所有图片格式均可使用"
            let request = UUID()
            currentWorkerRequest = request
            defer { currentWorkerRequest = nil }
            let data = try await nativeCodecHost.encode(sourceURL: url, preset: preset, requestID: request)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw SquooshProError.verifyFailed
            }
            return EncodedImageResult(
                data: data,
                format: .avif,
                dimensions: .init(width: image.width, height: image.height),
                quality: preset.output.quality
            )
        }
        if preset.output.format == .webp || preset.output.format == .avif {
            let processor = self.processor
            let decoded = try await Task.detached { try processor.decode(url: url, resize: preset.resize, jpegBackground: preset.alpha.jpegBackground) }.value
            let rgba = try await Task.detached { try processor.rgbaBytes(from: decoded.image) }.value
            let options = preset.formatOptions.merging(["quality": Double(preset.output.quality)]) { current, _ in current }
            for attempt in 0..<2 {
                let request = UUID()
                currentWorkerRequest = request
                do {
                    let data = try await codecHost.encodeRGBA(rgba, width: decoded.image.width, height: decoded.image.height, format: preset.output.format, options: options, requestID: request)
                    currentWorkerRequest = nil
                    return EncodedImageResult(data: data, format: preset.output.format, dimensions: .init(width: decoded.image.width, height: decoded.image.height), quality: preset.output.quality)
                } catch let error as SquooshProError where error == .workerCrashed && attempt == 0 && !Task.isCancelled {
                    currentWorkerRequest = nil
                    workerStatus = "编码器已恢复，正在重试当前图片"
                    try await Task.sleep(nanoseconds: 250_000_000)
                } catch {
                    currentWorkerRequest = nil
                    throw error
                }
            }
            throw SquooshProError.workerCrashed
        }
        return try await Task.detached { try processor.encode(url: url, preset: preset) }.value
    }

    private func encodeJPEG(url: URL, preset: CompressionPreset) async throws -> EncodedImageResult {
        try PresetValidator.validate(preset)
        let widths: [Int?]
        if preset.output.strategy == .targetBytes {
            let candidates = preset.resize.candidateWidths.isEmpty ? [preset.resize.width].compactMap { $0 } : preset.resize.candidateWidths
            widths = candidates.isEmpty ? [nil] : candidates.map(Optional.some)
        } else {
            widths = [nil]
        }

        for width in widths {
            try Task.checkCancellation()
            let processor = self.processor
            let decoded = try await Task.detached(priority: .userInitiated) {
                try processor.decode(
                    url: url,
                    resize: preset.resize,
                    overrideWidth: width,
                    jpegBackground: preset.alpha.jpegBackground,
                    flattenAlpha: true
                )
            }.value
            let rgba = try await Task.detached(priority: .userInitiated) {
                try processor.rgbaBytes(from: decoded.image)
            }.value
            let dimensions = ImageDimensions(width: decoded.image.width, height: decoded.image.height)

            if preset.output.strategy == .targetBytes {
                let target = preset.output.targetBytes ?? 0
                let safetyTarget = min(preset.output.safetyTargetBytes ?? target, target)
                if let candidate = try await searchJPEGQuality(
                    rgba: rgba,
                    width: dimensions.width,
                    height: dimensions.height,
                    preset: preset,
                    targetBytes: safetyTarget
                ), candidate.data.count <= target {
                    return EncodedImageResult(data: candidate.data, format: .mozjpeg, dimensions: dimensions, quality: candidate.quality)
                }
            } else {
                let data = try await encodeJPEGRGBA(
                    rgba,
                    width: dimensions.width,
                    height: dimensions.height,
                    quality: preset.output.quality,
                    formatOptions: preset.formatOptions
                )
                return EncodedImageResult(data: data, format: .mozjpeg, dimensions: dimensions, quality: preset.output.quality)
            }
        }
        throw SquooshProError.targetNotMet
    }

    private func searchJPEGQuality(
        rgba: Data,
        width: Int,
        height: Int,
        preset: CompressionPreset,
        targetBytes: Int
    ) async throws -> (data: Data, quality: Int)? {
        var attempts = 0
        var measured: [Int: Data] = [:]
        var best: (data: Data, quality: Int)?

        func measure(_ quality: Int) async throws -> Data {
            if let cached = measured[quality] { return cached }
            guard attempts < preset.output.maximumSearchAttempts else { throw SquooshProError.targetNotMet }
            try Task.checkCancellation()
            attempts += 1
            let data = try await encodeJPEGRGBA(
                rgba,
                width: width,
                height: height,
                quality: quality,
                formatOptions: preset.formatOptions
            )
            measured[quality] = data
            if data.count <= targetBytes, quality > (best?.quality ?? -1) { best = (data, quality) }
            return data
        }

        let initialQuality = preset.output.quality
        let initial = try await measure(initialQuality)
        var low = preset.output.minimumQuality
        var high = initial.count > targetBytes ? initialQuality - 1 : 100
        while low <= high, attempts < preset.output.maximumSearchAttempts {
            let quality = (low + high) / 2
            let data = try await measure(quality)
            if data.count <= targetBytes {
                low = quality + 1
            } else {
                high = quality - 1
            }
        }
        if best == nil, attempts < preset.output.maximumSearchAttempts {
            _ = try await measure(preset.output.minimumQuality)
        }
        return best
    }

    private func encodeJPEGRGBA(
        _ rgba: Data,
        width: Int,
        height: Int,
        quality: Int,
        formatOptions: [String: Double]
    ) async throws -> Data {
        let options = formatOptions.merging(["quality": Double(quality)]) { current, _ in current }
        for attempt in 0..<2 {
            let request = UUID()
            currentWorkerRequest = request
            do {
                let data = try await codecHost.encodeRGBA(
                    rgba,
                    width: width,
                    height: height,
                    format: .mozjpeg,
                    options: options,
                    requestID: request
                )
                currentWorkerRequest = nil
                return data
            } catch let error as SquooshProError where error == .workerCrashed && attempt == 0 && !Task.isCancelled {
                currentWorkerRequest = nil
                workerStatus = "编码器已恢复，正在重试当前图片"
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                currentWorkerRequest = nil
                throw error
            }
        }
        throw SquooshProError.workerCrashed
    }

    private func update(_ index: Int, manifest: inout JobManifest, recovery: inout JobRecoveryRecord?, state: FileState) {
        items[index].state = state
        manifest.items[index].state = state
        if let recoveryIndex = recovery?.items.firstIndex(where: { $0.id == items[index].id }) {
            recovery?.items[recoveryIndex].state = state
        }
        persist(&manifest)
        persistRecovery(&recovery)
    }

    private func persist(_ manifest: inout JobManifest) {
        manifest.updatedAt = Date()
        try? store?.save(manifest, relativePath: "Jobs/\(manifest.id.uuidString.lowercased()).json")
    }

    private func persistRecovery(_ recovery: inout JobRecoveryRecord?) {
        guard var value = recovery else { return }
        value.updatedAt = Date()
        try? recoveryStore?.save(value)
        recovery = value
    }

    private func reloadPersistence() {
        history = store?.jobManifests() ?? []
        recoveredJobCount = recoveryStore?.records().count ?? 0
        guard let presetDirectory = store?.root.appendingPathComponent("Presets", isDirectory: true) else { return }
        let urls = (try? FileManager.default.contentsOfDirectory(at: presetDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        userPresets = urls.compactMap { try? PresetValidator.decode(Data(contentsOf: $0)) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func loadThumbnail(for id: UUID) {
        guard let url = items.first(where: { $0.id == id })?.url else { return }
        Task {
            let cgImage = await Task.detached { () -> CGImage? in
                guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 160,
                        kCGImageSourceShouldCacheImmediately: true,
                      ] as CFDictionary) else { return nil }
                return cgImage
            }.value
            if let cgImage, let index = items.firstIndex(where: { $0.id == id }) {
                items[index].thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }
    }
}
