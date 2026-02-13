import CoreData
import Foundation

/// CorePersistenceController manages the CoreData stack for both iOS and macOS.
/// Platform-specific apps wrap this with their own PersistenceController that adds
/// platform-specific features (migration, WidgetKit, toast errors, etc.).
public final class CorePersistenceController: ObservableObject {

    // MARK: - Properties

    public let container: NSPersistentContainer

    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // MARK: - Initialization

    /// Creates a CorePersistenceController with the given store URL.
    /// - Parameters:
    ///   - storeURL: URL for the SQLite store. iOS passes App Group URL, macOS passes Application Support URL.
    ///   - inMemory: If true, uses /dev/null for testing/previews.
    public init(storeURL: URL? = nil, inMemory: Bool = false) {
        guard let modelURL = Bundle.module.url(forResource: "ScreenShotManager", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("CorePersistenceController: Failed to load CoreData model from Bundle.module")
        }

        container = NSPersistentContainer(name: "ScreenShotManager", managedObjectModel: model)

        if inMemory {
            guard let description = container.persistentStoreDescriptions.first else {
                container.loadPersistentStores { _, _ in }
                return
            }
            description.url = URL(fileURLWithPath: "/dev/null")
        } else if let storeURL = storeURL {
            let description = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("CoreData error: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Save Context

    public func save() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: - Smart Folder Setup

    public func setupDefaultSmartFoldersIfNeeded() {
        let fetchRequest: NSFetchRequest<SmartFolder> = SmartFolder.fetchRequest()

        do {
            let count = try viewContext.count(for: fetchRequest)
            if count == 0 {
                Self.createDefaultSmartFolders(in: viewContext)
                try viewContext.save()
            }
        } catch {
            print("Error checking smart folders: \(error)")
        }
    }

    public static func createDefaultSmartFolders(in context: NSManagedObjectContext) {
        let folders: [(name: String, keywords: [String], icon: String)] = [
            ("Recipes", ["recipe", "ingredients", "cups", "tablespoons", "teaspoons", "bake", "cook", "minutes", "oven", "mix", "stir"], "fork.knife"),
            ("Prices", ["$", "USD", "price", "cost", "total", "subtotal", "tax", "discount", "sale", "€", "£"], "dollarsign.circle"),
            ("Addresses", ["street", "ave", "avenue", "blvd", "boulevard", "road", "rd", "lane", "ln", "drive", "dr", "court", "ct", "zip", "city", "state"], "mappin.and.ellipse"),
            ("URLs", ["http", "https", "www", ".com", ".org", ".net", ".io", ".co", "://"], "link"),
            ("Phone Numbers", ["phone", "call", "tel", "mobile", "cell", "(", ")", "-"], "phone")
        ]

        for (name, keywords, icon) in folders {
            let folder = SmartFolder(context: context)
            folder.id = UUID()
            folder.name = name
            folder.keywords = keywords as NSObject
            folder.iconName = icon
        }
    }

    // MARK: - Screenshot Operations

    public func fetchOrCreateScreenshot(localIdentifier: String, creationDate: Date?) -> Screenshot {
        let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "localIdentifier == %@", localIdentifier)
        fetchRequest.fetchLimit = 1

        do {
            if let existing = try viewContext.fetch(fetchRequest).first {
                return existing
            }
        } catch {
            print("Error fetching screenshot: \(error)")
        }

        let screenshot = Screenshot(context: viewContext)
        screenshot.localIdentifier = localIdentifier
        screenshot.creationDate = creationDate
        screenshot.ocrProcessed = false

        return screenshot
    }

    public func fetchUnprocessedScreenshots() -> [Screenshot] {
        let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "ocrProcessed == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.creationDate, ascending: false)]

        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching unprocessed screenshots: \(error)")
            return []
        }
    }

    public func fetchAllScreenshots() -> [Screenshot] {
        let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.creationDate, ascending: false)]

        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching screenshots: \(error)")
            return []
        }
    }

    public func searchScreenshots(query: String) -> [Screenshot] {
        let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()

        let ocrPredicate = NSPredicate(format: "ocrText CONTAINS[cd] %@", query)
        let tagPredicate = NSPredicate(format: "ANY tags.name CONTAINS[cd] %@", query)
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [ocrPredicate, tagPredicate])
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.creationDate, ascending: false)]

        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error searching screenshots: \(error)")
            return []
        }
    }

    public func fetchScreenshots(withTag tag: Tag) -> [Screenshot] {
        let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "ANY tags == %@", tag)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.creationDate, ascending: false)]

        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching screenshots with tag: \(error)")
            return []
        }
    }

    public func updateOCRText(for localIdentifier: String, text: String) {
        let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "localIdentifier == %@", localIdentifier)
        fetchRequest.fetchLimit = 1

        do {
            if let screenshot = try viewContext.fetch(fetchRequest).first {
                screenshot.ocrText = text
                screenshot.ocrProcessed = true
                save()
            }
        } catch {
            print("Error updating OCR text: \(error)")
        }
    }

    public func updateLocalImagePath(for localIdentifier: String, path: String) {
        let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "localIdentifier == %@", localIdentifier)
        fetchRequest.fetchLimit = 1

        do {
            if let screenshot = try viewContext.fetch(fetchRequest).first {
                screenshot.localImagePath = path
                save()
            }
        } catch {
            print("Error updating local image path: \(error)")
        }
    }

    public func cleanupDeletedScreenshots(existingIdentifiers: Set<String>) {
        let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()

        do {
            let allScreenshots = try viewContext.fetch(fetchRequest)
            for screenshot in allScreenshots {
                if let identifier = screenshot.localIdentifier,
                   !existingIdentifiers.contains(identifier) {
                    if screenshot.localImagePath == nil {
                        viewContext.delete(screenshot)
                    }
                }
            }
            save()
        } catch {
            print("Error cleaning up screenshots: \(error)")
        }
    }

    public func deleteScreenshot(_ screenshot: Screenshot) {
        viewContext.delete(screenshot)
        save()
    }

    // MARK: - Tag Operations

    public func fetchAllTags() -> [Tag] {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]

        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching tags: \(error)")
            return []
        }
    }

    @discardableResult
    public func createTag(name: String, colorHex: String) -> Tag {
        let tag = Tag(context: viewContext)
        tag.id = UUID()
        tag.name = name
        tag.colorHex = colorHex
        save()
        return tag
    }

    public func deleteTag(_ tag: Tag) {
        viewContext.delete(tag)
        save()
    }

    // MARK: - Smart Folder Operations

    public func fetchAllSmartFolders() -> [SmartFolder] {
        let fetchRequest: NSFetchRequest<SmartFolder> = SmartFolder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SmartFolder.name, ascending: true)]

        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching smart folders: \(error)")
            return []
        }
    }

    @discardableResult
    public func createSmartFolder(name: String, keywords: [String], iconName: String) -> SmartFolder {
        let folder = SmartFolder(context: viewContext)
        folder.id = UUID()
        folder.name = name
        folder.keywords = keywords as NSObject
        folder.iconName = iconName
        save()
        return folder
    }

    public func updateSmartFolder(id: UUID, name: String, keywords: [String], iconName: String) {
        let fetchRequest: NSFetchRequest<SmartFolder> = SmartFolder.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            if let folder = try viewContext.fetch(fetchRequest).first {
                folder.name = name
                folder.keywords = keywords as NSObject
                folder.iconName = iconName
                save()
            }
        } catch {
            print("Error updating smart folder: \(error)")
        }
    }

    public func deleteSmartFolder(id: UUID) {
        let fetchRequest: NSFetchRequest<SmartFolder> = SmartFolder.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            if let folder = try viewContext.fetch(fetchRequest).first {
                viewContext.delete(folder)
                save()
            }
        } catch {
            print("Error deleting smart folder: \(error)")
        }
    }

    public func fetchScreenshots(for smartFolder: SmartFolder) -> [Screenshot] {
        guard let keywords = smartFolder.keywords as? [String], !keywords.isEmpty else {
            return []
        }

        let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()

        var predicates: [NSPredicate] = []
        for keyword in keywords {
            predicates.append(NSPredicate(format: "ocrText CONTAINS[cd] %@", keyword))
        }

        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.creationDate, ascending: false)]

        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching screenshots for smart folder: \(error)")
            return []
        }
    }

    // MARK: - Background Context

    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }

    public func updateOCRTextInBackground(for localIdentifier: String, text: String, completion: (() -> Void)? = nil) {
        performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "localIdentifier == %@", localIdentifier)
            fetchRequest.fetchLimit = 1

            do {
                if let screenshot = try context.fetch(fetchRequest).first {
                    screenshot.ocrText = text
                    screenshot.ocrProcessed = true
                    if context.hasChanges {
                        try context.save()
                    }
                }
            } catch {
                print("Error updating OCR text in background: \(error)")
            }

            completion?()
        }
    }
}
