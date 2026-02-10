import Foundation

public enum AppConfig {
    public static let emailForReport = "anymetrics.app@gmail.com"
    public static let group = "group.anymetrics.app"
    public static let metricsKey = "app.metrics"

    public enum Urls {
        public static let galleryVersion = "v1"

        public static let appRepository = URL(string: "https://github.com/hudishkin/AnyMetrics")!
        public static let galleryRepository = URL(string: "https://github.com/hudishkin/AnyMetricsGallery")!
        public static let rules = URL(string: "https://github.com/hudishkin/AnyMetrics")!
        public static let gallery = URL(string: String(format: "https://raw.githubusercontent.com/hudishkin/AnyMetricsGallery/main/%@/list.min.json", galleryVersion))!
    }

    public static let isiOSAppOnMac: Bool = {
        var isiOSAppOnMac = false
        if #available(iOS 14.0, *) {
            isiOSAppOnMac = ProcessInfo.processInfo.isiOSAppOnMac
        }
        return isiOSAppOnMac
    }()
}
