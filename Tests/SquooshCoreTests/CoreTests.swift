import Foundation
import XCTest
@testable import SquooshCore

final class CoreTests: XCTestCase {
    func testValidatesBuiltInPresets() throws {
        for preset in CompressionPreset.builtIns { try PresetValidator.validate(preset) }
    }

    func testRejectsInvalidTargetPreset() {
        var preset = CompressionPreset.webJPEG150KB
        preset.output.safetyTargetBytes = 160_000
        XCTAssertThrowsError(try PresetValidator.validate(preset))
    }

    func testFixedQualityDoesNotValidateUnusedMinimumQuality() throws {
        var preset = CompressionPreset.websiteJPEG
        preset.output.quality = 10
        preset.output.minimumQuality = 35
        XCTAssertNoThrow(try PresetValidator.validate(preset))
    }

    func testTargetSizeRejectsMinimumQualityAboveInitialQuality() {
        var preset = CompressionPreset.webJPEG150KB
        preset.output.quality = 20
        preset.output.minimumQuality = 35
        XCTAssertThrowsError(try PresetValidator.validate(preset)) { error in
            XCTAssertEqual(error.localizedDescription, "预设无效：最低质量不能高于初始质量")
        }
    }

    func testPresetNotesRoundTripAndLegacyDecode() throws {
        var preset = CompressionPreset.websiteJPEG
        preset.notes = "商品详情页图片"
        let encoded = try PresetValidator.encode(preset)
        XCTAssertEqual(try PresetValidator.decode(encoded).notes, "商品详情页图片")

        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "notes")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        XCTAssertNil(try PresetValidator.decode(legacyData).notes)
    }

    func testTargetSearchChoosesHighestMeasuredQuality() throws {
        let result = try TargetSizeSearch.highestQuality(initialQuality: 75, minimumQuality: 35, targetBytes: 145, maximumAttempts: 8) { quality in
            Data(repeating: 0, count: quality * 2)
        }
        XCTAssertEqual(result.quality, 72)
        XCTAssertEqual(result.byteCount, 144)
    }

    func testTargetSearchFailsWhenMinimumCannotFit() {
        XCTAssertThrowsError(try TargetSizeSearch.highestQuality(initialQuality: 75, minimumQuality: 35, targetBytes: 10, maximumAttempts: 8) { quality in
            Data(repeating: 0, count: quality)
        }) { error in
            XCTAssertEqual(error as? SquooshProError, .targetNotMet)
        }
    }

    func testPathsAreSanitizedAndUniqued() {
        XCTAssertEqual(PathSafety.sanitizedFileStem("../bad:name"), "..-bad-name")
        let directory = URL(fileURLWithPath: "/tmp/result")
        let result = PathSafety.uniqueOutputURL(directory: directory, sourceName: "照片.jpg", suffix: "", extension: "jpg") { $0 == "照片.jpg" }
        XCTAssertEqual(result.lastPathComponent, "照片-1.jpg")
    }

    func testTimestampDirectoriesAreCollisionSafe() {
        let date = Date(timeIntervalSince1970: 0)
        let base = PathSafety.timestampDirectoryName(date: date)
        let next = PathSafety.timestampDirectoryName(date: date, existingNames: [base, "\(base)-2"])
        XCTAssertEqual(next, "\(base)-3")
    }

    func testJobAndFileStatesRejectInvalidTransitions() throws {
        var job = JobStateMachine()
        try job.transition(to: .ready)
        try job.transition(to: .running)
        XCTAssertThrowsError(try job.transition(to: .draft))
        var file = FileStateMachine()
        try file.transition(to: .reading)
        XCTAssertThrowsError(try file.transition(to: .committing))
    }

    func testResizePreservesAspectRatioAndDoesNotUpscale() {
        let processor = ImageProcessor()
        let source = ImageDimensions(width: 4000, height: 3000)
        XCTAssertEqual(processor.targetDimensions(source: source, resize: .init(mode: .fixedWidth, width: 1000)), ImageDimensions(width: 1000, height: 750))
        XCTAssertEqual(processor.targetDimensions(source: .init(width: 640, height: 480), resize: .init(mode: .fixedWidth, width: 1000)), ImageDimensions(width: 640, height: 480))
    }

    func testFingerprintDetectsChanges() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("input.bin")
        try Data("first".utf8).write(to: file)
        let fingerprint = try SourceFingerprint.capture(url: file)
        try fingerprint.verifyUnchanged()
        try Data("changed".utf8).write(to: file)
        XCTAssertThrowsError(try fingerprint.verifyUnchanged()) { error in
            XCTAssertEqual(error as? SquooshProError, .sourceChanged)
        }
    }
}
