import Foundation

public extension Screenshot {
    var tagsArray: [Tag] {
        let tagSet = tags as? Set<Tag> ?? []
        return Array(tagSet).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
}
