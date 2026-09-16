import AppKit
import SwiftUI

@main
struct SquooshProApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Squoosh Pro") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 720, minHeight: 480)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    model.shutdown()
                }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加图片…") { model.chooseImages() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("添加文件夹…") { model.chooseFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandMenu("压缩") {
                Button("开始压缩") { model.startBatch() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(model.items.isEmpty || model.isRunning)
                Button(model.isPaused ? "继续" : "暂停") { model.pauseOrResume() }
                    .keyboardShortcut("p", modifiers: [.command, .option])
                    .disabled(!model.isRunning)
                Button("取消任务") { model.cancel() }
                    .keyboardShortcut(".", modifiers: [.command])
                    .disabled(!model.isRunning)
            }
        }
    }
}
