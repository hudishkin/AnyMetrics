import CoreImage
import SwiftUI
import UIKit
import AnyMetricsShared

struct MetricSharePayload {
    let image: UIImage
    let imageURL: URL
    let metricURL: URL
    let caption: String

    var activityItems: [Any] {
        [
            MetricShareImageItem(image: image, title: caption),
            MetricShareFileItem(fileURL: metricURL),
            MetricShareTextItem(caption: caption)
        ]
    }

    var fileURLs: [URL] {
        [imageURL, metricURL]
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
    static func writePayload(metric: Metric) throws -> MetricSharePayload {
        let rendered = try writeShareImage(metric: metric)
        let metricURL: URL
        do {
            metricURL = try MetricItemImportData.writeFile(for: metric, options: .default)
        } catch {
            try? FileManager.default.removeItem(at: rendered.url)
            throw error
        }
        return MetricSharePayload(
            image: rendered.image,
            imageURL: rendered.url,
            metricURL: metricURL,
            caption: caption(title: metric.title)
        )
    }

    @MainActor
    static func writeShareImage(metric: Metric) throws -> (image: UIImage, url: URL) {
        guard let image = renderCard(metric: metric), let data = image.pngData() else {
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

    @MainActor
    private static func render<Content: View>(_ content: Content, size: CGSize, scale: CGFloat) -> UIImage? {
        let root = content
            .frame(width: size.width, height: size.height)

        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: root)
            renderer.scale = scale
            renderer.proposedSize = ProposedViewSize(size)
            return renderer.uiImage
        }

        let hosting = UIHostingController(rootView: root)
        hosting.view.bounds = CGRect(origin: .zero, size: size)
        hosting.view.backgroundColor = .clear
        hosting.overrideUserInterfaceStyle = .light

        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = hosting
        window.isHidden = false
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        return image
    }
}

enum MetricShareWriteError: Error {
    case renderFailed
    case writeFailed
}
