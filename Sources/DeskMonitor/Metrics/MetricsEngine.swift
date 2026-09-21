import Combine
import Foundation

/// 统一采样调度：后台队列取数，主线程发布，供 SwiftUI 绑定。
final class MetricsEngine: ObservableObject {

    static let historyLength = 60

    @Published private(set) var cpu = 0.0
    @Published private(set) var cpuUser = 0.0
    @Published private(set) var cpuSystem = 0.0
    @Published private(set) var cpuHistory = [Double]()

    @Published private(set) var gpu = 0.0
    @Published private(set) var gpuHistory = [Double]()
    @Published private(set) var gpuAvailable = true

    @Published private(set) var memoryUsed: UInt64 = 0
    @Published private(set) var memoryTotal: UInt64 = 0
    @Published private(set) var memoryApp: UInt64 = 0
    @Published private(set) var memoryWired: UInt64 = 0
    @Published private(set) var memoryCompressed: UInt64 = 0
    @Published private(set) var memoryPressure = 0.0
    @Published private(set) var swapUsed: UInt64 = 0

    @Published private(set) var diskRead = 0.0
    @Published private(set) var diskWrite = 0.0
    @Published private(set) var readHistory = [Double]()
    @Published private(set) var writeHistory = [Double]()
    @Published private(set) var diskFree: UInt64 = 0
    @Published private(set) var diskCapacity: UInt64 = 0

    @Published private(set) var networkDownload = 0.0
    @Published private(set) var networkUpload = 0.0
    @Published private(set) var downloadHistory = [Double]()
    @Published private(set) var uploadHistory = [Double]()
    @Published private(set) var networkInterface = "—"
    @Published private(set) var sessionReceived: UInt64 = 0
    @Published private(set) var sessionSent: UInt64 = 0

    @Published var interval: TimeInterval {
        didSet {
            UserDefaults.standard.set(interval, forKey: "refreshInterval")
            restart()
        }
    }

    private let cpuMonitor = CPUMonitor()
    private let gpuMonitor = GPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let diskMonitor = DiskMonitor()
    private let networkMonitor = NetworkMonitor()

    private let queue = DispatchQueue(label: "com.deskmonitor.sampler", qos: .utility)
    private var timer: DispatchSourceTimer?

    init() {
        let stored = UserDefaults.standard.double(forKey: "refreshInterval")
        interval = stored > 0 ? stored : 1.0
        memoryTotal = memoryMonitor.total
        restart()
    }

    private func restart() {
        timer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.05, repeating: interval, leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in self?.sample() }
        timer.resume()
        self.timer = timer
    }

    private func sample() {
        let cpuSample = cpuMonitor.read()
        let gpuSample = gpuMonitor.read()
        let memorySample = memoryMonitor.read()
        let diskSample = diskMonitor.read()
        let networkSample = networkMonitor.read()

        let capacity = diskMonitor.capacity()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if let cpuSample {
                cpu = cpuSample.total
                cpuUser = cpuSample.user
                cpuSystem = cpuSample.system
                Self.append(cpuSample.total, to: &cpuHistory)
            }

            if let gpuSample {
                gpuAvailable = true
                gpu = gpuSample
                Self.append(gpuSample, to: &gpuHistory)
            } else {
                gpuAvailable = false
            }

            if let memorySample {
                memoryUsed = memorySample.used
                memoryApp = memorySample.app
                memoryWired = memorySample.wired
                memoryCompressed = memorySample.compressed
                memoryPressure = memorySample.pressure
                swapUsed = memorySample.swapUsed
            }

            if let diskSample {
                diskRead = diskSample.readBytesPerSecond
                diskWrite = diskSample.writeBytesPerSecond
                Self.append(diskSample.readBytesPerSecond, to: &readHistory)
                Self.append(diskSample.writeBytesPerSecond, to: &writeHistory)
            }

            if let networkSample {
                networkDownload = networkSample.download
                networkUpload = networkSample.upload
                networkInterface = networkSample.interface
                sessionReceived = networkSample.sessionReceived
                sessionSent = networkSample.sessionSent
                Self.append(networkSample.download, to: &downloadHistory)
                Self.append(networkSample.upload, to: &uploadHistory)
            }

            if let capacity {
                diskFree = capacity.free
                diskCapacity = capacity.total
            }
        }
    }

    private static func append(_ value: Double, to history: inout [Double]) {
        history.append(value)
        if history.count > historyLength {
            history.removeFirst(history.count - historyLength)
        }
    }
}
