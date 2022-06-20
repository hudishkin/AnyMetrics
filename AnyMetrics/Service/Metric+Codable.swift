//
//  Metric+Codable.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Foundation

extension Metric: Codable {

    enum CodingKeys: String, CodingKey {
        case id,
             title,
             paramName,
             lastValue,
             request,
             type,
             parseRules,
             created,
             updated,
             indicateError,
             style,
             formatter,
             author,
             description,
             website
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(UUID.self, forKey: CodingKeys.id)) ?? UUID()
        title = try container.decode(String.self, forKey: CodingKeys.title)
        paramName = try container.decode(String.self, forKey: CodingKeys.paramName)
        lastValue = (try? container.decodeIfPresent(String.self, forKey: CodingKeys.lastValue)) ?? ""
        request = try container.decode(RequestData.self, forKey: CodingKeys.request)
        type = try container.decode(TypeMetric.self, forKey: CodingKeys.type)
        parseRules = try? container.decodeIfPresent(String.self, forKey: CodingKeys.parseRules)
        created = (try? container.decodeIfPresent(Date.self, forKey: CodingKeys.created)) ?? Date()
        updated = try? container.decodeIfPresent(Date.self, forKey: CodingKeys.updated)
        indicateError = (try? container.decodeIfPresent(Bool.self, forKey: CodingKeys.indicateError)) ?? false
//        style = (try? container.decodeIfPresent(MetricStyle.self, forKey: CodingKeys.style))
        formatter = (try? container.decodeIfPresent(MetricValueFormatter.self, forKey: CodingKeys.formatter)) ?? .default
        author = (try? container.decodeIfPresent(String.self, forKey: CodingKeys.author))
        description = (try? container.decodeIfPresent(String.self, forKey: CodingKeys.description))
        website = (try? container.decodeIfPresent(URL.self, forKey: CodingKeys.website))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
//        try container.encode(style, forKey: .style)
        try container.encode(paramName, forKey: .paramName)
        try container.encode(lastValue, forKey: .lastValue)
        try container.encode(request, forKey: .request)
        try container.encode(type, forKey: .type)
        try? container.encodeIfPresent(parseRules, forKey: .parseRules)
        try container.encode(created, forKey: .created)
        try? container.encodeIfPresent(updated, forKey: .updated)
        try? container.encodeIfPresent(formatter, forKey: .formatter)
        try container.encode(indicateError, forKey: .indicateError)
        try? container.encodeIfPresent(author, forKey: .author)
        try? container.encodeIfPresent(description, forKey: .description)
        try? container.encodeIfPresent(website, forKey: .website)

    }
}


extension RequestData: Codable {
    enum CodingKeys: String, CodingKey {
        case headers, method, url, timeout
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        headers = try container.decode([String:String].self, forKey: .headers)
        method = try container.decode(String.self, forKey: .method)
        url = try container.decode(URL.self, forKey: .url)
        timeout = try? container.decodeIfPresent(Double.self, forKey: .timeout)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.headers, forKey: .headers)
        try container.encode(self.method, forKey: .method)
        try container.encode(self.url, forKey: .url)
        try? container.encodeIfPresent(self.timeout, forKey: .timeout)
    }
}

extension MetricValueFormatter: Codable {
    enum CodingKeys: String, CodingKey {
        case format, length, fraction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = (try? container.decodeIfPresent(MetricFormatterType.self, forKey: .format)) ?? .none
        length = try? container.decodeIfPresent(Int.self, forKey: .length)
        fraction = try? container.decodeIfPresent(Int.self, forKey: .fraction)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.length, forKey: .length)
        try container.encode(self.format, forKey: .format)
        try container.encode(self.fraction, forKey: .fraction)
    }
}


extension MetricStyle: Codable {

    enum CodingKeys: String, CodingKey {
        case symbol, hexColor, imageURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageURL = try? container.decodeIfPresent(URL.self, forKey: .imageURL)
        hexColor = try? container.decodeIfPresent(String.self, forKey: .hexColor)
        symbol = (try? container.decodeIfPresent(String.self, forKey: .symbol)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encodeIfPresent(self.symbol, forKey: .symbol)
        try? container.encodeIfPresent(self.hexColor, forKey: .hexColor)
        try? container.encodeIfPresent(self.imageURL, forKey: .imageURL)
    }
}

extension MetricFormatterType {
    var localizedName: String { NSLocalizedString("format-type-\(self.rawValue.lowercased())", comment: "") }
}
