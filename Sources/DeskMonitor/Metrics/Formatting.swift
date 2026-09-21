import Foundation

enum Format {

    /// 12.4 MB/s —— 速度用十进制单位，和磁盘厂商/活动监视器一致
    static func speed(_ bytesPerSecond: Double) -> String {
        byteCount(bytesPerSecond, suffix: "/s")
    }

    static func size(_ bytes: UInt64) -> String {
        byteCount(Double(bytes), suffix: "")
    }

    private static func byteCount(_ value: Double, suffix: String) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var amount = max(value, 0)
        var index = 0
        while amount >= 1000, index < units.count - 1 {
            amount /= 1000
            index += 1
        }
        let decimals: Int
        switch true {
        case index == 0: decimals = 0
        case amount >= 100: decimals = 0
        case amount >= 10: decimals = 1
        default: decimals = index == 1 ? 0 : 1
        }
        return String(format: "%.\(decimals)f %@%@", amount, units[index], suffix)
    }

    static func percent(_ ratio: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%%", max(0, min(ratio, 1)) * 100)
    }
}
