import Darwin
import Foundation
import SystemConfiguration

/// 网络流量取主网卡的收发字节计数，相邻采样求差 ÷ 间隔 = 实时速度。
///
/// 计数器走 `sysctl(NET_RT_IFLIST2)` 的 `if_data64`，但本进程拿到的
/// `ifi_ibytes` / `ifi_obytes` 只有低 32 位有效（Apple 签名的进程才拿到完整 64 位）。
/// 因此增量按模 2³² 计算——只要单次采样间隔内流量不超过 4 GB，截断与否结果都正确；
/// 绝对值则不可信，「累计」只能自己从增量累加。
final class NetworkMonitor {

    struct Sample {
        var download: Double        // B/s
        var upload: Double          // B/s
        var interface: String       // 本地化名，如 “Wi-Fi”
        var sessionReceived: UInt64 // 本次会话累计，自行累加
        var sessionSent: UInt64
    }

    private lazy var store = SCDynamicStoreCreate(nil, "com.deht.deskmonitor" as CFString, nil, nil)
    private var displayNames = [String: String]()

    /// 内核可能只给 32 位，增量一律按模 2³² 计算
    private static let counterMask: UInt64 = 0xFFFF_FFFF

    private var sessionReceived: UInt64 = 0
    private var sessionSent: UInt64 = 0
    private var lastReceived: UInt64 = 0
    private var lastSent: UInt64 = 0
    private var lastTimestamp: CFAbsoluteTime = 0
    private var lastInterface = ""

    func read() -> Sample? {
        guard let bsdName = primaryInterface() else {
            lastTimestamp = 0                       // 断网后重新建立基线
            lastInterface = ""
            return Sample(download: 0, upload: 0, interface: "未连接",
                          sessionReceived: sessionReceived, sessionSent: sessionSent)
        }
        guard let counters = counters(for: bsdName) else { return nil }

        let now = CFAbsoluteTimeGetCurrent()
        let switched = bsdName != lastInterface
        defer {
            lastReceived = counters.received
            lastSent = counters.sent
            lastTimestamp = now
            lastInterface = bsdName
        }

        // 第一次采样、或刚切换网卡（Wi-Fi ↔ 以太网），只记基线
        guard lastTimestamp > 0, !switched else { return nil }
        let elapsed = now - lastTimestamp
        guard elapsed > 0.01 else { return nil }

        let receivedDelta = (counters.received &- lastReceived) & Self.counterMask
        let sentDelta = (counters.sent &- lastSent) & Self.counterMask
        sessionReceived &+= receivedDelta
        sessionSent &+= sentDelta

        return Sample(download: Double(receivedDelta) / elapsed,
                      upload: Double(sentDelta) / elapsed,
                      interface: displayName(for: bsdName),
                      sessionReceived: sessionReceived,
                      sessionSent: sessionSent)
    }

    // MARK: - 主网卡

    private func primaryInterface() -> String? {
        guard let store,
              let global = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let name = global["PrimaryInterface"] as? String else { return nil }
        return name
    }

    /// en0 → “Wi-Fi” / “以太网”，查一次就缓存
    private func displayName(for bsdName: String) -> String {
        if let cached = displayNames[bsdName] { return cached }
        var resolved = bsdName
        if let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] {
            for interface in interfaces
            where SCNetworkInterfaceGetBSDName(interface) as String? == bsdName {
                if let localized = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? {
                    resolved = localized
                }
                break
            }
        }
        displayNames[bsdName] = resolved
        return resolved
    }

    // MARK: - 64 位收发计数

    private func counters(for bsdName: String) -> (received: UInt64, sent: UInt64)? {
        let index = if_nametoindex(bsdName)
        guard index > 0 else { return nil }

        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, Int32(index)]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return nil }

        return buffer.withUnsafeBytes { raw -> (UInt64, UInt64)? in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let messageLength = Int(header.ifm_msglen)
                guard messageLength > 0 else { break }

                if Int32(header.ifm_type) == RTM_IFINFO2,
                   offset + MemoryLayout<if_msghdr2>.size <= length {
                    let message = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if message.ifm_index == index {
                        return (message.ifm_data.ifi_ibytes, message.ifm_data.ifi_obytes)
                    }
                }
                offset += messageLength
            }
            return nil
        }
    }
}
