import Foundation
import SwiftUI

/// Supplies UI copy and the locale that formats dates and numbers. The app target installs the
/// implementation that follows the language chosen in Settings (`AppLanguage`).
public protocol UICopyProviding {
    /// The translation of an English source string, or the string itself.
    func string(_ key: String) -> String
    /// Locale for dates, numbers and relative times.
    var locale: Locale { get }
}

/// Follows the system language. Used until the app installs its own provider, and in tests.
public struct SystemUICopy: UICopyProviding {
    public init() {}

    public func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    public var locale: Locale { .autoupdatingCurrent }
}

public enum UICopy {
    /// Replaced once at launch by the app (`TemplateApp`).
    public static var provider: any UICopyProviding = SystemUICopy()
}

extension String {
    /// The single entry point for user-visible text built in code: the key is the English source
    /// string; translations live in `Resources/Localizable.xcstrings`. Call it inside a view `body` and
    /// the view redraws when the language changes.
    public static func loc(_ key: String) -> String {
        UICopy.provider.string(key)
    }
}

extension View {
    /// Applies the app's chosen locale to this view tree (put it on the root view of every scene).
    public func uiLocale() -> some View {
        environment(\.locale, UICopy.provider.locale)
    }
}
