import Foundation
import Testing

/// Guards the String Catalog against the code: UI strings are English keys that exist in the
/// catalog, no Chinese literal is left in app code, and no catalog key is orphaned.
/// Xcode command-line builds do not write new strings back to the catalog, so tests do it.
struct UserVisibleStringsTests {
    /// Chinese allowed in app code: language names (shown verbatim, `AppLanguage`).
    private static let allowedChinese: Set<String> = ["简体中文", "繁體中文", "日本語"]

    /// SwiftUI calls whose first string literal is shown to the user (and so must be a catalog key).
    private static let uiOpeners = [
        "String.loc(", "Text(", "Button(", "Label(", "Toggle(", "Picker(", "Section(", "TextField(",
        "Menu(",
        "Link(", ".help(", ".navigationTitle(", "ProgressView(", "SecureField(", "Window(",
    ]

    private struct Catalog: Decodable {
        let strings: [String: Empty]
    }

    private struct Empty: Decodable {}

    private static var root: URL {
        URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Replaces `\(...)` in a string literal's content with `%@` (parentheses and inner quotes are
    /// paired).
    private static func literals(in source: String) -> [(line: Int, text: String)] {
        let chars = Array(source)
        var result: [(Int, String)] = []
        var line = 1
        var i = 0
        func skipInterpolation(_ i: inout Int) {
            // After `\(`: skip to the matching `)`; strings may appear inside.
            var depth = 1
            while i < chars.count, depth > 0 {
                let c = chars[i]
                if c == "\n" { line += 1 }
                if c == "\"" {
                    i += 1
                    while i < chars.count, chars[i] != "\"" {
                        if chars[i] == "\\" { i += 1 }
                        if i < chars.count, chars[i] == "(" {}
                        i += 1
                    }
                } else if c == "(" {
                    depth += 1
                } else if c == ")" {
                    depth -= 1
                }
                i += 1
            }
        }
        while i < chars.count {
            let c = chars[i]
            if c == "\n" {
                line += 1
                i += 1
                continue
            }
            if c == "/", i + 1 < chars.count, chars[i + 1] == "/" {
                while i < chars.count, chars[i] != "\n" { i += 1 }
                continue
            }
            if c == "\"" {
                if i + 2 < chars.count, chars[i + 1] == "\"", chars[i + 2] == "\"" {
                    // Multi-line literal: skip it whole (none in the project need translation).
                    i += 3
                    while i + 2 < chars.count,
                        !(chars[i] == "\"" && chars[i + 1] == "\"" && chars[i + 2] == "\"")
                    {
                        if chars[i] == "\n" { line += 1 }
                        i += 1
                    }
                    i += 3
                    continue
                }
                let startLine = line
                i += 1
                var text = ""
                while i < chars.count, chars[i] != "\"" {
                    if chars[i] == "\\", i + 1 < chars.count {
                        if chars[i + 1] == "(" {
                            i += 2
                            skipInterpolation(&i)
                            text += "%@"
                            continue
                        }
                        text += chars[i + 1] == "n" ? "\n" : String(chars[i + 1])
                        i += 2
                        continue
                    }
                    text.append(chars[i])
                    i += 1
                }
                i += 1
                result.append((startLine, text))
                continue
            }
            i += 1
        }
        return result
    }

    private static func skeleton(_ text: String) -> String {
        text.replacing(/%(?:\d+\$)?(?:lld|@)/, with: "§")
    }

    private static func catalogKeys() throws -> Set<String> {
        let url = root.appending(path: "Template/Resources/Localizable.xcstrings")
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        return Set(catalog.strings.keys.map(skeleton))
    }

    /// The app target and the Core package: both produce user-visible text.
    private static let sourceRoots = ["Template", "TemplateCore/Sources"]

    private static func appSources() throws -> [(name: String, text: String)] {
        try sourceRoots.flatMap { directory in
            let enumerator = try #require(
                FileManager.default.enumerator(
                    at: root.appending(path: directory), includingPropertiesForKeys: nil))
            return try enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
                .map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
        }
    }

    @Test func noChineseIsLeftInAppCode() throws {
        var found: [String] = []
        for (name, source) in try Self.appSources() {
            for (line, text) in Self.literals(in: source)
            where text.unicodeScalars.contains(where: { $0.value >= 0x4E00 && $0.value <= 0x9FFF })
                && !Self.allowedChinese.contains(text)
            {
                found.append("\(name):\(line) \(text.prefix(40))")
            }
        }
        #expect(found.isEmpty, "Chinese literals in app code: \(found.prefix(15))")
    }

    @Test func everyUILiteralIsInTheCatalog() throws {
        let keys = try Self.catalogKeys()
        var missing: [String] = []
        for (name, source) in try Self.appSources() {
            let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
            for (index, line) in lines.enumerated() {
                let code = line.drop(while: { $0 == " " })
                if code.hasPrefix("//") || code.contains("verbatim:") || code.contains("#Preview") {
                    continue
                }
                for opener in Self.uiOpeners {
                    var rest = Substring(line)
                    while let range = rest.range(of: opener + "\"") {
                        let tail = rest[range.upperBound...]
                        let literal = Self.literals(in: "\"" + tail).first?.text ?? ""
                        let hasLetters = Self.skeleton(literal).contains(/\p{L}/)
                        if hasLetters, !keys.contains(Self.skeleton(literal)) {
                            missing.append("\(name):\(index + 1) \(literal.prefix(50))")
                        }
                        rest = tail
                    }
                }
            }
        }
        #expect(
            missing.isEmpty, "UI text that is not in Localizable.xcstrings: \(missing.prefix(15))")
    }

    @Test func everyCatalogKeyIsUsedInCode() throws {
        let keys = try Self.catalogKeys()
        var used: Set<String> = []
        for (_, source) in try Self.appSources() {
            for (_, text) in Self.literals(in: source) { used.insert(Self.skeleton(text)) }
        }
        let everything = try Self.appSources().map(\.text).joined()
        let orphaned = keys.subtracting(used).filter { key in
            // Literals nested inside another literal's interpolation count too.
            let chunk = key.components(separatedBy: "§").max { $0.count < $1.count } ?? ""
            return chunk.count < 4 || !everything.contains(chunk)
        }.sorted()
        #expect(orphaned.isEmpty, "Catalog keys no code uses: \(orphaned.prefix(15))")
    }
}
