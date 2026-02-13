import Foundation
import CoreData

extension SmartFolder {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SmartFolder> {
        return NSFetchRequest<SmartFolder>(entityName: "SmartFolder")
    }

    @NSManaged public var iconName: String?
    @NSManaged public var id: UUID?
    @NSManaged public var keywords: NSObject?
    @NSManaged public var name: String?
}

extension SmartFolder: Identifiable {
}
