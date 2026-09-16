import SquooshCore
import SwiftUI

struct PresetsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var message: String?

    var body: some View {
        Form {
            Section("系统预设") {
                ForEach(model.systemPresets) { preset in presetRow(preset) }
            }
            Section("我的预设") {
                if model.userPresets.isEmpty { Text("尚未保存自定义预设").foregroundStyle(.secondary) }
                ForEach(model.userPresets) { preset in presetRow(preset) }
            }
            Section("导入与导出") {
                ViewThatFits(in: .horizontal) {
                    HStack { presetActionButtons }
                    VStack(alignment: .leading) { presetActionButtons }
                }
                if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("预设")
    }

    private func presetRow(_ preset: CompressionPreset) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack { presetDescription(preset); Spacer(); presetActions(preset) }
            VStack(alignment: .leading, spacing: 8) {
                presetDescription(preset)
                HStack { Spacer(); presetActions(preset) }
            }
        }
    }

    @ViewBuilder private var presetActionButtons: some View {
        Button("导入预设…") { do { try model.importPreset(); message = "已导入" } catch { message = error.localizedDescription } }
        Button("导出我的预设…") { do { try model.exportUserPresets(); message = "已导出全部自定义预设" } catch { message = error.localizedDescription } }
            .disabled(model.userPresets.isEmpty)
            .accessibilityIdentifier("presets.exportUserPresets")
    }

    private func presetDescription(_ preset: CompressionPreset) -> some View {
        VStack(alignment: .leading) {
            Text(preset.name)
            Text("\(preset.output.format.displayName) · \(preset.output.strategy == .targetBytes ? "严格大小" : "固定质量")")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let notes = preset.notes, !notes.isEmpty {
                Text(notes).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func presetActions(_ preset: CompressionPreset) -> some View {
        HStack {
            if model.selectedPreset.id == preset.id {
                Label("已选择", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            } else {
                Button("选择") { model.selectPreset(preset); model.section = .compress }
            }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.history.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clock").font(.largeTitle).foregroundStyle(.secondary)
                    Text("暂无任务历史").font(.headline)
                    Text("完成压缩后，任务报告会显示在这里。").foregroundStyle(.secondary)
                    Spacer()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.history) { job in
                    ViewThatFits(in: .horizontal) {
                        HStack { historyDescription(job); Spacer(); historyActions(job) }
                        VStack(alignment: .leading, spacing: 4) {
                            historyDescription(job)
                            historyActions(job)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            if let message = model.recoveryMessage {
                Text(message).font(.caption).foregroundStyle(.secondary).padding(10)
            }
        }.navigationTitle("历史记录")
    }

    private func stateText(_ state: JobState) -> String {
        switch state {
        case .completed: return "已完成"
        case .completedWithErrors: return "部分失败"
        case .cancelled: return "已取消"
        case .failed: return "失败"
        case .paused, .pausing: return "已暂停"
        default: return "未完成"
        }
    }

    private func historyDescription(_ job: JobManifest) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(job.outputDirectoryName).font(.headline)
            Text(job.createdAt.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func historyActions(_ job: JobManifest) -> some View {
        HStack {
            Text(job.preset.name).foregroundStyle(.secondary)
            Text(stateText(job.state))
            if model.canResume(job.id) {
                Button("恢复") { model.resume(job.id) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("history.resume.\(job.id.uuidString)")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ApplicationSettingsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Form {
            Section("文件夹") {
                Toggle("添加文件夹时包含子文件夹", isOn: $model.recursiveFolders).accessibilityIdentifier("appSettings.recursive")
            }
            Section("性能") {
                Toggle("硬件加速预览", isOn: hardwareAcceleration)
                    .accessibilityIdentifier("appSettings.hardwareAcceleration")
                Text(model.hardwareAccelerationStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section("隐私与安全") {
                Label("图片只在本机处理，原图不会被修改", systemImage: "lock.shield")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section("格式支持") { Text(model.workerStatus).fixedSize(horizontal: false, vertical: true) }
            if model.recoveredJobCount > 0 {
                Section("恢复") {
                    Label("发现 \(model.recoveredJobCount) 个可恢复任务。可在历史记录中继续未完成文件。", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                        .fixedSize(horizontal: false, vertical: true)
                    if let message = model.recoveryMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
            }
            Section("版本") {
                LabeledContent("Squoosh Pro", value: "0.1.0")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }

    private var hardwareAcceleration: Binding<Bool> {
        Binding(
            get: { model.hardwareAccelerationEnabled },
            set: { model.setHardwareAccelerationEnabled($0) }
        )
    }
}
