import CoreImage
import SwiftUI
import UIKit
import AnyMetricsShared

enum MetricShareKind: Equatable, Sendable {
    /// Card image plus the importable metric file.
    case file
    /// Card image only. No metric file and no request.
    case image
}

struct MetricSharePayload {
    let image: UIImage
    let imageURL: URL
    let metricURL: URL?
    let caption: String
    let kind: MetricShareKind
    let includesRequest: Bool

    var includesFile: Bool { kind == .file }

    var activityItems: [Any] {
        switch kind {
        case .image:
            return [MetricShareImageItem(image: image, title: caption)]
        case .file:
            var items: [Any] = [MetricShareImageItem(image: image, title: caption)]
            if let metricURL {
                items.append(MetricShareFileItem(fileURL: metricURL))
            }
            items.append(MetricShareTextItem(caption: caption))
            return items
        }
    }

    var fileURLs: [URL] {
        [imageURL, metricURL].compactMap { $0 }
    }
}

enum MetricShareComposer {

    static let cardSize = CGSize(width: 360, height: 500)
    static let renderScale: CGFloat = 3
    static let widgetSide: CGFloat = 228
    static let qrSide: CGFloat = 52

    static var appStoreURL: URL { AppConfig.Urls.appStore }

    static func caption(title: String) -> String {
        AnyMetricsStrings.Metric.Share.caption(title)
    }

    static func fileName(title: String, id: UUID) -> String {
        let sanitizedTitle = title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
            .lowercased()
        let baseName = sanitizedTitle.isEmpty ? "metric" : sanitizedTitle
        let shortId = String(id.uuidString.prefix(8)).lowercased()
        return "share_\(baseName)_\(shortId).png"
    }

    static func qrImage(from string: String, size: CGFloat) -> UIImage? {
        guard size > 0,
              let data = string.data(using: .isoLatin1),
              let filter = CIFilter(name: "CIQRCodeGenerator")
        else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }

        let scale = size / max(output.extent.width, 1)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func qrImage(url: URL, size: CGFloat) -> UIImage? {
        qrImage(from: url.absoluteString, size: size)
    }

    @MainActor
    static func renderCard(metric: Metric) -> UIImage? {
        let qr = qrImage(url: appStoreURL, size: qrSide * renderScale)
        let card = MetricShareCardView(metric: metric, qrImage: qr)
            .environment(\.colorScheme, .light)
        return render(card, size: cardSize, scale: renderScale)
    }

    @MainActor
    static func writePayload(
        metric: Metric,
        options: MetricExportOptions = .default,
        kind: MetricShareKind = .file
    ) throws -> MetricSharePayload {
        let rendered = try writeShareImage(metric: metric)
        let metricURL: URL?
        let includesRequest: Bool
        if kind == .file {
            do {
                metricURL = try MetricItemImportData.writeFile(for: metric, options: options)
            } catch {
                try? FileManager.default.removeItem(at: rendered.url)
                throw error
            }
            includesRequest = options.includeRequest
        } else {
            metricURL = nil
            includesRequest = false
        }
        return MetricSharePayload(
            image: rendered.image,
            imageURL: rendered.url,
            metricURL: metricURL,
            caption: caption(title: metric.title),
            kind: kind,
            includesRequest: includesRequest
        )
    }

    @MainActor
    static func writeShareImage(metric: Metric) throws -> (image: UIImage, url: URL) {
        guard let rendered = renderCard(metric: metric) else {
            throw MetricShareWriteError.renderFailed
        }
        let image = opaqueImage(rendered)
        guard let data = image.pngData() else {
            throw MetricShareWriteError.renderFailed
        }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(title: metric.title, id: metric.id))
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw MetricShareWriteError.writeFailed
        }
        return (image, fileURL)
    }

    /// ImageRenderer always emits premultiplied alpha. The card is fully opaque, so keep RGB only.
    /// Otherwise ImageIO logs an error on every encode, including the share sheet's second pass.
    private static func opaqueImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return image }

        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return image }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let stripped = context.makeImage() else { return image }
        return UIImage(cgImage: stripped, scale: image.scale, orientation: image.imageOrientation)
    }

    @MainActor
    private static func render<Content: View>(_ content: Content, size: CGSize, scale: CGFloat) -> UIImage? {
        let root = content
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: root)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
}

enum MetricShareWriteError: Error {
    case renderFailed
    case writeFailed
}
