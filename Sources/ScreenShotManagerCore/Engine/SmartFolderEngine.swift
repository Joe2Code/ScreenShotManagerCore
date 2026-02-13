import Foundation
import Combine
import CoreData

/// SmartFolderEngine handles the logic for matching screenshots to smart folders
/// based on OCR text content and keyword patterns.
@MainActor
public final class SmartFolderEngine: ObservableObject {

    // MARK: - Types

    /// Represents a smart folder with its matching screenshots
    public struct SmartFolderResult: Identifiable {
        public let id: UUID
        public let name: String
        public let iconName: String
        public let keywords: [String]
        public let regexPatterns: [String]
        public var matchingIdentifiers: [String]
        public var matchCount: Int { matchingIdentifiers.count }

        public init(id: UUID, name: String, iconName: String, keywords: [String], regexPatterns: [String], matchingIdentifiers: [String]) {
            self.id = id
            self.name = name
            self.iconName = iconName
            self.keywords = keywords
            self.regexPatterns = regexPatterns
            self.matchingIdentifiers = matchingIdentifiers
        }
    }

    /// Predefined smart folder configurations
    public enum SmartFolderType: String, CaseIterable {
        case recipes = "Recipes"
        case prices = "Prices"
        case addresses = "Addresses"
        case urls = "URLs"
        case phoneNumbers = "Phone Numbers"

        public var keywords: [String] {
            switch self {
            case .recipes:
                return ["recipe", "ingredients", "tablespoon", "teaspoon", "tbsp", "tsp",
                        "preheat", "prep time", "cook time", "servings", "bake at",
                        "nutrition facts", "calories per", "whisk", "simmer", "sauté",
                        "marinate", "knead", "fold in"]
            case .prices:
                return ["$", "USD", "subtotal", "tax", "discount",
                        "€", "£", "¥", "amount due",
                        "balance", "invoice", "receipt", "order total"]
            case .addresses:
                return ["street", "avenue", "blvd", "boulevard", "lane",
                        "drive", "court", "suite", "apt", "apartment", "po box"]
            case .urls:
                return ["http://", "https://", "www."]
            case .phoneNumbers:
                return ["tel:", "phone:", "call us", "contact us"]
            }
        }

        public var iconName: String {
            switch self {
            case .recipes: return "fork.knife"
            case .prices: return "dollarsign.circle"
            case .addresses: return "mappin.and.ellipse"
            case .urls: return "link"
            case .phoneNumbers: return "phone"
            }
        }

        public var regexPatterns: [String] {
            switch self {
            case .recipes:
                return [
                    "\\d+\\s*(cup|cups|tbsp|tsp|tablespoon|teaspoon|oz|ounce|lb|pound|g|gram|ml|liter)s?",
                    "preheat.*\\d+.*degrees",
                    "bake.*\\d+.*minutes"
                ]
            case .prices:
                return [
                    "\\$\\d+\\.?\\d*",
                    "\\d+\\.\\d{2}\\s*USD",
                    "€\\d+\\.?\\d*",
                    "£\\d+\\.?\\d*",
                    "total:?\\s*\\$?\\d+"
                ]
            case .addresses:
                return [
                    "\\d+\\s+[A-Za-z]+\\s+(street|st|avenue|ave|boulevard|blvd|road|rd|drive|dr|lane|ln|court|ct)",
                    "\\d{5}(-\\d{4})?",
                    "[A-Za-z]+,\\s*[A-Z]{2}\\s+\\d{5}"
                ]
            case .urls:
                return [
                    "https?://[\\w\\-._~:/?#\\[\\]@!$&'()*+,;=%]+",
                    "www\\.[\\w\\-._~:/?#\\[\\]@!$&'()*+,;=%]+",
                    "[\\w\\-]+\\.(com|org|net|io|co|app|dev|edu|gov)"
                ]
            case .phoneNumbers:
                return [
                    "\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}",
                    "\\+?1?[-.\\s]?\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}",
                    "\\d{3}[-.\\s]\\d{4}"
                ]
            }
        }

        public var minimumMatches: Int {
            switch self {
            case .recipes: return 4
            case .prices: return 2
            case .addresses: return 3
            case .urls: return 1
            case .phoneNumbers: return 1
            }
        }
    }

