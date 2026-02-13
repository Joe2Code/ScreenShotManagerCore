import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

public extension PlatformImage {
    /// Returns a CGImage representation of this image.
    var cgImageRepresentation: CGImage? {
        #if canImport(UIKit)
        return cgImage
        #elseif canImport(AppKit)
        return cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }

    /// Returns JPEG data for this image at the given compression quality.
    func jpegData(quality: CGFloat) -> Data? {
        #if canImport(UIKit)
        return jpegData(compressionQuality: quality)
        #elseif canImport(AppKit)
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        #endif
    }
}
