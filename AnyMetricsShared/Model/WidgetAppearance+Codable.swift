import Foundation

// MARK: - WidgetAppearance custom decode (version default)

extension WidgetAppearance {
    enum CodingKeys: String, CodingKey {
        case version, presetId, small, medium
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? WidgetAppearance.currentVersion
        presetId = try container.decodeIfPresent(String.self, forKey: .presetId)
        small = try container.decode(WidgetSizeAppearance.self, forKey: .small)
        medium = try container.decode(WidgetSizeAppearance.self, forKey: .medium)
    }
}

extension WidgetBackgroundFill: Codable {
    enum CodingKeys: String, CodingKey {
        case type, solid, gradient, image
    }

    enum FillType: String, Codable {
        case system, solid, gradient, statusGradient, image
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(FillType.self, forKey: .type)
        switch type {
        case .system:
            self = .system
        case .solid:
            self = .solid(try container.decode(WidgetColorSpec.self, forKey: .solid))
        case .gradient:
            self = .gradient(try container.decode(WidgetGradientSpec.self, forKey: .gradient))
        case .statusGradient:
            self = .statusGradient
        case .image:
            self = .image(try container.decode(WidgetImageRef.self, forKey: .image))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .system:
            try container.encode(FillType.system, forKey: .type)
        case .solid(let color):
            try container.encode(FillType.solid, forKey: .type)
            try container.encode(color, forKey: .solid)
        case .gradient(let gradient):
            try container.encode(FillType.gradient, forKey: .type)
            try container.encode(gradient, forKey: .gradient)
        case .statusGradient:
            try container.encode(FillType.statusGradient, forKey: .type)
        case .image(let image):
            try container.encode(FillType.image, forKey: .type)
            try container.encode(image, forKey: .image)
        }
    }
}

extension WidgetImageRef: Codable {
    enum CodingKeys: String, CodingKey {
        case type, path, url, data
    }

    enum RefType: String, Codable {
        case file, url, base64
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(RefType.self, forKey: .type)
        switch type {
        case .file:
            self = .file(try container.decode(String.self, forKey: .path))
        case .url:
            self = .url(try container.decode(String.self, forKey: .url))
        case .base64:
            self = .base64(try container.decode(String.self, forKey: .data))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .file(let path):
            try container.encode(RefType.file, forKey: .type)
            try container.encode(path, forKey: .path)
        case .url(let url):
            try container.encode(RefType.url, forKey: .type)
            try container.encode(url, forKey: .url)
        case .base64(let data):
            try container.encode(RefType.base64, forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
}

extension WidgetColorSpec: Codable {
    enum CodingKeys: String, CodingKey {
        case type, token, hex, light, dark
    }

    enum ColorType: String, Codable {
        case adaptive, hex, adaptiveHex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ColorType.self, forKey: .type)
        switch type {
        case .adaptive:
            self = .adaptive(try container.decode(WidgetAdaptiveColor.self, forKey: .token))
        case .hex:
            self = .hex(try container.decode(String.self, forKey: .hex))
        case .adaptiveHex:
            self = .adaptiveHex(
                light: try container.decode(String.self, forKey: .light),
                dark: try container.decode(String.self, forKey: .dark)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .adaptive(let token):
            try container.encode(ColorType.adaptive, forKey: .type)
            try container.encode(token, forKey: .token)
        case .hex(let hex):
            try container.encode(ColorType.hex, forKey: .type)
            try container.encode(hex, forKey: .hex)
        case .adaptiveHex(let light, let dark):
            try container.encode(ColorType.adaptiveHex, forKey: .type)
            try container.encode(light, forKey: .light)
            try container.encode(dark, forKey: .dark)
        }
    }
}
