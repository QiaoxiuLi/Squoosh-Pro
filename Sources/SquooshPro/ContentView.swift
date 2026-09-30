import AppKit
import SquooshCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $model.section) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
                    .accessibilityIdentifier("sidebar.\(section.id)")
            }
            .navigationTitle("Squoosh Pro")
            .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
        } detail: {
            switch model.section ?? .compress {
            case .compress: CompressionWorkspace()
            case .presets: PresetsView()
            case .history: HistoryView()
            case .settings: ApplicationSettingsView()
            }
        }
        .toolbar { toolbar }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { model.chooseImages() } label: { Label("添加图片", systemImage: "photo.badge.plus") }
                .labelStyle(.titleAndIcon)
                .help("添加一张或多张图片")
                .accessibilityIdentifier("toolbar.addImages")
            Button { model.chooseFolder() } label: { Label("添加文件夹", systemImage: "folder.badge.plus") }
                .labelStyle(.titleAndIcon)
                .help("添加文件夹")
                .accessibilityIdentifier("toolbar.addFolder")
            Button { model.clear() } label: { Label("清空", systemImage: "trash") }
                .labelStyle(.titleAndIcon)
                .disabled(model.items.isEmpty || model.isRunning)
                .accessibilityIdentifier("toolbar.clear")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if model.isRunning {
                Button { model.pauseOrResume() } label: {
                    Label(model.isPaused ? "继续" : "暂停", systemImage: model.isPaused ? "play.fill" : "pause.fill")
                }
                    .labelStyle(.titleAndIcon)
                    .accessibilityIdentifier("toolbar.pauseResume")
                Button { model.cancel() } label: { Label("取消", systemImage: "xmark.circle") }
                    .labelStyle(.titleAndIcon)
                    .accessibilityIdentifier("toolbar.cancel")
            } else {
                Button { model.startBatch() } label: { Label("开始压缩", systemImage: "play.fill") }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.items.isEmpty)
                    .accessibilityIdentifier("toolbar.start")
            }
        }
    }
}

private struct CompressionWorkspace: View {
    @EnvironmentObject private var model: AppModel
    @State private var dropTargeted = false
    @State private var compactTab = 1

    var body: some View {
        VStack(spacing: 0) {
            if model.items.isEmpty {
                EmptyWorkspace()
            } else {
                GeometryReader { geometry in
                    if geometry.size.width >= 900 && geometry.size.height >= 480 {
                        HSplitView {
                            QueueList()
                                .frame(minWidth: 210, idealWidth: 235, maxWidth: 320)
                            PreviewPane()
                                .frame(minWidth: 380)
                            CompressionSettingsPane()
                                .frame(minWidth: 280, idealWidth: 310, maxWidth: 390)
                        }
                    } else {
                        TabView(selection: $compactTab) {
                            QueueList()
                                .tabItem { Label("图片", systemImage: "photo.on.rectangle") }
                                .accessibilityIdentifier("compact.queue")
                                .tag(0)
                            PreviewPane()
                                .tabItem { Label("预览", systemImage: "rectangle.split.2x1") }
                                .accessibilityIdentifier("compact.preview")
                                .tag(1)
                            CompressionSettingsPane()
                                .tabItem { Label("设置", systemImage: "slider.horizontal.3") }
                                .accessibilityIdentifier("compact.settings")
                                .tag(2)
                        }
                        .onChange(of: model.selectedItemID) { _ in compactTab = 1 }
                    }
                }
            }
            if !model.items.isEmpty {
                BatchSummaryBar()
            }
        }
        .background(dropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.addURLs(urls)
            return true
        } isTargeted: { dropTargeted = $0 }
        .navigationTitle("压缩")
    }
}

