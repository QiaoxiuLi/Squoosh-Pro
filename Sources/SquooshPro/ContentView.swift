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
                .help("添加一张或多张图片")
                .accessibilityIdentifier("toolbar.addImages")
            Button { model.chooseFolder() } label: { Label("添加文件夹", systemImage: "folder.badge.plus") }
                .help("添加文件夹")
                .accessibilityIdentifier("toolbar.addFolder")
            Button { model.clear() } label: { Label("清空", systemImage: "trash") }
                .disabled(model.items.isEmpty || model.isRunning)
                .accessibilityIdentifier("toolbar.clear")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if model.isRunning {
                Button(model.isPaused ? "继续" : "暂停") { model.pauseOrResume() }
                    .accessibilityIdentifier("toolbar.pauseResume")
                Button("取消") { model.cancel() }
                    .accessibilityIdentifier("toolbar.cancel")
            } else {
                Button { model.startBatch() } label: { Label("开始压缩", systemImage: "play.fill") }
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
                        TabView {
                            QueueList()
                                .tabItem { Label("图片", systemImage: "photo.on.rectangle") }
                                .accessibilityIdentifier("compact.queue")
                            PreviewPane()
                                .tabItem { Label("预览", systemImage: "rectangle.split.2x1") }
                                .accessibilityIdentifier("compact.preview")
                            CompressionSettingsPane()
                                .tabItem { Label("设置", systemImage: "slider.horizontal.3") }
                                .accessibilityIdentifier("compact.settings")
                        }
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

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        WorkflowStep(number: 1, title: "添加图片")
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        WorkflowStep(number: 2, title: "选择方案")
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        WorkflowStep(number: 3, title: "开始压缩")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        WorkflowStep(number: 1, title: "添加图片")
                        WorkflowStep(number: 2, title: "选择方案")
                        WorkflowStep(number: 3, title: "开始压缩")
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

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
            Text("本地图片压缩")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text("拖入图片，清晰地完成压缩")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text("选择图片和压缩方案，确认预览后开始处理。原图不会被修改。")
                .font(.callout)
                .foregroundStyle(.secondary)
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

private struct WorkflowStep: View {
    let number: Int
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
            Text(title).font(.callout.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QueueList: View {
    @EnvironmentObject private var model: AppModel

    private var selection: Binding<UUID?> {
        Binding(get: { model.selectedItemID }, set: { model.selectItem($0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("图片").font(.headline)
                Spacer()
                Text("\(model.items.count)").foregroundStyle(.secondary)
            }.padding(12)
            Divider()
            List(model.items, selection: selection) { item in
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
                    }
                }
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
    @State private var divider = 0.5
    @State private var zoom: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("效果预览").font(.headline)
                Spacer()
                Button { zoom = 1 } label: { Label("适应窗口", systemImage: "arrow.up.left.and.arrow.down.right") }.accessibilityIdentifier("preview.fit")
                Button { zoom = 2 } label: { Text("100%") }.accessibilityIdentifier("preview.actualSize")
            }
            .buttonStyle(.borderless)
            .padding(12)
            Divider()
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                if let source = model.sourcePreview {
                    BeforeAfterImage(source: source, output: model.outputPreview, divider: $divider, zoom: zoom)
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
            .clipped()
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), alignment: .leading)], alignment: .leading, spacing: 12) {
                    Metric(label: "原始", value: model.selectedItem.map { ByteCountFormatter.string(fromByteCount: Int64((try? $0.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0), countStyle: .file) } ?? "—")
                    Metric(label: "预计输出", value: model.previewBytes.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "—")
                    Metric(label: "输出尺寸", value: model.previewDimensions.map { "\($0.width)×\($0.height)" } ?? "—")
                    Metric(label: "质量", value: model.previewQuality.map(String.init) ?? "—")
                }
                if let error = model.previewError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }
    }
}

private struct BeforeAfterImage: View {
    let source: NSImage
    let output: NSImage?
    @Binding var divider: Double
    let zoom: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let x = geometry.size.width * divider
            ZStack {
                Image(nsImage: source).resizable().scaledToFit().scaleEffect(zoom)
                if let output {
                    Image(nsImage: output)
                        .resizable().scaledToFit().scaleEffect(zoom)
                        .mask(alignment: .leading) {
                            HStack(spacing: 0) { Color.clear.frame(width: x); Rectangle() }
                        }
                }
                Rectangle().fill(.white).shadow(color: .black.opacity(0.5), radius: 2).frame(width: 2).position(x: x, y: geometry.size.height / 2)
                Circle().fill(.white).shadow(radius: 2).frame(width: 28, height: 28).overlay(Image(systemName: "arrow.left.and.right").foregroundStyle(.black).font(.caption)).position(x: x, y: geometry.size.height / 2)
                VStack { HStack { Text("原图").padding(6).background(.regularMaterial, in: Capsule()); Spacer(); Text("输出").padding(6).background(.regularMaterial, in: Capsule()) }; Spacer() }.padding(12)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { divider = min(1, max(0, $0.location.x / max(1, geometry.size.width))) })
            .accessibilityIdentifier("preview.comparison")
            .accessibilityLabel("原图与输出效果对比")
            .accessibilityValue("分割位置 \(Int(divider * 100))%")
        }
        .padding(16)
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
