import Foundation

func localized(_ key: String, bundle: Bundle = .main) -> String {
    bundle.localizedString(forKey: key, value: nil, table: nil)
}

func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localized(key), locale: Locale.current, arguments: arguments)
}
