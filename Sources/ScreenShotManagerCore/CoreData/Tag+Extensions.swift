import Foundation

public extension Tag {
    var screenshotsArray: [Screenshot] {
        let screenshotSet = screenshots as? Set<Screenshot> ?? []
        return Array(screenshotSet).sorted { ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast) }
    }
}
