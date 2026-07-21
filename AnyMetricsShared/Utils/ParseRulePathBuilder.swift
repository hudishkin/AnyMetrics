import Foundation
import SwiftyJSON
import SwiftSoup

public enum ParseRulePathBuilder {

    public struct TapTarget: Equatable {
        public let range: NSRange
        public let parseRule: String

        public init(range: NSRange, parseRule: String) {
            self.range = range
            self.parseRule = parseRule
        }
    }

    public enum ContentType {
        case json
        case html
    }

    public static func tapTargets(in text: String, type: ContentType) -> [TapTarget] {
        switch type {
        case .json:
            return jsonTapTargets(in: text)
        case .html:
            return htmlTapTargets(in: text)
        }
    }

    public static func parseRule(at location: Int, in targets: [TapTarget]) -> String? {
        tapTarget(at: location, in: targets)?.parseRule
    }

    public static func tapTarget(at location: Int, in targets: [TapTarget]) -> TapTarget? {
        let matching = targets.filter { NSLocationInRange(location, $0.range) }
        return matching.min(by: { $0.range.length < $1.range.length })
    }

    // MARK: - JSON

    private static func jsonTapTargets(in text: String) -> [TapTarget] {
        guard !text.isEmpty,
              let data = text.data(using: .utf8),
              (try? JSON(data: data)) != nil else { return [] }

        var scanner = JSONTextScanner(text: text as NSString)
        scanner.scanValue(path: "")
        return scanner.targets.map { TapTarget(range: $0.range, parseRule: $0.path) }
    }

    // MARK: - HTML

    private static func htmlTapTargets(in html: String) -> [TapTarget] {
        guard !html.isEmpty,
              let document = try? SwiftSoup.parse(html),
              let elements = try? document.select("*") else { return [] }

        let nsHtml = html as NSString
        var targets: [TapTarget] = []

        for element in elements {
            let text = element.ownText()
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            var searchRange = NSRange(location: 0, length: nsHtml.length)
            while searchRange.location < nsHtml.length {
                let found = nsHtml.range(of: text, options: [], range: searchRange)
                guard found.location != NSNotFound else { break }

                let selector = cssSelector(for: element)
                targets.append(TapTarget(range: found, parseRule: selector))
                searchRange.location = found.location + found.length
                searchRange.length = nsHtml.length - searchRange.location
            }
        }

        return targets
    }

    private static func cssSelector(for element: Element) -> String {
        let id = element.id()
        if !id.isEmpty {
            return "#\(id)"
        }

        let tag = element.tagName().lowercased()
        if let classes = try? element.classNames(), let firstClass = classes.first, !firstClass.isEmpty {
            return "\(tag).\(firstClass)"
        }

        return tag
    }
}

// MARK: - JSON Scanner

private struct ScannedTarget {
    let range: NSRange
    let path: String
}

private enum JSONChar {
    static let openBrace = unichar(UInt8(ascii: "{"))
    static let closeBrace = unichar(UInt8(ascii: "}"))
    static let openBracket = unichar(UInt8(ascii: "["))
    static let closeBracket = unichar(UInt8(ascii: "]"))
    static let quote = unichar(UInt8(ascii: "\""))
    static let colon = unichar(UInt8(ascii: ":"))
    static let comma = unichar(UInt8(ascii: ","))
    static let backslash = unichar(UInt8(ascii: "\\"))
    static let minus = unichar(UInt8(ascii: "-"))
    static let dot = unichar(UInt8(ascii: "."))
    static let e = unichar(UInt8(ascii: "e"))
    static let upperE = unichar(UInt8(ascii: "E"))
    static let plus = unichar(UInt8(ascii: "+"))
    static let t = unichar(UInt8(ascii: "t"))
    static let f = unichar(UInt8(ascii: "f"))
    static let n = unichar(UInt8(ascii: "n"))
    static let zero = unichar(UInt8(ascii: "0"))
    static let nine = unichar(UInt8(ascii: "9"))
}

