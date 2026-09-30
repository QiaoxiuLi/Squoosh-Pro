import Foundation
import ImageIO

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2 else {
    fatalError("Usage: swift write-ico.swift <output.ico> <size.png> ...")
}

let frames = try arguments.dropFirst().map { path -> (Int, Data) in
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width == image.height, (1...256).contains(image.width),
          data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) else {
        fatalError("ICO frames must be square PNG images of at most 256 pixels: \(path)")
    }
    return (image.width, data)
}
guard Set(frames.map { $0.0 }).count == frames.count else {
    fatalError("ICO frame sizes must be unique")
}

func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
    var value = value.littleEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}

// ICO directory entries point to the original lossless PNG payloads.
var result = littleEndian(UInt16(0)) + littleEndian(UInt16(1)) + littleEndian(UInt16(frames.count))
var offset = 6 + 16 * frames.count
for (size, data) in frames {
    let dimension = UInt8(size == 256 ? 0 : size)
    result.append(contentsOf: [dimension, dimension, 0, 0])
    result.append(littleEndian(UInt16(1)))
    result.append(littleEndian(UInt16(32)))
    result.append(littleEndian(UInt32(data.count)))
    result.append(littleEndian(UInt32(offset)))
    offset += data.count
}
for (_, data) in frames { result.append(data) }
try result.write(to: URL(fileURLWithPath: arguments[0]), options: .atomic)
print("ICO frames: \(frames.map { String($0.0) }.joined(separator: ", "))")
