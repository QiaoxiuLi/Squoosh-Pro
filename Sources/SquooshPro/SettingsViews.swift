import SquooshCore
import SwiftUI

struct CompressionSettingsPane: View {
    @EnvironmentObject private var model: AppModel

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
                }
                GroupBox("输出格式") {
                    Picker("输出格式", selection: $model.selectedPreset.output.format) {
                        ForEach(CodecFormat.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden().onChange(of: model.selectedPreset.output.format) { _ in model.schedulePreview() }.accessibilityIdentifier("settings.format")
                }
                GroupBox("大小或质量") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("策略", selection: $model.selectedPreset.output.strategy) {
                            Text("指定质量").tag(CompressionStrategy.fixedQuality)
                            Text("每张不超过指定大小").tag(CompressionStrategy.targetBytes)
                        }.labelsHidden().pickerStyle(.radioGroup).onChange(of: model.selectedPreset.output.strategy) { _ in model.schedulePreview() }
                        if model.selectedPreset.output.strategy == .fixedQuality {
                            HStack { Slider(value: quality, in: 0...100, step: 1); Text("\(model.selectedPreset.output.quality)").monospacedDigit().frame(width: 32) }
                                .accessibilityIdentifier("settings.quality")
                        } else {
                            HStack {
                                TextField("字节", value: targetBytes, format: .number).textFieldStyle(.roundedBorder).frame(width: 100).accessibilityIdentifier("settings.targetBytes")
                                Text("bytes")
                            }
                            Text("每张图片都会单独控制大小。")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(.vertical, 4)
                }
                GroupBox("图片尺寸") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("模式", selection: $model.selectedPreset.resize.mode) {
                            Text("保持原尺寸").tag(ResizeMode.original)
                            Text("最长边").tag(ResizeMode.longestEdge)
                            Text("固定宽度").tag(ResizeMode.fixedWidth)
                            Text("固定高度").tag(ResizeMode.fixedHeight)
                            Text("限制在边框内").tag(ResizeMode.fitBox)
                            Text("自适应宽度").tag(ResizeMode.adaptiveWidth)
                        }.onChange(of: model.selectedPreset.resize.mode) { _ in model.schedulePreview() }.accessibilityIdentifier("settings.resizeMode")
                        sizeFields
                        Toggle("不放大小图片", isOn: noUpscale).accessibilityIdentifier("settings.noUpscale")
                    }.padding(.vertical, 4)
                }
                GroupBox("输出位置") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.outputParent?.path ?? "默认：在原图旁创建带时间的文件夹").font(.caption).foregroundStyle(.secondary).lineLimit(3).truncationMode(.middle)
                        Button("选择位置…") { model.chooseOutputParent() }.accessibilityIdentifier("settings.outputDirectory")
                    }.padding(.vertical, 4)
                }
                DisclosureGroup("高级设置", isExpanded: $model.showAdvanced) { AdvancedSettings().padding(.top, 12) }
                    .accessibilityIdentifier("settings.advanced")
                SummaryCard()
            }.padding(14)
        }
        .disabled(model.isRunning)
        .onChange(of: model.selectedPreset.output.quality) { _ in model.schedulePreview() }
    }

    private var quality: Binding<Double> {
        Binding(get: { Double(model.selectedPreset.output.quality) }, set: { model.selectedPreset.output.quality = Int($0) })
    }
    private var targetBytes: Binding<Int> {
        Binding(get: { model.selectedPreset.output.targetBytes ?? 150_000 }, set: {
            model.selectedPreset.output.targetBytes = max(1, $0)
            model.selectedPreset.output.safetyTargetBytes = min(model.selectedPreset.output.safetyTargetBytes ?? $0, $0)
            model.schedulePreview()
        })
    }
    private var noUpscale: Binding<Bool> {
        Binding(get: { !model.selectedPreset.resize.allowUpscale }, set: { model.selectedPreset.resize.allowUpscale = !$0; model.schedulePreview() })
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
            HStack { TextField("宽", value: optionalInt(\.width, fallback: 1920), format: .number); Text("×"); TextField("高", value: optionalInt(\.height, fallback: 1080), format: .number) }
        case .adaptiveWidth:
            Text("候选宽度：\(model.selectedPreset.resize.candidateWidths.map(String.init).joined(separator: "、")) px").font(.caption).foregroundStyle(.secondary)
        case .original: EmptyView()
        }
    }

    private func optionalInt(_ path: WritableKeyPath<ResizeOptions, Int?>, fallback: Int) -> Binding<Int> {
        Binding(get: { model.selectedPreset.resize[keyPath: path] ?? fallback }, set: { model.selectedPreset.resize[keyPath: path] = max(1, $0); model.schedulePreview() })
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
            }
            LabeledContent("色彩空间", value: "sRGB")
            if model.selectedPreset.output.format == .mozjpeg || model.selectedPreset.output.format == .automatic {
                ColorPicker("透明区域背景", selection: .constant(Color.white)).disabled(true)
                Toggle("渐进式显示", isOn: option("progressive", default: true))
                Toggle("优化文件大小", isOn: option("optimizeCoding", default: true))
                Toggle("标准兼容模式", isOn: option("baseline", default: false))
                LabeledContent("最低质量") { Stepper("\(model.selectedPreset.output.minimumQuality)", value: $model.selectedPreset.output.minimumQuality, in: 0...100) }
                LabeledContent("质量搜索次数") { Stepper("\(model.selectedPreset.output.maximumSearchAttempts)", value: $model.selectedPreset.output.maximumSearchAttempts, in: 1...16) }
            } else if model.selectedPreset.output.format == .oxipng {
                LabeledContent("PNG 压缩级别") { Stepper("\(Int(model.selectedPreset.formatOptions["level"] ?? 2))", value: numberOption("level", default: 2), in: 0...6) }
                Toggle("交错显示", isOn: option("interlace", default: false))
            } else if model.selectedPreset.output.format == .webp {
                Toggle("无损", isOn: option("lossless", default: false))
                LabeledContent("压缩强度") { Stepper("\(Int(model.selectedPreset.formatOptions["method"] ?? 4))", value: numberOption("method", default: 4), in: 0...6) }
                Toggle("增强清晰度", isOn: option("sharpYUV", default: false))
            } else if model.selectedPreset.output.format == .avif {
                LabeledContent("处理速度") { Stepper("\(Int(model.selectedPreset.formatOptions["speed"] ?? 6))", value: numberOption("speed", default: 6), in: 0...10) }
                Text("AVIF 处理时间较长。").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func option(_ name: String, default fallback: Bool) -> Binding<Bool> {
        Binding(get: { (model.selectedPreset.formatOptions[name] ?? (fallback ? 1 : 0)) != 0 }, set: { model.selectedPreset.formatOptions[name] = $0 ? 1 : 0; model.schedulePreview() })
    }
    private func numberOption(_ name: String, default fallback: Double) -> Binding<Int> {
        Binding(get: { Int(model.selectedPreset.formatOptions[name] ?? fallback) }, set: { model.selectedPreset.formatOptions[name] = Double($0); model.schedulePreview() })
    }
}

private struct SummaryCard: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("输出为 \(model.selectedPreset.output.format.displayName)", systemImage: "checkmark.circle")
            if model.selectedPreset.output.strategy == .targetBytes { Label("每张不超过 \(model.selectedPreset.output.targetBytes ?? 0) bytes", systemImage: "externaldrive.badge.checkmark") }
        }
        .font(.caption)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
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
