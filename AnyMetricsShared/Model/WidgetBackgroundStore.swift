import Foundation
import UIKit

/// Stores widget background images in the App Group container.
public final class WidgetBackgroundStore: @unchecked Sendable {
    public static let shared = WidgetBackgroundStore()

    public static let directoryName = "widget-backgrounds"
    public static let maxPixelDimension: CGFloat = 800
    public static let jpegQuality: CGFloat = 0.72

    private let fileManager: FileManager
    private let groupIdentifier: String

    public init(
        fileManager: FileManager = .default,
        groupIdentifier: String = AppConfig.group
    ) {
        self.fileManager = fileManager
        self.groupIdentifier = groupIdentifier
    }

    public var directoryURL: URL? {
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else {
            return nil
        }
        let url = container.appendingPathComponent(Self.directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    public func fileURL(relativePath: String) -> URL? {
        directoryURL?.appendingPathComponent(relativePath)
    }

    public func loadImage(relativePath: String) -> UIImage? {
        guard let url = fileURL(relativePath: relativePath),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    public func loadData(relativePath: String) -> Data? {
        guard let url = fileURL(relativePath: relativePath) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Compresses and writes image; returns relative path for `WidgetImageRef.file`.
    @discardableResult
    public func saveImage(_ image: UIImage, metricId: UUID, size: WidgetSizeKey) throws -> String {
        let prepared = Self.downscaled(image, maxDimension: Self.maxPixelDimension)
        guard let data = prepared.jpegData(compressionQuality: Self.jpegQuality) else {
            throw WidgetBackgroundStoreError.encodingFailed
        }
        return try saveData(data, metricId: metricId, size: size, fileExtension: "jpg")
    }

    public func saveData(_ data: Data, metricId: UUID, size: WidgetSizeKey, fileExtension: String = "jpg") throws -> String {
        guard let directory = directoryURL else {
            throw WidgetBackgroundStoreError.containerUnavailable
        }
        let relative = "\(metricId.uuidString)-\(size.rawValue).\(fileExtension)"
        let url = directory.appendingPathComponent(relative)
        try data.write(to: url, options: .atomic)
        return relative
    }

    public func delete(relativePath: String) {
        guard let url = fileURL(relativePath: relativePath) else { return }
        try? fileManager.removeItem(at: url)
    }

    public func deleteAll(for metricId: UUID) {
        guard let directory = directoryURL,
              let files = try? fileManager.contentsOfDirectory(atPath: directory.path)
        else { return }
        let prefix = metricId.uuidString
        for name in files where name.hasPrefix(prefix) {
            try? fileManager.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    public static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension, maxSide > 0 else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

public enum WidgetBackgroundStoreError: Error {
    case containerUnavailable
    case encodingFailed
    case invalidBase64
    case imageUnavailableForExport
}

public extension WidgetAppearance {
    /// Inlines file images as base64 for share/export JSON.
    func preparingForExport(store: WidgetBackgroundStore = .shared) throws -> WidgetAppearance {
        var copy = self
        copy.small = try copy.small.preparingForExport(store: store)
        copy.medium = try copy.medium.preparingForExport(store: store)
        return copy
    }

    /// Materializes base64 images into App Group files after import.
    mutating func materializeImportedImages(
        metricId: UUID,
        store: WidgetBackgroundStore = .shared
    ) throws {
        small = try small.materializeImportedImages(metricId: metricId, size: .small, store: store)
        medium = try medium.materializeImportedImages(metricId: metricId, size: .medium, store: store)
    }

    var containsBase64Images: Bool {
        small.background.fill.isBase64Image || medium.background.fill.isBase64Image
    }
}

private extension WidgetSizeAppearance {
    func preparingForExport(store: WidgetBackgroundStore) throws -> WidgetSizeAppearance {
        var copy = self
        if case .image(let ref) = copy.background.fill {
            copy.background.fill = .image(try ref.preparingForExport(store: store))
        }
        return copy
    }

    func materializeImportedImages(
        metricId: UUID,
        size: WidgetSizeKey,
        store: WidgetBackgroundStore
    ) throws -> WidgetSizeAppearance {
        var copy = self
        if case .image(let ref) = copy.background.fill {
            copy.background.fill = .image(try ref.materialize(metricId: metricId, size: size, store: store))
        }
        return copy
    }
}

private extension WidgetBackgroundFill {
    var isBase64Image: Bool {
        if case .image(.base64) = self { return true }
        return false
    }
}

private extension WidgetImageRef {
    func preparingForExport(store: WidgetBackgroundStore) throws -> WidgetImageRef {
        switch self {
        case .file(let path):
            guard let data = store.loadData(relativePath: path) else {
                throw WidgetBackgroundStoreError.imageUnavailableForExport
            }
            return .base64(data.base64EncodedString())
        case .url, .base64:
            return self
        }
    }

    func materialize(
        metricId: UUID,
        size: WidgetSizeKey,
        store: WidgetBackgroundStore
    ) throws -> WidgetImageRef {
        switch self {
        case .base64(let string):
            // Share/paste paths can introduce whitespace; ignore it when decoding.
            guard let data = Data(base64Encoded: string, options: .ignoreUnknownCharacters),
                  let image = UIImage(data: data)
            else {
                throw WidgetBackgroundStoreError.invalidBase64
            }
            // Re-encode via saveImage so the widget always reads a compact JPEG in App Group.
            let path = try store.saveImage(image, metricId: metricId, size: size)
            return .file(path)
        case .file, .url:
            return self
        }
    }
}