    // MARK: - Published Properties

    @Published public var smartFolderResults: [SmartFolderResult] = []

    // MARK: - Properties

    private let persistenceController: CorePersistenceController
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(persistenceController: CorePersistenceController) {
        self.persistenceController = persistenceController
    }

    // MARK: - Smart Folder Matching

    public func refreshSmartFolders() {
        let screenshots = persistenceController.fetchAllScreenshots()

        var results: [SmartFolderResult] = []

        for folderType in SmartFolderType.allCases {
            let matchingIdentifiers = Self.findMatchingScreenshots(
                screenshots: screenshots,
                keywords: folderType.keywords,
                regexPatterns: folderType.regexPatterns,
                minimumMatches: folderType.minimumMatches
            )

            let result = SmartFolderResult(
                id: UUID(),
                name: folderType.rawValue,
                iconName: folderType.iconName,
                keywords: folderType.keywords,
                regexPatterns: folderType.regexPatterns,
                matchingIdentifiers: matchingIdentifiers
            )

            results.append(result)
        }

        let customFolders = persistenceController.fetchAllSmartFolders()
        for folder in customFolders {
            guard let keywords = folder.keywords as? [String] else { continue }

            let matchingIdentifiers = Self.findMatchingScreenshots(
                screenshots: screenshots,
                keywords: keywords,
                regexPatterns: []
            )

            let result = SmartFolderResult(
                id: folder.id ?? UUID(),
                name: folder.name ?? "Unknown",
                iconName: folder.iconName ?? "folder",
                keywords: keywords,
                regexPatterns: [],
                matchingIdentifiers: matchingIdentifiers
            )

            if !results.contains(where: { $0.name == result.name }) {
                results.append(result)
            }
        }

        self.smartFolderResults = results
    }

    public func refreshSmartFoldersAsync() async {
        let results: [SmartFolderResult] = await withCheckedContinuation { continuation in
            persistenceController.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Screenshot.creationDate, ascending: false)]

                var screenshots: [Screenshot] = []
                do {
                    screenshots = try context.fetch(fetchRequest)
                } catch {
                    print("Error fetching screenshots in background: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                var results: [SmartFolderResult] = []

                for folderType in SmartFolderType.allCases {
                    let matchingIdentifiers = Self.findMatchingScreenshots(
                        screenshots: screenshots,
                        keywords: folderType.keywords,
                        regexPatterns: folderType.regexPatterns,
                        minimumMatches: folderType.minimumMatches
                    )

                    let result = SmartFolderResult(
                        id: UUID(),
                        name: folderType.rawValue,
                        iconName: folderType.iconName,
                        keywords: folderType.keywords,
                        regexPatterns: folderType.regexPatterns,
                        matchingIdentifiers: matchingIdentifiers
                    )
                    results.append(result)
                }

                let folderFetch: NSFetchRequest<SmartFolder> = SmartFolder.fetchRequest()
                folderFetch.sortDescriptors = [NSSortDescriptor(keyPath: \SmartFolder.name, ascending: true)]

                let customFolders = (try? context.fetch(folderFetch)) ?? []
                for folder in customFolders {
                    guard let keywords = folder.keywords as? [String] else { continue }

                    let matchingIdentifiers = Self.findMatchingScreenshots(
                        screenshots: screenshots,
                        keywords: keywords,
                        regexPatterns: []
                    )

                    let result = SmartFolderResult(
                        id: folder.id ?? UUID(),
                        name: folder.name ?? "Unknown",
                        iconName: folder.iconName ?? "folder",
                        keywords: keywords,
                        regexPatterns: [],
                        matchingIdentifiers: matchingIdentifiers
                    )

                    if !results.contains(where: { $0.name == result.name }) {
                        results.append(result)
                    }
                }

                continuation.resume(returning: results)
            }
        }

