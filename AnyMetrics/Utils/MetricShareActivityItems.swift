import LinkPresentation
import UIKit
import UniformTypeIdentifiers

enum MetricShareActivity {

    static func prefersFilesOverLinks(_ activityType: UIActivity.ActivityType?) -> Bool {
        guard let raw = activityType?.rawValue.lowercased() else { return false }
        return raw.contains("telegram")
            || raw.contains("telegraph")
            || raw.contains("whatsapp")
            || raw.contains("instagram")
            || raw.contains("vk.")
            || raw.contains("com.vk")
    }
}

final class MetricShareImageItem: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        title
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}

final class MetricShareFileItem: NSObject, UIActivityItemSource {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.json.identifier
    }
}

final class MetricShareTextItem: NSObject, UIActivityItemSource {
    let caption: String

    init(caption: String) {
        self.caption = caption
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        caption
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        Self.text(caption: caption, activityType: activityType)
    }

    static func text(caption: String, activityType: UIActivity.ActivityType?) -> String {
        if MetricShareActivity.prefersFilesOverLinks(activityType) {
            return caption
        }
        return "\(caption)\n\(MetricShareComposer.appStoreURL.absoluteString)"
    }
}
