// Dump the accessibility tree of the running app (what VoiceOver reads) and flag problems.
//
//   swift scripts/ax-audit.swift [bundle-id]      default: PRODUCT_BUNDLE_IDENTIFIER of project.yml
//
// Prints one line per element: role | name | value. Problems are listed after the tree:
//   UNNAMED  an interactive element (button, checkbox, ...) with no name: VoiceOver says only its role
//   CJK      Chinese text while the app language is not Chinese or Japanese (a missing translation)
// Exit status 1 when a problem is found. Needs Accessibility permission for the terminal
// (System Settings > Privacy & Security > Accessibility). Open the windows you want checked first.
import ApplicationServices
import AppKit
import Foundation

// The app's bundle identifier from project.yml (first PRODUCT_BUNDLE_IDENTIFIER that is not the tests'),
// read from the current directory, so run it from the repository root.
func defaultBundleID() -> String {
    let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("project.yml")
    let text = (try? String(contentsOf: project, encoding: .utf8)) ?? ""
    for line in text.split(separator: "\n") {
        let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2, parts[0] == "PRODUCT_BUNDLE_IDENTIFIER", !parts[1].hasSuffix(".tests") { return parts[1] }
    }
    print("error: pass the bundle identifier (project.yml has none)")
    exit(2)
}

let bundleID = CommandLine.arguments.dropFirst().first ?? defaultBundleID()
let language = UserDefaults(suiteName: bundleID)?.string(forKey: "language") ?? "system"
// Japanese uses kanji too; the catalog tests cover it.
let chineseUI = ["system", "zh-Hans", "zh-Hant", "ja"].contains(language)
let languageNames: Set<String> = ["简体中文", "繁體中文", "日本語", "한국어"]
let interactive: Set<String> = [
    "AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton", "AXSlider",
    "AXTextField", "AXComboBox", "AXLink", "AXSwitch", "AXDisclosureTriangle", "AXMenuItem",
]

guard AXIsProcessTrusted() else {
    print("error: grant Accessibility permission to this terminal, then run again")
    exit(2)
}
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
    print("error: \(bundleID) is not running")
    exit(2)
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
func text(_ element: AXUIElement, _ name: String) -> String {
    if let string = attribute(element, name) as? String { return string }
    if let attributed = attribute(element, name) as? NSAttributedString { return attributed.string }
    return ""
}
func children(_ element: AXUIElement) -> [AXUIElement] {
    (attribute(element, "AXChildren") as? [AXUIElement]) ?? []
}

var problems = Set<String>()
func visit(_ element: AXUIElement, depth: Int, window: String) {
    let role = text(element, "AXRole")
    let name = [text(element, "AXTitle"), text(element, "AXDescription"), text(element, "AXAttributedDescription")]
        .first { !$0.isEmpty } ?? ""
    let value = text(element, "AXValue")
    let help = text(element, "AXHelp")
    var line = String(repeating: "  ", count: depth) + role + " | " + name
    if !value.isEmpty { line += " | " + value }
    if !help.isEmpty { line += " | help: " + help }
    print(line)
    let kids = children(element)
    let label = [name, value] + kids.map { text($0, "AXTitle") + text($0, "AXValue") }
    // The window's own close / minimize / zoom buttons are named by the system from their subrole.
    let systemButton = text(element, "AXSubrole").hasSuffix("Button") && depth <= 2
    if interactive.contains(role), !systemButton, label.allSatisfy({ $0.isEmpty }) {
        problems.insert("UNNAMED \(role) in '\(window)'")
    }
    if !chineseUI {
        for string in [name, value, help] where !languageNames.contains(string) {
            if string.unicodeScalars.contains(where: { (0x3400...0x9FFF).contains($0.value) }) {
                problems.insert("CJK '\(string)' in '\(window)' (\(role))")
            }
        }
    }
    for kid in kids { visit(kid, depth: depth + 1, window: window) }
}

let root = AXUIElementCreateApplication(app.processIdentifier)
let windows = (attribute(root, "AXWindows") as? [AXUIElement]) ?? []
for window in windows {
    let title = text(window, "AXTitle")
    print("== window: \(title)")
    visit(window, depth: 1, window: title)
}
// The menu bar extra and any popover live outside AXWindows.
if let extras = attribute(root, "AXExtrasMenuBar") {
    print("== menu bar extra")
    visit(extras as! AXUIElement, depth: 1, window: "menu bar extra")
}
print("\nlanguage: \(language), windows: \(windows.count)")
if problems.isEmpty {
    print("no problems found")
} else {
    for problem in problems.sorted() { print(problem) }
    exit(1)
}
