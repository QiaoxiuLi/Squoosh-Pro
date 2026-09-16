import Darwin
import Foundation
import SquooshCore

@MainActor
public final class NativeAVIFCodecHost {
    private var processes: [UUID: Process] = [:]

    public init() {}

    public func encode(sourceURL: URL, preset: CompressionPreset, requestID: UUID) async throws -> Data {
        guard preset.output.format == .avif else { throw SquooshProError.unsupportedFormat }
        let process = Process()
        process.executableURL = try workerExecutableURL()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        let request = NativeCodecWorkerRequest(sourcePath: sourceURL.path, preset: preset)
        let requestData = try JSONEncoder().encode(request)
        processes[requestID] = process
        defer { processes.removeValue(forKey: requestID) }

        return try await withTaskCancellationHandler {
            do { try process.run() }
            catch { throw SquooshProError.workerCrashed }
            inputPipe.fileHandleForWriting.write(requestData)
            try? inputPipe.fileHandleForWriting.close()

            async let outputData = Task.detached { try outputPipe.fileHandleForReading.readToEnd() ?? Data() }.value
            async let errorData = Task.detached { try errorPipe.fileHandleForReading.readToEnd() ?? Data() }.value
            let status = await Task.detached {
                process.waitUntilExit()
                return process.terminationStatus
            }.value
            let (output, diagnostics) = try await (outputData, errorData)
            if Task.isCancelled { throw SquooshProError.cancelled }
            guard status == 0, !output.isEmpty else {
                let detail = String(data: diagnostics, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                throw detail.map(SquooshProError.unknown) ?? SquooshProError.encodeFailed
            }
            return output
        } onCancel: {
            Task { @MainActor [weak self] in await self?.cancel(requestID: requestID) }
        }
    }

    public func cancel(requestID: UUID) async {
        guard let process = processes[requestID], process.isRunning else { return }
        process.terminate()
        let processID = process.processIdentifier
        Task.detached {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if process.isRunning { Darwin.kill(processID, SIGKILL) }
        }
    }

    public func shutdown() async {
        let identifiers = Array(processes.keys)
        for identifier in identifiers { await cancel(requestID: identifier) }
    }

    private func workerExecutableURL() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["SQUOOSH_NATIVE_CODEC_WORKER"], !override.isEmpty {
            let url = URL(fileURLWithPath: override)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }
        if let appURL = Bundle.main.executableURL {
            let helper = appURL.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Helpers/SquooshNativeCodecWorker")
            if FileManager.default.isExecutableFile(atPath: helper.path) { return helper }
            let sibling = appURL.deletingLastPathComponent().appendingPathComponent("SquooshNativeCodecWorker")
            if FileManager.default.isExecutableFile(atPath: sibling.path) { return sibling }
        }
        throw SquooshProError.workerCrashed
    }
}
