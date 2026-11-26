import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Gets a meal photo ready to send: any format the camera or library gives (HEIC, PNG, a 12 MP JPEG) becomes a JPEG
/// no longer than Claude reads at full detail, turned the right way up. A few hundred KB instead of several MB.
public enum PhotoPrep {
    /// The longest side Claude looks at without scaling the image down itself.
    public static let maxPixels = 1568

    public static func jpeg(from data: Data, maxPixels: Int = maxPixels, quality: Double = 0.8) -> Data? {
        guard let image = image(from: data, maxPixels: maxPixels) else { return nil }
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? out as Data : nil
    }

    /// The photo, upright and at most `maxPixels` on its longest side, for showing or sending.
    public static func image(from data: Data, maxPixels: Int = maxPixels) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// When the photo was taken, from its EXIF data, read as the phone's local time. Nil when the photo doesn't say
    /// (screenshots, edited copies), so the caller uses now.
    public static func takenAt(_ data: Data, timeZone: TimeZone = .current) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
            let text = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: text)
    }
}
