import Foundation
import CoreData

extension Tag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }

    @NSManaged public var colorHex: String?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var screenshots: NSSet?
}

// MARK: Generated accessors for screenshots
extension Tag {

    @objc(addScreenshotsObject:)
    @NSManaged public func addToScreenshots(_ value: Screenshot)

    @objc(removeScreenshotsObject:)
    @NSManaged public func removeFromScreenshots(_ value: Screenshot)

    @objc(addScreenshots:)
    @NSManaged public func addToScreenshots(_ values: NSSet)

    @objc(removeScreenshots:)
    @NSManaged public func removeFromScreenshots(_ values: NSSet)
}

extension Tag: Identifiable {
}
