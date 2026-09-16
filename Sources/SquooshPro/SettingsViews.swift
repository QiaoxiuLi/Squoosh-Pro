import SquooshCore
import SwiftUI

struct CompressionSettingsPane: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingSavePreset = false

    private var presetID: Binding<String> {
        Binding(get: { model.selectedPreset.id }, set: { id in
            if let preset = (model.systemPresets + model.userPresets).first(where: { $0.id == id }) { model.selectPreset(preset) }
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("压缩设置").font(.headline)
                GroupBox("用途") {
                    Picker("用途", selection: presetID) {
                        Section("系统预设") { ForEach(model.systemPresets) { Text($0.name).tag($0.id) } }
                        if !model.userPresets.isEmpty { Section("我的预设") { ForEach(model.userPresets) { Text($0.name).tag($0.id) } } }
                    }.labelsHidden().accessibilityIdentifier("settings.purpose")
                }.frame(maxWidth: .infinity, alignment: .leading)
                GroupBox("输出格式") {
                    Picker("输出格式", selection: $model.selectedPreset.output.format) {
                        ForEach(CodecFormat.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden().onChange(of: model.selectedPreset.output.format) { _ in model.settingsDidChange() }.accessibilityIdentifier("settings.format")
                }.frame(maxWidth: .infinity, alignment: .leading)
                GroupBox("大小或质量") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("策略", selection: $model.selectedPreset.output.strategy) {
                            Text("指定质量").tag(CompressionStrategy.fixedQuality)
                            Text("每张不超过指定大小").tag(CompressionStrategy.targetBytes)
                        }.labelsHidden().pickerStyle(.radioGroup).onChange(of: model.selectedPreset.output.strategy) { _ in model.settingsDidChange() }
                        if model.selectedPreset.output.strategy == .fixedQuality {
                            HStack { Slider(value: quality, in: 0...100, step: 1); Text("\(model.selectedPreset.output.quality)").monospacedDigit().frame(width: 32) }
                                .accessibilityIdentifier("settings.quality")
                        } else {
                            HStack {
                                TextField("大小", value: targetKilobytes, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                    .accessibilityIdentifier("settings.targetSizeKB")
                                Text("KB")
                            }
                            Text("每张图片都会单独控制大小，1 KB 按 1000 字节计算。")
                                .font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(.vertical, 4)
                }.frame(maxWidth: .infinity, alignment: .leading)
                GroupBox("图片尺寸") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("模式", selection: $model.selectedPreset.resize.mode) {
                            Text("保持原尺寸").tag(ResizeMode.original)
                            Text("最长边").tag(ResizeMode.longestEdge)
                            Text("固定宽度").tag(ResizeMode.fixedWidth)
                            Text("固定高度").tag(ResizeMode.fixedHeight)
                            Text("适合指定范围").tag(ResizeMode.fitBox)
                            Text("自动选择宽度").tag(ResizeMode.adaptiveWidth)
                        }.onChange(of: model.selectedPreset.resize.mode) { _ in model.settingsDidChange() }.accessibilityIdentifier("settings.resizeMode")
                        sizeFields
                        Toggle("小图片保持原尺寸", isOn: noUpscale).accessibilityIdentifier("settings.noUpscale")
                        Text("开启后，尺寸已经更小的图片不会被放大。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }.padding(.vertical, 4)
                }.frame(maxWidth: .infinity, alignment: .leading)
                GroupBox("输出位置") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.outputParent?.path ?? "默认：在原图旁创建带时间的文件夹").font(.callout).foregroundStyle(.secondary).lineLimit(3).truncationMode(.middle)
                        Button("选择位置…") { model.chooseOutputParent() }.accessibilityIdentifier("settings.outputDirectory")
                    }.padding(.vertical, 4)
                }.frame(maxWidth: .infinity, alignment: .leading)
                GroupBox("高级设置（始终生效）") {
                    DisclosureGroup(model.showAdvanced ? "收起高级设置" : "展开高级设置", isExpanded: $model.showAdvanced) { AdvancedSettings().padding(.top, 12) }
                        .accessibilityIdentifier("settings.advanced")
                        .padding(.vertical, 4)
                    Text("展开或收起只改变显示，已设置选项始终应用。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                SummaryCard()
                Button {
                    showingSavePreset = true
                } label: {
                    Label("保存为预设", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("settings.savePreset")
            }.padding(14)
        }
        .font(.body)
        .controlSize(.large)
        .disabled(model.isRunning)
        .onChange(of: model.selectedPreset.output.quality) { _ in model.settingsDidChange() }
        .sheet(isPresented: $showingSavePreset) {
            SavePresetSheet(defaultName: model.selectedPreset.name)
                .environmentObject(model)
        }
    }

    private var quality: Binding<Double> {
        Binding(
            get: { Double(max(0, min(100, model.selectedPreset.output.quality))) },
            set: { model.selectedPreset.output.quality = max(0, min(100, Int($0.rounded()))) }
        )
    }
    private var targetKilobytes: Binding<Int> {
        Binding(get: { max(1, ((model.selectedPreset.output.targetBytes ?? 150_000) + 999) / 1_000) }, set: {
            let kilobytes = max(1, min(1_000_000, $0))
            let bytes = kilobytes * 1_000
            model.selectedPreset.output.targetBytes = bytes
            model.selectedPreset.output.safetyTargetBytes = max(1, bytes - min(5_000, bytes / 20))
            model.settingsDidChange()
        })
    }
    private var noUpscale: Binding<Bool> {
        Binding(get: { !model.selectedPreset.resize.allowUpscale }, set: { model.selectedPreset.resize.allowUpscale = !$0; model.settingsDidChange() })
    }

    @ViewBuilder private var sizeFields: some View {
        switch model.selectedPreset.resize.mode {
        case .longestEdge:
            LabeledContent("最长边") { TextField("px", value: optionalInt(\.longestEdge, fallback: 1920), format: .number).frame(width: 80) }
        case .fixedWidth:
            LabeledContent("宽度") { TextField("px", value: optionalInt(\.width, fallback: 1000), format: .number).frame(width: 80) }
        case .fixedHeight:
            LabeledContent("高度") { TextField("px", value: optionalInt(\.height, fallback: 1000), format: .number).frame(width: 80) }
        case .fitBox:
            VStack(alignment: .leading, spacing: 8) {
                HStack { TextField("宽", value: optionalInt(\.width, fallback: 1920), format: .number); Text("×"); TextField("高", value: optionalInt(\.height, fallback: 1080), format: .number) }
                Text("完整保留图片，不会裁切；宽和高都不会超过这里的数值。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .adaptiveWidth:
            Text("会从 \(model.selectedPreset.resize.candidateWidths.map(String.init).joined(separator: "、")) px 中选择能满足大小限制的最大宽度。")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        case .original: EmptyView()
        }
    }

    private func optionalInt(_ path: WritableKeyPath<ResizeOptions, Int?>, fallback: Int) -> Binding<Int> {
        Binding(get: { model.selectedPreset.resize[keyPath: path] ?? fallback }, set: { model.selectedPreset.resize[keyPath: path] = max(1, $0); model.settingsDidChange() })
    }
}

private struct AdvancedSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("元数据", selection: $model.selectedPreset.metadata.policy) {
                Text("删除隐私信息").tag(MetadataPolicy.stripPrivate)
                Text("删除所有信息").tag(MetadataPolicy.stripAll)
                Text("保留常用信息").tag(MetadataPolicy.preserveSafe)
                Text("保留全部信息").tag(MetadataPolicy.preserveAll)
            }.onChange(of: model.selectedPreset.metadata.policy) { _ in model.settingsDidChange() }
            LabeledContent("色彩空间", value: "sRGB")
            if model.selectedPreset.output.format == .mozjpeg || model.selectedPreset.output.format == .automatic {
                LabeledContent("透明区域", value: "自动填充为白色")
                explainedToggle(
                    "渐进式显示",
                    isOn: progressiveOption,
                    explanation: "使用 Progressive JPEG。网页加载时会先显示整张图片的粗略版本，再逐步变清晰；画质不变，文件大小可能略有变化，主流浏览器均支持。"
                )
                explainedToggle(
                    "优化文件大小",
                    isOn: option("optimizeCoding", default: true),
                    explanation: "使用 MozJPEG 优化图片内部的数据编码，在相同质量下通常能减小文件；压缩会稍慢，不会改变图片尺寸。"
                )
                explainedToggle(
                    "标准兼容模式",
                    isOn: baselineOption,
                    explanation: "输出 Baseline JPEG，图片会从上到下一次加载完成，不使用渐进式显示。适合非常老旧的软件；现代浏览器和手机通常不需要开启。"
                )
                LabeledContent("最低质量") { Stepper("\(model.selectedPreset.output.minimumQuality)", value: integerOutputOption(\.minimumQuality), in: 0...100) }
                LabeledContent("质量搜索次数") { Stepper("\(model.selectedPreset.output.maximumSearchAttempts)", value: integerOutputOption(\.maximumSearchAttempts), in: 1...16) }
            } else if model.selectedPreset.output.format == .oxipng {
                LabeledContent("PNG 压缩级别") { Stepper("\(Int(model.selectedPreset.formatOptions["level"] ?? 2))", value: numberOption("level", default: 2), in: 0...6) }
                Toggle("交错显示", isOn: option("interlace", default: false))
            } else if model.selectedPreset.output.format == .webp {
                Toggle("无损", isOn: option("lossless", default: false))
                LabeledContent("压缩强度") { Stepper("\(Int(model.selectedPreset.formatOptions["method"] ?? 4))", value: numberOption("method", default: 4), in: 0...6) }
                Toggle("增强清晰度", isOn: option("sharpYUV", default: false))
            } else if model.selectedPreset.output.format == .avif {
                LabeledContent("处理速度") { Stepper("\(Int(model.selectedPreset.formatOptions["speed"] ?? 6))", value: numberOption("speed", default: 6), in: 0...10) }
                Text("AVIF 处理时间较长。").font(.callout).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func explainedToggle(_ title: String, isOn: Binding<Bool>, explanation: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Toggle(title, isOn: isOn)
            Spacer(minLength: 8)
            SettingInfoButton(title: title, explanation: explanation)
        }
    }

    private var progressiveOption: Binding<Bool> {
        Binding(
            get: { (model.selectedPreset.formatOptions["progressive"] ?? 1) != 0 },
            set: {
                model.selectedPreset.formatOptions["progressive"] = $0 ? 1 : 0
                if $0 { model.selectedPreset.formatOptions["baseline"] = 0 }
                model.settingsDidChange()
            }
        )
    }

    private var baselineOption: Binding<Bool> {
        Binding(
            get: { (model.selectedPreset.formatOptions["baseline"] ?? 0) != 0 },
            set: {
                model.selectedPreset.formatOptions["baseline"] = $0 ? 1 : 0
                if $0 { model.selectedPreset.formatOptions["progressive"] = 0 }
                model.settingsDidChange()
            }
        )
    }

    private func option(_ name: String, default fallback: Bool) -> Binding<Bool> {
        Binding(get: { (model.selectedPreset.formatOptions[name] ?? (fallback ? 1 : 0)) != 0 }, set: { model.selectedPreset.formatOptions[name] = $0 ? 1 : 0; model.settingsDidChange() })
    }
    private func numberOption(_ name: String, default fallback: Double) -> Binding<Int> {
        Binding(get: { Int(model.selectedPreset.formatOptions[name] ?? fallback) }, set: { model.selectedPreset.formatOptions[name] = Double($0); model.settingsDidChange() })
    }
    private func integerOutputOption(_ path: WritableKeyPath<OutputOptions, Int>) -> Binding<Int> {
        Binding(get: { model.selectedPreset.output[keyPath: path] }, set: { model.selectedPreset.output[keyPath: path] = $0; model.settingsDidChange() })
    }
}

private struct SettingInfoButton: View {
    let title: String
    let explanation: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("说明", systemImage: "info.circle")
        }
        .buttonStyle(.borderless)
        .controlSize(.regular)
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(explanation).font(.body).fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 320, alignment: .leading)
        }
    }
}