private struct EmptyWorkspace: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 28) {
                        heroCopy
                        Spacer(minLength: 12)
                        heroSymbol
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        heroCopy
                        heroSymbol.frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(28)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.16), Color.teal.opacity(0.10), Color(nsColor: .controlBackgroundColor)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(0.08))
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("选择压缩方案").font(.title3.weight(.semibold))
                        Spacer()
                        Text("当前：\(model.selectedPreset.name)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                        ForEach(featuredPresets) { preset in
                            PresetChoiceCard(
                                preset: preset,
                                description: description(for: preset),
                                isSelected: model.selectedPreset.id == preset.id
                            ) {
                                model.selectPreset(preset)
                            }
                        }
                    }
                }

                Label("已选择“\(model.selectedPreset.name)”。添加图片后，点击右上角“开始压缩”。", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.accentColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("empty.selectedPreset")
            }
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var featuredPresets: [CompressionPreset] {
        [.smart, .websiteJPEG, .webJPEG150KB, .losslessPNG]
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Squoosh Pro")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    chooseImagesButton
                    chooseFolderButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    chooseImagesButton
                    chooseFolderButton
                }
            }
        }
    }

    private var heroSymbol: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 50, weight: .medium))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 132, height: 116)
    }

    private func description(for preset: CompressionPreset) -> String {
        switch preset.id {
        case CompressionPreset.smart.id: return "自动选择合适的格式和质量"
        case CompressionPreset.websiteJPEG.id: return "兼容常用浏览器和设备"
        case CompressionPreset.webJPEG150KB.id: return "适合网页上传，每张不超过 150 KB"
        case CompressionPreset.losslessPNG.id: return "保留 PNG 清晰度和透明区域"
        default: return "使用已保存的压缩设置"
        }
    }

    private var chooseImagesButton: some View {
        Button {
            model.chooseImages()
        } label: {
            Label("选择图片", systemImage: "photo.badge.plus")
                .frame(minWidth: 92)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("empty.chooseImages")
    }

    private var chooseFolderButton: some View {
        Button {
            model.chooseFolder()
        } label: {
            Label("选择文件夹", systemImage: "folder.badge.plus")
                .frame(minWidth: 92)
        }
        .controlSize(.large)
        .buttonStyle(.bordered)
        .accessibilityIdentifier("empty.chooseFolder")
    }
}

