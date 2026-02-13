import Foundation

/// Constants shared across iOS and macOS apps.
public enum SharedConstants {

    // MARK: - App Identifiers

    #if os(iOS)
    public static let appGroupID = "group.com.screenshotmanager.app"
    public static let urlScheme = "screenshotmanager"
    #endif

    // MARK: - Container URLs

    #if os(iOS)
    /// Whether the App Group container is available.
    public static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    /// Root of the shared App Group container (iOS).
    public static var sharedContainerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return url
        }
        print("SharedConstants: App Group unavailable, falling back to Documents directory")
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Shared UserDefaults suite (iOS).
    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
    #elseif os(macOS)
    /// Application Support directory for macOS.
    public static var sharedContainerURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("ScreenShotManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Standard UserDefaults on macOS.
    public static var sharedDefaults: UserDefaults {
        .standard
    }
    #endif

    // MARK: - CoreData Store

    public static var sharedStoreURL: URL {
        sharedContainerURL.appendingPathComponent("ScreenShotManager.sqlite")
    }

    // MARK: - Image Directories

    public static var sharedScreenshotsDirectory: URL {
        let url = sharedContainerURL.appendingPathComponent("Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static var sharedThumbnailsDirectory: URL {
        let url = sharedContainerURL.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - UserDefaults Keys

    public static let hasMigratedStoreKey = "hasMigratedCoreDataStore"
    public static let hasMigratedImagesKey = "hasMigratedImageStorage"
}