        self.smartFolderResults = results
    }

    nonisolated public static func findMatchingScreenshots(
        screenshots: [Screenshot],
        keywords: [String],
        regexPatterns: [String],
        minimumMatches: Int = 1
    ) -> [String] {
        var matchingIdentifiers: [String] = []

        for screenshot in screenshots {
            guard let ocrText = screenshot.ocrText,
                  !ocrText.isEmpty,
                  let identifier = screenshot.localIdentifier else {
                continue
            }

            let lowercasedText = ocrText.lowercased()

            let keywordMatchCount = keywords.filter { keyword in
                lowercasedText.contains(keyword.lowercased())
            }.count

            let regexMatchCount = regexPatterns.filter { pattern in
                matchesRegex(text: ocrText, pattern: pattern)
            }.count

            if (keywordMatchCount + regexMatchCount) >= minimumMatches {
                matchingIdentifiers.append(identifier)
            }
        }

        return matchingIdentifiers
    }

    nonisolated public static func matchesRegex(text: String, pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        } catch {
            return false
        }
    }

    // MARK: - Smart Folder for Specific Screenshot

    public func smartFolders(for localIdentifier: String) -> [SmartFolderType] {
        guard let ocrText = getOCRText(for: localIdentifier) else {
            return []
        }

        var matchingFolders: [SmartFolderType] = []

        for folderType in SmartFolderType.allCases {
            if matchesSmartFolder(ocrText: ocrText, folderType: folderType) {
                matchingFolders.append(folderType)
            }
        }

        return matchingFolders
    }

    private func matchesSmartFolder(ocrText: String, folderType: SmartFolderType) -> Bool {
        let lowercasedText = ocrText.lowercased()

        let keywordMatchCount = folderType.keywords.filter { keyword in
            lowercasedText.contains(keyword.lowercased())
        }.count

        let regexMatchCount = folderType.regexPatterns.filter { pattern in
            Self.matchesRegex(text: ocrText, pattern: pattern)
        }.count

        return (keywordMatchCount + regexMatchCount) >= folderType.minimumMatches
    }

    private func getOCRText(for localIdentifier: String) -> String? {
        let fetchRequest = Screenshot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "localIdentifier == %@", localIdentifier)
        fetchRequest.fetchLimit = 1

        do {
            if let screenshot = try persistenceController.viewContext.fetch(fetchRequest).first {
                return screenshot.ocrText
            }
        } catch {
            print("Error fetching OCR text: \(error)")
        }

        return nil
    }

    // MARK: - Screenshots for Smart Folder

    public func screenshotIdentifiers(for folderType: SmartFolderType) -> [String] {
        let screenshots = persistenceController.fetchAllScreenshots()

        return Self.findMatchingScreenshots(
            screenshots: screenshots,
            keywords: folderType.keywords,
            regexPatterns: folderType.regexPatterns,
            minimumMatches: folderType.minimumMatches
        )
    }

    public func screenshotIdentifiers(for folderResult: SmartFolderResult) -> [String] {
        return folderResult.matchingIdentifiers
    }

    // MARK: - Keyword Highlighting

    public func keywordRanges(in text: String, for folderType: SmartFolderType) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []

        for keyword in folderType.keywords {
            var searchRange = text.startIndex..<text.endIndex
            while let range = text.range(of: keyword, options: .caseInsensitive, range: searchRange) {
                ranges.append(range)
                searchRange = range.upperBound..<text.endIndex
            }
        }

        for pattern in folderType.regexPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
                let matches = regex.matches(in: text, options: [], range: nsRange)

                for match in matches {
                    if let range = Range(match.range, in: text) {
                        ranges.append(range)
                    }
                }
            } catch {
                continue
            }
        }

        return ranges
    }

    // MARK: - Matched Snippets

    nonisolated public static func matchedSnippets(
        ocrText: String,
        keywords: [String],
        regexPatterns: [String]
    ) -> [String] {
        let lines = ocrText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var matched: [String] = []

        for line in lines {
            guard matched.count < 3 else { break }
            let lowercasedLine = line.lowercased()

            let hasKeyword = keywords.contains { keyword in
                lowercasedLine.contains(keyword.lowercased())
            }

            let hasRegex = regexPatterns.contains { pattern in
                matchesRegex(text: line, pattern: pattern)
            }

            if hasKeyword || hasRegex {
                matched.append(line.trimmingCharacters(in: .whitespaces))
            }
        }

        return matched
    }

    // MARK: - Statistics

    public func smartFolderStatistics() -> [(name: String, count: Int, icon: String)] {
        refreshSmartFolders()

        return smartFolderResults.map { result in
            (name: result.name, count: result.matchCount, icon: result.iconName)
        }
    }
}
