import Foundation
import SquooshCore

do {
    let requestData = FileHandle.standardInput.readDataToEndOfFile()
    let request = try JSONDecoder().decode(NativeCodecWorkerRequest.self, from: requestData)
    guard request.preset.output.format == .avif,
          request.preset.output.strategy == .fixedQuality,
          request.sourcePath.hasPrefix("/") else {
        throw SquooshProError.invalidPreset("原生 helper 仅接受绝对路径的固定质量 AVIF 请求")
    }
    let sourceURL = URL(fileURLWithPath: request.sourcePath).resolvingSymlinksInPath().standardizedFileURL
    let result = try ImageProcessor().encode(url: sourceURL, preset: request.preset)
    FileHandle.standardOutput.write(result.data)
} catch {
    let message = ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription) + "\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(1)
}
