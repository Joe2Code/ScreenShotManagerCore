# ScreenShotManagerCore

A cross-platform Swift Package providing shared CoreData, OCR, smart folders, and image storage for the ScreenShot Manager app ecosystem.

## Platforms

- iOS 16.0+
- macOS 13.0+

## Installation

Add to your Xcode project via Swift Package Manager:

```
https://github.com/Joe2Code/ScreenShotManagerCore.git
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Joe2Code/ScreenShotManagerCore.git", branch: "main")
]
```

## What's Inside

### CoreData

- **`CorePersistenceController`** -- manages the full CoreData stack, loads the model from `Bundle.module`. Accepts a custom `storeURL` so iOS can use App Group containers and macOS can use Application Support.
- **`Screenshot`**, **`Tag`**, **`SmartFolder`** -- manual `NSManagedObject` subclasses with generated accessors
- Full CRUD for screenshots, tags, and smart folders
- Background context support (`performBackgroundTask`, `updateOCRTextInBackground`)

### OCR Engine

- **`OCREngine`** -- cross-platform Vision framework wrapper using `CGImage` input
- `recognizeText(in: CGImage) async -> String`
- `recognizeTextSync(in: CGImage) -> String`
- Accurate recognition level, language correction, multi-language support

### Smart Folder Engine

- **`SmartFolderEngine`** -- keyword and regex-based auto-categorization
- Built-in folder types: Recipes, Prices, Addresses, URLs, Phone Numbers
- Custom folders with user-defined keywords
- Async refresh on background context

### Image Storage

- **`CoreImageStorage`** -- file-based image and thumbnail management
- Save/load/delete with sanitized filenames
- Storage statistics and formatting
- **`PlatformImage`** -- `typealias` for `UIImage` (iOS) or `NSImage` (macOS) with `cgImageRepresentation` and `jpegData(quality:)` helpers

### Utilities

- **`SharedConstants`** -- platform-aware paths (`#if os(iOS)` App Group, `#if os(macOS)` Application Support)
- **`Color.init(hex:)`** / **`toHex()`** -- hex color conversion with UIColor/NSColor support
- **`Notification.Name`** extensions -- `.ocrTextUpdated`, `.newScreenshotsDetected`, `.cloudKitSyncCompleted`

## Used By

- [ScreenShot Manager for Mac](https://github.com/Joe2Code/ScreenShotManager-Mac) -- macOS menu bar app (open source)
- ScreenShot Manager for iOS -- iPhone/iPad app (private)

## License

MIT -- see [LICENSE](LICENSE)
