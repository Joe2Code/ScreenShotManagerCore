import Foundation
import CoreData

extension Screenshot {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Screenshot> {
        return NSFetchRequest<Screenshot>(entityName: "Screenshot")
    }

    @NSManaged public var creationDate: Date?
    @NSManaged public var localIdentifier: String?
    @NSManaged public var localImagePath: String?
    @NSManaged public var ocrProcessed: Bool
    @NSManaged public var ocrText: String?
    @NSManaged public var tags: NSSet?
}

// MARK: Generated accessors for tags
extension Screenshot {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
}

extension Screenshot: Identifiable {
}
