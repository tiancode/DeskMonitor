import Foundation

/// 界面文案查 `Localizable.strings`，键直接用英文原文——资源缺失时（例如
/// `swift run` 而不是跑打包好的 .app）会落回英文，不会露出键名。
///
/// 挑哪份 `.lproj` 由 macOS 按用户的语言顺序决定，都不匹配则退到
/// `CFBundleDevelopmentRegion`（英文）。
func L(_ key: String, _ arguments: CVarArg...) -> String {
    let template = Bundle.main.localizedString(forKey: key, value: key, table: nil)
    return arguments.isEmpty ? template : String(format: template, arguments: arguments)
}
