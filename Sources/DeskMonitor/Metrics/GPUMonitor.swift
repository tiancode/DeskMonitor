import Foundation
import IOKit

/// Apple Silicon 的 GPU 占用率来自 IORegistry 里 IOAccelerator 节点的
/// `PerformanceStatistics` 字典，不需要 root（powermetrics 才需要）。
///
/// 同一个字典里的 `In use system memory` 不要当显存用：统一内存架构下它跟着
/// 系统内存走，在大内存机器上会报出几百 GB。
final class GPUMonitor {

    private let utilizationKeys = [
        "Device Utilization %",
        "GPU Activity(%)",
        "Renderer Utilization %",
        "Tiler Utilization %"
    ]

    /// 占用率 0...1；没有 IOAccelerator 节点时返回 nil
    func read() -> Double? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var utilization = 0.0
        var found = false

        var service = IOIteratorNext(iterator)
        while service != 0 {
            // 只取 PerformanceStatistics 一个键：整份属性字典在多核 GPU 上构造一次要上毫秒。
            // 停在 NSDictionary 上按需取键，桥成 Swift Dictionary 会把每个值都装箱一遍。
            if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString,
                                                           kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSDictionary {
                found = true
                for key in utilizationKeys {
                    if let value = stats[key] as? NSNumber {
                        utilization = max(utilization, value.doubleValue)
                        break
                    }
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return found ? min(utilization / 100.0, 1.0) : nil
    }
}
