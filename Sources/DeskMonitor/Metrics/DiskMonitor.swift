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
            // 同 GPUMonitor：只取 Statistics，不构造整份属性字典
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

    /// 启动盘容量（变化慢，engine 里低频刷新）。
    ///
    /// 用 `statfs` 而不是 `URLResourceValues`：后者每次都要新建 URL 才能拿到新鲜值，
    /// 绕过缓存后单次要 25 ms；`statfs` 是 0.6 µs，且读数与 `df` 一致。
    /// （`volumeAvailableCapacityForImportantUsage` 会把可清除空间算进可用，
    /// 在这台机器上多出约 10 GB，对一个概览面板没有意义。）
    func capacity() -> (free: UInt64, total: UInt64)? {
        var fs = statfs()
        guard statfs("/", &fs) == 0 else { return nil }
        let blockSize = UInt64(fs.f_bsize)
        return (UInt64(fs.f_bavail) * blockSize, UInt64(fs.f_blocks) * blockSize)
    }
}
