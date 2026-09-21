import Darwin
import Foundation

/// 内存口径对齐活动监视器：已用 = 应用内存 + 联动(wired) + 已压缩。
final class MemoryMonitor {

    struct Sample {
        var total: UInt64
        var used: UInt64
        var app: UInt64
        var wired: UInt64
        var compressed: UInt64
        var swapUsed: UInt64
        var pressure: Double      // 0...1，基于 kern.memorystatus_vm_pressure_level
    }

    /// 主机端口取一次存着，原因见 `CPUMonitor`
    private let host = mach_host_self()

    let total: UInt64 = {
        var size: UInt64 = 0
        var length = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &length, nil, 0)
        return size
    }()

    func read() -> Sample? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let kr = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }

        let page = UInt64(vm_kernel_page_size)
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        let purgeable = UInt64(stats.purgeable_count)
        let internalPages = UInt64(stats.internal_page_count)
        let app = (internalPages > purgeable ? internalPages - purgeable : 0) * page

        return Sample(total: total,
                      used: app + wired + compressed,
                      app: app,
                      wired: wired,
                      compressed: compressed,
                      swapUsed: swapUsed(),
                      pressure: pressureLevel())
    }

    private func swapUsed() -> UInt64 {
        var usage = xsw_usage()
        var length = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &length, nil, 0) == 0 else { return 0 }
        return usage.xsu_used
    }

    /// 把 sysctl 的等级（1 正常 / 2 警告 / 4 紧急）归一化成 0 / 0.5 / 1
    private func pressureLevel() -> Double {
        var level: Int32 = 1
        var length = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &length, nil, 0) == 0 else { return 0 }
        switch level {
        case 4: return 1.0
        case 2: return 0.5
        default: return 0.0
        }
    }
}
