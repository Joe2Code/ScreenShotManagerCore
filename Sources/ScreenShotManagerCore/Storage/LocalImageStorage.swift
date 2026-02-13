import Foundation

/// Core image storage operations shared between iOS and macOS.
/// Platform-specific apps extend this with their own import/migration logic.
public class CoreImageStorage {

    // MARK: - Properties

    private let fileManager = FileManager.default
    public let screenshotsDirectory: URL
    public let thumbnailsDirectory: URL

    // MARK: - Initialization

    public init(screenshotsDirectory: URL, thumbnailsDirectory: URL) {
        self.screenshotsDirectory = screenshotsDirectory
        self.thumbnailsDirectory = thumbnailsDirectory

        // Ensure directories exist
        try? fileManager.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Save

    /// Saves image data to the screenshots directory.
    @discardableResult
    public func saveImageData(_ data: Data, filename: String) -> Bool {
        let fileURL = screenshotsDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return true
        } catch {
            print("CoreImageStorage: Failed to save image - \(error)")
            return false
        }
    }

    /// Saves thumbnail data to the thumbnails directory.
    @discardableResult
    public func saveThumbnailData(_ data: Data, filename: String) -> Bool {
        let fileURL = thumbnailsDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return true
        } catch {
            print("CoreImageStorage: Failed to save thumbnail - \(error)")
            return false
        }
    }

    /// Saves a PlatformImage as JPEG to the screenshots directory.
    @discardableResult
    public func saveImage(_ image: PlatformImage, for localIdentifier: String, quality: CGFloat = 0.85) -> String? {
        let filename = sanitizedFilename(from: localIdentifier) + ".jpg"

        guard let data = image.jpegData(quality: quality) else {
            print("CoreImageStorage: Failed to create JPEG data")
            return nil
        }

        return saveImageData(data, filename: filename) ? filename : nil
    }

    /// Saves a PlatformImage as a thumbnail.
    @discardableResult
    public func saveThumbnail(_ image: PlatformImage, for localIdentifier: String, quality: CGFloat = 0.7) -> String? {
        let filename = sanitizedFilename(from: localIdentifier) + "_thumb.jpg"

        guard let data = image.jpegData(quality: quality) else {
            return nil
        }

        return saveThumbnailData(data, filename: filename) ? filename : nil
    }

    // MARK: - Load

    /// Loads an image from the screenshots directory.
    public func loadImage(relativePath: String) -> PlatformImage? {
        let fileURL = screenshotsDirectory.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        #if canImport(UIKit)
        return PlatformImage(contentsOfFile: fileURL.path)
        #elseif canImport(AppKit)
        return PlatformImage(contentsOf: fileURL)
        #endif
    }

    /// Loads a thumbnail for a local identifier.
    public func loadThumbnail(for localIdentifier: String) -> PlatformImage? {
        let filename = sanitizedFilename(from: localIdentifier) + "_thumb.jpg"
        let fileURL = thumbnailsDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        #if canImport(UIKit)
        return PlatformImage(contentsOfFile: fileURL.path)
        #elseif canImport(AppKit)
        return PlatformImage(contentsOf: fileURL)
        #endif
    }

    /// Returns the full URL for a stored image.
    public func imageURL(relativePath: String) -> URL {
        return screenshotsDirectory.appendingPathComponent(relativePath)
    }

    // MARK: - Check Existence

    public func hasLocalImage(for localIdentifier: String) -> Bool {
        let filename = sanitizedFilename(from: localIdentifier) + ".jpg"
        let fileURL = screenshotsDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    public func localImagePath(for localIdentifier: String) -> String? {
        let filename = sanitizedFilename(from: localIdentifier) + ".jpg"
        let fileURL = screenshotsDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fileURL.path) ? filename : nil
    }

    // MARK: - Delete

    public func deleteImage(relativePath: String) {
        let fileURL = screenshotsDirectory.appendingPathComponent(relativePath)
        try? fileManager.removeItem(at: fileURL)

        // Also delete thumbnail
        let thumbFilename = relativePath.replacingOccurrences(of: ".jpg", with: "_thumb.jpg")
        let thumbURL = thumbnailsDirectory.appendingPathComponent(thumbFilename)
        try? fileManager.removeItem(at: thumbURL)
    }

    public func deleteImage(for localIdentifier: String) {
        let filename = sanitizedFilename(from: localIdentifier) + ".jpg"
        deleteImage(relativePath: filename)
    }

    // MARK: - Storage Info

    public func totalStorageUsed() -> Int64 {
        var totalSize: Int64 = 0

        for dir in [screenshotsDirectory, thumbnailsDirectory] {
            if let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        }

        return totalSize
    }

    public func formattedStorageUsed() -> String {
        let bytes = totalStorageUsed()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    public func localImageCount() -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(at: screenshotsDirectory, includingPropertiesForKeys: nil) else {
            return 0
        }
        return contents.filter { $0.pathExtension == "jpg" }.count
    }

    // MARK: - Cleanup

    public func clearAllImages() {
        try? fileManager.removeItem(at: screenshotsDirectory)
        try? fileManager.removeItem(at: thumbnailsDirectory)

        try? fileManager.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    public func cleanupOrphanedImages(validIdentifiers: Set<String>) {
        guard let contents = try? fileManager.contentsOfDirectory(at: screenshotsDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        let validFilenames = Set(validIdentifiers.map { sanitizedFilename(from: $0) + ".jpg" })

        for fileURL in contents where fileURL.pathExtension == "jpg" {
            let filename = fileURL.lastPathComponent
            if !filename.contains("_thumb") && !validFilenames.contains(filename) {
                deleteImage(relativePath: filename)
            }
        }
    }

    // MARK: - Helpers

    public func sanitizedFilename(from localIdentifier: String) -> String {
        return localIdentifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }
}
