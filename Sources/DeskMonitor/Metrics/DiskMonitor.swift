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
            // 只取 Statistics 一个键：构造整份属性字典的开销没必要付
            if let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString,
                                                           kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] {
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

    /// 启动盘容量。口径与 `df` 一致，不含可清除空间
    /// —— `volumeAvailableCapacityForImportantUsage` 会把可清除空间算作可用，
    /// 对一个概览面板没有意义。
    func capacity() -> (free: UInt64, total: UInt64)? {
        var fs = statfs()
        guard statfs("/", &fs) == 0 else { return nil }
        let blockSize = UInt64(fs.f_bsize)
        return (UInt64(fs.f_bavail) * blockSize, UInt64(fs.f_blocks) * blockSize)
    }
}
