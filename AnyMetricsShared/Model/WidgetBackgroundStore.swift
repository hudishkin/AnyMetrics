import Foundation
import UIKit

/// Stores widget background images in the App Group container.
public final class WidgetBackgroundStore: @unchecked Sendable {
    public static let shared = WidgetBackgroundStore()

    public static let directoryName = "widget-backgrounds"
    public static let maxPixelDimension: CGFloat = 800
    public static let jpegQuality: CGFloat = 0.72
    public static let urlDownloadTimeout: TimeInterval = 12

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

    /// Compresses and writes image; PNG when alpha is present, otherwise JPEG.
    @discardableResult
    public func saveImage(_ image: UIImage, metricId: UUID, size: WidgetSizeKey) throws -> String {
        let encoded = try Self.encodedImage(image)
        // Drop stale sibling extensions so path always matches bytes on disk.
        delete(relativePath: "\(metricId.uuidString)-\(size.rawValue).jpg")
        delete(relativePath: "\(metricId.uuidString)-\(size.rawValue).png")
        return try saveData(encoded.data, metricId: metricId, size: size, fileExtension: encoded.fileExtension)
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
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = !hasAlpha(image)
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    public static func encodedImage(_ image: UIImage) throws -> (data: Data, fileExtension: String) {
        let prepared = downscaled(image, maxDimension: maxPixelDimension)
        if hasAlpha(prepared), let png = prepared.pngData() {
            return (png, "png")
        }
        guard let jpeg = prepared.jpegData(compressionQuality: jpegQuality) else {
            throw WidgetBackgroundStoreError.encodingFailed
        }
        return (jpeg, "jpg")
    }

    public static func hasAlpha(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        switch cgImage.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
            return true
        default:
            return false
        }
    }
}

public enum WidgetBackgroundStoreError: Error {
    case containerUnavailable
    case encodingFailed
    case invalidBase64
    case invalidURL
    case downloadFailed
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

    /// Materializes base64 / URL images into App Group files (URL via sync session with timeout).
    mutating func materializeImportedImages(
        metricId: UUID,
        store: WidgetBackgroundStore = .shared
    ) throws {
        small = try small.materializeImportedImages(metricId: metricId, size: .small, store: store)
        medium = try medium.materializeImportedImages(metricId: metricId, size: .medium, store: store)
    }

    /// Async-friendly materialize: base64 sync, URL via URLSession (no unbounded `Data(contentsOf:)`).
    func materializeImportedImagesAsync(
        metricId: UUID,
        store: WidgetBackgroundStore = .shared,
        completion: @escaping (WidgetAppearance) -> Void
    ) {
        var copy = self
        let group = DispatchGroup()
        let lock = NSLock()

        func materializeSize(_ keyPath: WritableKeyPath<WidgetAppearance, WidgetSizeAppearance>, size: WidgetSizeKey) {
            let fill = copy[keyPath: keyPath].background.fill
            guard case .image(let ref) = fill else { return }

            switch ref {
            case .file:
                break
            case .base64:
                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    defer { group.leave() }
                    if let materialized = try? ref.materialize(metricId: metricId, size: size, store: store) {
                        lock.lock()
                        copy[keyPath: keyPath].background.fill = .image(materialized)
                        lock.unlock()
                    }
                }
            case .url(let raw):
                group.enter()
                ref.downloadAndSave(metricId: metricId, size: size, store: store) { result in
                    lock.lock()
                    switch result {
                    case .success(let fileRef):
                        copy[keyPath: keyPath].background.fill = .image(fileRef)
                    case .failure:
                        // Avoid leaving an unloadable `.url` fill in the widget.
                        copy[keyPath: keyPath].background.fill = .system
                    }
                    lock.unlock()
                    group.leave()
                }
            }
        }

        materializeSize(\.small, size: .small)
        materializeSize(\.medium, size: .medium)

        group.notify(queue: .main) {
            completion(copy)
        }
    }

    var containsBase64Images: Bool {
        small.background.fill.isBase64Image || medium.background.fill.isBase64Image
    }

    var containsURLImages: Bool {
        small.background.fill.isURLImage || medium.background.fill.isURLImage
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

    var isURLImage: Bool {
        if case .image(.url) = self { return true }
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
            guard let data = Data(base64Encoded: string, options: .ignoreUnknownCharacters),
                  let image = UIImage(data: data)
            else {
                throw WidgetBackgroundStoreError.invalidBase64
            }
            let path = try store.saveImage(image, metricId: metricId, size: size)
            return .file(path)
        case .url(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else {
                throw WidgetBackgroundStoreError.invalidURL
            }
            let data = try downloadSynchronously(from: url)
            guard let image = UIImage(data: data) else {
                throw WidgetBackgroundStoreError.downloadFailed
            }
            let path = try store.saveImage(image, metricId: metricId, size: size)
            return .file(path)
        case .file:
            return self
        }
    }

    func downloadAndSave(
        metricId: UUID,
        size: WidgetSizeKey,
        store: WidgetBackgroundStore,
        completion: @escaping (Result<WidgetImageRef, Error>) -> Void
    ) {
        guard case .url(let raw) = self else {
            completion(.success(self))
            return
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            completion(.failure(WidgetBackgroundStoreError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = WidgetBackgroundStore.urlDownloadTimeout
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data, let image = UIImage(data: data) else {
                completion(.failure(WidgetBackgroundStoreError.downloadFailed))
                return
            }
            do {
                let path = try store.saveImage(image, metricId: metricId, size: size)
                completion(.success(.file(path)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// Bounded sync download for import paths (not for WidgetKit timeline).
    private func downloadSynchronously(from url: URL) throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = WidgetBackgroundStore.urlDownloadTimeout
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Data, Error> = .failure(WidgetBackgroundStoreError.downloadFailed)
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                result = .failure(error)
            } else if let data {
                result = .success(data)
            } else {
                result = .failure(WidgetBackgroundStoreError.downloadFailed)
            }
            semaphore.signal()
        }.resume()
        let wait = semaphore.wait(timeout: .now() + WidgetBackgroundStore.urlDownloadTimeout + 1)
        guard wait == .success else {
            throw WidgetBackgroundStoreError.downloadFailed
        }
        return try result.get()
    }
}
