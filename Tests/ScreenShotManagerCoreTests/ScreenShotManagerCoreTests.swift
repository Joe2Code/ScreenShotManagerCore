import XCTest
@testable import ScreenShotManagerCore

final class ScreenShotManagerCoreTests: XCTestCase {
    func testCoreImageStorageInit() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let screenshots = tempDir.appendingPathComponent("TestScreenshots")
        let thumbnails = tempDir.appendingPathComponent("TestThumbnails")

        let storage = CoreImageStorage(
            screenshotsDirectory: screenshots,
            thumbnailsDirectory: thumbnails
        )

        XCTAssertEqual(storage.localImageCount(), 0)
        XCTAssertEqual(storage.totalStorageUsed(), 0)

        // Cleanup
        try? FileManager.default.removeItem(at: screenshots)
        try? FileManager.default.removeItem(at: thumbnails)
    }

    func testSanitizedFilename() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let storage = CoreImageStorage(
            screenshotsDirectory: tempDir.appendingPathComponent("S"),
            thumbnailsDirectory: tempDir.appendingPathComponent("T")
        )

        let result = storage.sanitizedFilename(from: "ABC123/L0/001")
        XCTAssertEqual(result, "ABC123_L0_001")

        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("S"))
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("T"))
    }
}