private struct JSONTextScanner {
    let text: NSString
    var index = 0
    var targets: [ScannedTarget] = []

    mutating func skipWhitespace() {
        while index < text.length {
            let character = text.character(at: index)
            if character == 32 || character == 9 || character == 10 || character == 13 {
                index += 1
            } else {
                break
            }
        }
    }

    mutating func scanValue(path: String) {
        skipWhitespace()
        guard index < text.length else { return }

        switch text.character(at: index) {
        case JSONChar.openBrace:
            scanObject(path: path)
        case JSONChar.openBracket:
            scanArray(path: path)
        case JSONChar.quote:
            let range = scanString()
            if !path.isEmpty {
                targets.append(ScannedTarget(range: range, path: path))
            }
        case JSONChar.t, JSONChar.f, JSONChar.n:
            let range = scanLiteral()
            if !path.isEmpty {
                targets.append(ScannedTarget(range: range, path: path))
            }
        default:
            if isDigit(text.character(at: index)) || text.character(at: index) == JSONChar.minus {
                let range = scanNumber()
                if !path.isEmpty {
                    targets.append(ScannedTarget(range: range, path: path))
                }
            }
        }
    }

    mutating func scanObject(path: String) {
        index += 1
        skipWhitespace()

        if index < text.length, text.character(at: index) == JSONChar.closeBrace {
            index += 1
            return
        }

        while index < text.length {
            skipWhitespace()
            let keyRange = scanString()
            let key = text.substring(with: keyRange).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            skipWhitespace()

            if index < text.length, text.character(at: index) == JSONChar.colon {
                index += 1
            }

            let childPath = path.isEmpty ? key : "\(path).\(key)"
            scanValue(path: childPath)
            skipWhitespace()

            if index < text.length, text.character(at: index) == JSONChar.comma {
                index += 1
                continue
            }

            if index < text.length, text.character(at: index) == JSONChar.closeBrace {
                index += 1
                break
            }
        }
    }

    mutating func scanArray(path: String) {
        index += 1
        skipWhitespace()

        if index < text.length, text.character(at: index) == JSONChar.closeBracket {
            index += 1
            return
        }

        var itemIndex = 0
        while index < text.length {
            let childPath = path.isEmpty ? String(itemIndex) : "\(path).\(itemIndex)"
            scanValue(path: childPath)
            itemIndex += 1
            skipWhitespace()

            if index < text.length, text.character(at: index) == JSONChar.comma {
                index += 1
                continue
            }

            if index < text.length, text.character(at: index) == JSONChar.closeBracket {
                index += 1
                break
            }
        }
    }

    mutating func scanString() -> NSRange {
        let start = index
        index += 1

        while index < text.length {
            let character = text.character(at: index)
            if character == JSONChar.backslash {
                index = min(index + 2, text.length)
                continue
            }
            if character == JSONChar.quote {
                index += 1
                break
            }
            index += 1
        }

        return NSRange(location: start, length: index - start)
    }

    mutating func scanNumber() -> NSRange {
        let start = index

        if text.character(at: index) == JSONChar.minus {
            index += 1
        }

        while index < text.length {
            let character = text.character(at: index)
            if isDigit(character)
                || character == JSONChar.dot
                || character == JSONChar.e
                || character == JSONChar.upperE
                || character == JSONChar.plus
                || character == JSONChar.minus {
                index += 1
            } else {
                break
            }
        }

        return NSRange(location: start, length: index - start)
    }

    mutating func scanLiteral() -> NSRange {
        let start = index

        switch text.character(at: index) {
        case JSONChar.n:
            index += 4
        case JSONChar.t:
            index += 4
        case JSONChar.f:
            index += 5
        default:
            break
        }

        return NSRange(location: start, length: index - start)
    }

    private func isDigit(_ character: unichar) -> Bool {
        character >= JSONChar.zero && character <= JSONChar.nine
    }
}
