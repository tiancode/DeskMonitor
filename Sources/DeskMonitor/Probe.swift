import Foundation

/// `DeskMonitor --probe` 用纯文本打印几轮采样，方便和活动监视器 / netstat 对照校验。
enum Probe {

    static func run(rounds: Int = 5, interval: TimeInterval = 1.0) {
        let cpu = CPUMonitor()
        let gpu = GPUMonitor()
        let memory = MemoryMonitor()
        let disk = DiskMonitor()
        let network = NetworkMonitor()

        for round in 0...rounds {
            let cpuSample = cpu.read()
            let gpuSample = gpu.read()
            let memorySample = memory.read()
            let diskSample = disk.read()
            let networkSample = network.read()

            if round > 0 {
                let cpuText = cpuSample.map { Format.percent($0.total) } ?? "n/a"
                let gpuText = gpuSample.map { Format.percent($0) } ?? "n/a (无 IOAccelerator)"
                let memoryText = memorySample.map {
                    "\(Format.size($0.used)) / \(Format.size($0.total))  [应用 \(Format.size($0.app)) · 联动 \(Format.size($0.wired)) · 压缩 \(Format.size($0.compressed))]"
                } ?? "n/a"
                let diskText = diskSample.map {
                    "读 \(Format.speed($0.readBytesPerSecond))  写 \(Format.speed($0.writeBytesPerSecond))"
                } ?? "n/a"

                let networkText = networkSample.map {
                    "↓ \(Format.speed($0.download))  ↑ \(Format.speed($0.upload))  [\($0.interface)]  会话 ↓\(Format.size($0.sessionReceived)) ↑\(Format.size($0.sessionSent))"
                } ?? "n/a"

                print("#\(round)  CPU \(cpuText)   GPU \(gpuText)")
                print("     内存 \(memoryText)")
                print("     硬盘 \(diskText)")
                print("     网络 \(networkText)")
            }
            if round < rounds { Thread.sleep(forTimeInterval: interval) }
        }

        if let capacity = disk.capacity() {
            print("启动盘 可用 \(Format.size(capacity.free)) / \(Format.size(capacity.total))")
        }
    }
}
