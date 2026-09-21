import Foundation

/// 界面文案查 `Localizable.strings`，键直接用英文原文——资源缺失时（例如
/// `swift run` 而不是跑打包好的 .app）会落回英文，不会露出键名。
///
/// 选哪种语言由 macOS 决定：先看「系统设置 › 语言与地区 › 应用程序」里给本应用
/// 单独指定的语言，没有就按系统语言顺序在 `Contents/Resources/*.lproj` 里挑，
/// 都不匹配则退到 `CFBundleDevelopmentRegion`（英文）。
func L(_ key: String, _ arguments: CVarArg...) -> String {
    let template = Bundle.main.localizedString(forKey: key, value: key, table: nil)
    return arguments.isEmpty ? template : String(format: template, arguments: arguments)
}
