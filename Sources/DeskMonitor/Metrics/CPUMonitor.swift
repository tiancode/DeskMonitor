import Darwin
import Foundation

/// 通过 Mach 的 `host_processor_info` 读取每个核心的 tick 计数，
/// 两次采样求差值得到真实占用率（和活动监视器同源）。
final class CPUMonitor {

    struct Sample {
        var total: Double      // 0...1
        var user: Double
        var system: Double
    }

    private var previousTicks: [UInt32] = []
    private let stateCount = Int(CPU_STATE_MAX)

    func read() -> Sample? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let kr = host_processor_info(mach_host_self(),
                                     processor_flavor_t(PROCESSOR_CPU_LOAD_INFO),
                                     &cpuCount,
                                     &info,
                                     &infoCount)
        guard kr == KERN_SUCCESS, let info else { return nil }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: UnsafeRawPointer(info))),
                          vm_size_t(UInt(infoCount) * UInt(MemoryLayout<integer_t>.size)))
        }

        let count = Int(cpuCount) * stateCount
        var ticks = [UInt32](repeating: 0, count: count)
        for i in 0..<count { ticks[i] = UInt32(bitPattern: info[i]) }

        defer { previousTicks = ticks }
        guard previousTicks.count == count else { return nil }   // 第一次采样只记录基线

        var busyTotal = 0.0, idleTotal = 0.0, userTotal = 0.0, systemTotal = 0.0

        for core in 0..<Int(cpuCount) {
            let base = core * stateCount
            let user   = Double(ticks[base + Int(CPU_STATE_USER)]   &- previousTicks[base + Int(CPU_STATE_USER)])
            let system = Double(ticks[base + Int(CPU_STATE_SYSTEM)] &- previousTicks[base + Int(CPU_STATE_SYSTEM)])
            let idle   = Double(ticks[base + Int(CPU_STATE_IDLE)]   &- previousTicks[base + Int(CPU_STATE_IDLE)])
            let nice   = Double(ticks[base + Int(CPU_STATE_NICE)]   &- previousTicks[base + Int(CPU_STATE_NICE)])

            busyTotal += user + system + nice
            idleTotal += idle
            userTotal += user + nice
            systemTotal += system
        }

        let all = busyTotal + idleTotal
        guard all > 0 else { return nil }
        return Sample(total: busyTotal / all,
                      user: userTotal / all,
                      system: systemTotal / all)
    }
}