private struct PresetChoiceCard: View {
    let preset: CompressionPreset
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    Spacer()
                    if isSelected {
                        Label("已选择", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(preset.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(preset.output.format.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
            .background(
                isSelected ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("empty.preset.\(preset.id)")
        .accessibilityLabel("\(preset.name)，\(description)\(isSelected ? "，已选择" : "")")
    }

    private var icon: String {
        switch preset.output.format {
        case .automatic: return "wand.and.stars"
        case .mozjpeg: return "globe"
        case .oxipng: return "sparkles.rectangle.stack"
        case .webp, .avif: return "gauge.with.dots.needle.67percent"
        }
    }
}

private struct QueueList: View {
    @EnvironmentObject private var model: AppModel
    @State private var searchText = ""

    private var selection: Binding<UUID?> {
        Binding(get: { model.selectedItemID }, set: { model.selectItem($0) })
    }

    private var filteredItems: [ImageQueueItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.items }
        return model.items.filter { $0.url.lastPathComponent.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("图片").font(.headline)
                Spacer()
                Text("\(model.items.count)").foregroundStyle(.secondary)
            }.padding(12)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索图片", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("queue.search")
                if !searchText.isEmpty {
                    Button("清除") { searchText = "" }
                        .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            Divider()
            List(filteredItems, selection: selection) { item in
                HStack(spacing: 10) {
                    Group {
                        if let thumbnail = item.thumbnail { Image(nsImage: thumbnail).resizable().scaledToFill() }
                        else { Image(systemName: "photo").foregroundStyle(.secondary) }
                    }
                    .frame(width: 52, height: 42)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                        HStack(spacing: 5) {
                            StatusIcon(state: item.state)
                            Text(statusText(item)).font(.caption).foregroundStyle(item.state == .failed ? Color.red : Color.secondary).lineLimit(1)
                        }
                        if model.cachedItemIDs.contains(item.id) {
                            Label("已缓存", systemImage: "bolt.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { model.selectItem(item.id) }
                .tag(item.id)
                .accessibilityIdentifier("queue.item.\(item.id.uuidString)")
                .accessibilityLabel("\(item.url.lastPathComponent)，\(statusText(item))")
            }
            .listStyle(.sidebar)
        }
    }

    private func statusText(_ item: ImageQueueItem) -> String {
        if let error = item.errorMessage { return error }
        switch item.state {
        case .queued: return "等待处理"
        case .reading: return "读取中"
        case .decoding: return "解码中"
        case .transforming: return "调整中"
        case .encoding: return "压缩中"
        case .verifying: return "验证中"
        case .committing: return "保存中"
        case .completed: return item.outputBytes.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
}

private struct StatusIcon: View {
    let state: FileState
    var body: some View {
        switch state {
        case .completed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        case .cancelled: Image(systemName: "xmark.circle").foregroundStyle(.secondary)
        case .queued: Image(systemName: "circle").foregroundStyle(.secondary)
        default: ProgressView().controlSize(.mini)
        }
    }
}

private struct PreviewPane: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var navigation = PreviewNavigation()

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("效果预览").font(.headline)
                HStack(spacing: 8) {
                    Button("适应窗口") { navigation.perform(.fit) }.accessibilityIdentifier("preview.fit")
                    Button("100%") { navigation.perform(.actual) }.accessibilityIdentifier("preview.actualSize")
                    Button { navigation.perform(.zoomOut) } label: { Image(systemName: "minus").frame(width: 20, height: 18) }
                        .accessibilityLabel("缩小预览").accessibilityIdentifier("preview.zoomOut")
                    Text("\(navigation.percent)%").monospacedDigit().frame(minWidth: 44).accessibilityIdentifier("preview.zoomValue")
                    Button { navigation.perform(.zoomIn) } label: { Image(systemName: "plus").frame(width: 20, height: 18) }
                        .accessibilityLabel("放大预览").accessibilityIdentifier("preview.zoomIn")
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.bordered)
            .padding(12)
            Divider()
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                if let source = model.sourcePreview {
                    ComparisonPreview(source: source, output: model.outputPreview, dimensions: model.previewDimensions, navigation: navigation)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .top) {
                            HStack {
                                Text("原图").padding(6).background(.regularMaterial, in: Capsule())
                                Spacer()
                                Text("输出").padding(6).background(.regularMaterial, in: Capsule())
                            }
                            .font(.caption)
                            .padding(12)
                            .allowsHitTesting(false)
                        }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark").font(.largeTitle).foregroundStyle(.secondary)
                        Text("无法预览").font(.headline)
                        Text("请选择一张可读取的图片").foregroundStyle(.secondary)
                    }
                }
                if model.isPreviewing {
                    VStack { ProgressView(); Text("正在加载预览").font(.caption).foregroundStyle(.secondary) }
                        .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), alignment: .leading)], alignment: .leading, spacing: 12) {
                    Metric(label: "原始", value: model.selectedItem.flatMap { try? $0.url.resourceValues(forKeys: [.fileSizeKey]).fileSize }.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "—")
                    Metric(label: "预计输出", value: model.previewBytes.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "—")
                    Metric(label: "输出尺寸", value: model.previewDimensions.map { "\($0.width)×\($0.height)" } ?? "—")
                    Metric(label: "质量", value: model.previewQuality.map(String.init) ?? "—")
                }
                if let error = model.previewError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(model.previewError != nil ? "预览加载失败" : model.isPreviewing ? "正在加载预览" : model.outputPreview == nil ? "等待预览" : "预览已加载 · 拖动分界线对比，放大后可拖动画面")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("preview.ready")
            }
            .padding(12)
        }
    }
}

private struct Metric: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
        }
    }
}
