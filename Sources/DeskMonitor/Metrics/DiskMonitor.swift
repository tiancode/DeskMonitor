import Foundation
import IOKit

/// 硬盘读写量取自 IOBlockStorageDriver 的累计字节计数，
/// 相邻两次采样求差再除以间隔 = 实时速度。
final class DiskMonitor {

    struct Sample {
        var readBytesPerSecond: Double
        var writeBytesPerSecond: Double
    }

    private var lastRead: UInt64 = 0
    private var lastWritten: UInt64 = 0
    private var lastTimestamp: CFAbsoluteTime = 0

    func read() -> Sample? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWritten: UInt64 = 0

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var unmanaged: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let properties = unmanaged?.takeRetainedValue() as? [String: Any],
               let stats = properties["Statistics"] as? [String: Any] {
                totalRead += (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                totalWritten += (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        let now = CFAbsoluteTimeGetCurrent()
        defer {
            lastRead = totalRead
            lastWritten = totalWritten
            lastTimestamp = now
        }

        guard lastTimestamp > 0 else { return nil }             // 第一次只记基线
        let elapsed = now - lastTimestamp
        guard elapsed > 0.01 else { return nil }

        let readDelta = totalRead >= lastRead ? totalRead - lastRead : 0
        let writeDelta = totalWritten >= lastWritten ? totalWritten - lastWritten : 0

        return Sample(readBytesPerSecond: Double(readDelta) / elapsed,
                      writeBytesPerSecond: Double(writeDelta) / elapsed)
    }

    /// 启动盘容量（变化慢，engine 里低频刷新）
    func capacity() -> (free: UInt64, total: UInt64)? {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]) else { return nil }
        guard let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return (UInt64(max(0, free)), UInt64(max(0, total)))
    }
}
