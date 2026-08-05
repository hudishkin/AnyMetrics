import Foundation
import UIKit

/// Stores metric image results in the App Group container.
public final class MetricResultImageStore: @unchecked Sendable {
    public static let shared = MetricResultImageStore()

    public static let directoryName = "metric-results"
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
        guard let data = loadData(relativePath: relativePath) else { return nil }
        return UIImage(data: data)
    }

    public func loadData(relativePath: String) -> Data? {
        guard let url = fileURL(relativePath: relativePath) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Validates, compresses, and writes image data; returns relative path.
    @discardableResult
    public func save(data: Data, metricId: UUID) throws -> String {
        guard let image = UIImage(data: data) else {
            throw MetricResultImageStoreError.invalidImageData
        }
        return try save(image: image, metricId: metricId)
    }

    @discardableResult
    public func save(image: UIImage, metricId: UUID) throws -> String {
        let prepared = WidgetBackgroundStore.downscaled(image, maxDimension: Self.maxPixelDimension)
        guard let jpeg = prepared.jpegData(compressionQuality: Self.jpegQuality) else {
            throw MetricResultImageStoreError.encodingFailed
        }
        guard let directory = directoryURL else {
            throw MetricResultImageStoreError.containerUnavailable
        }
        let relative = "\(metricId.uuidString).jpg"
        let url = directory.appendingPathComponent(relative)
        try jpeg.write(to: url, options: .atomic)
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
}

public enum MetricResultImageStoreError: Error {
    case containerUnavailable
    case encodingFailed
    case invalidImageData
}