private struct SummaryCard: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("输出为 \(model.selectedPreset.output.format.displayName)", systemImage: "checkmark.circle")
            if model.selectedPreset.output.strategy == .targetBytes {
                Label("每张不超过 \((model.selectedPreset.output.targetBytes ?? 0) / 1_000) KB", systemImage: "externaldrive.badge.checkmark")
            }
        }
        .font(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SavePresetSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var notes = ""
    @State private var errorMessage: String?

    init(defaultName: String) {
        _name = State(initialValue: "\(defaultName) 副本")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("保存预设").font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 8) {
                Text("预设名称").font(.headline)
                TextField("例如：商品图 150 KB", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("savePreset.name")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("备注（可选）").font(.headline)
                TextField("说明这个预设适合什么图片", text: $notes)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("savePreset.notes")
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存预设") {
                    do {
                        try model.saveUserPreset(name: name, notes: notes)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("savePreset.confirm")
            }
        }
        .font(.body)
        .controlSize(.large)
        .padding(24)
        .frame(width: 460)
    }
}

struct BatchSummaryBar: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { summaryContent; Spacer(); sizeSummary }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) { summaryContent }
                    HStack { sizeSummary; Spacer() }
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder private var summaryContent: some View {
        if model.isRunning {
            ProgressView(value: model.progress).frame(maxWidth: 150).accessibilityIdentifier("batch.progress")
            Text("\(model.completedCount)/\(model.items.count) 已完成")
        } else if model.completedCount == 0 && model.failedCount == 0 {
            Label("已选择“\(model.selectedPreset.name)”", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text("点击“开始压缩”")
        } else {
            Text("\(model.completedCount)/\(model.items.count) 已完成")
            if model.failedCount > 0 {
                Text("\(model.failedCount) 失败").foregroundStyle(.red)
                Button("重试失败项") { model.retryFailures() }
            }
        }
    }

    @ViewBuilder private var sizeSummary: some View {
        if model.totalOutputBytes > 0 {
            Text("\(ByteCountFormatter.string(fromByteCount: model.totalInputBytes, countStyle: .file)) → \(ByteCountFormatter.string(fromByteCount: model.totalOutputBytes, countStyle: .file))")
                .monospacedDigit().foregroundStyle(.secondary)
        } else {
            Text("已添加 \(ByteCountFormatter.string(fromByteCount: model.totalInputBytes, countStyle: .file))")
                .monospacedDigit().foregroundStyle(.secondary)
        }
        if model.currentOutputDirectory != nil {
            Button("打开输出目录") { model.revealOutput() }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("batch.openOutput")
        }
    }
}
