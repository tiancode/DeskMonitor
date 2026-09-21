import SwiftUI

struct DashboardView: View {

    @ObservedObject var engine: MetricsEngine

    private let cpuTint = Color(red: 0.32, green: 0.78, blue: 0.94)
    private let gpuTint = Color(red: 0.69, green: 0.56, blue: 0.98)
    private let memoryTint = Color(red: 0.99, green: 0.69, blue: 0.33)
    private let readTint = Color(red: 0.36, green: 0.86, blue: 0.72)
    private let writeTint = Color(red: 0.98, green: 0.51, blue: 0.62)
    private let downloadTint = Color(red: 0.45, green: 0.72, blue: 0.98)
    private let uploadTint = Color(red: 0.98, green: 0.80, blue: 0.40)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(spacing: 14) {
                cpuSection
                gpuSection
                memorySection
                diskSection
                networkSection
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .frame(width: 272)
        .background {
            ZStack {
                VisualEffectView()
                Color.black.opacity(0.28)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(LinearGradient(colors: [cpuTint, gpuTint], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 7, height: 7)
            Text("系统监视")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(String(format: "%.1fs", engine.interval))
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .monospacedDigit()
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 9)
        .background(.white.opacity(0.04))
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
        }
    }

    // MARK: - 指标

    private var cpuSection: some View {
        MetricBlock(title: "CPU",
                    value: Format.percent(engine.cpu),
                    caption: "用户 \(Format.percent(engine.cpuUser, decimals: 0)) · 系统 \(Format.percent(engine.cpuSystem, decimals: 0))",
                    tint: cpuTint) {
            Sparkline(values: engine.cpuHistory, maxValue: 1.0, tint: cpuTint)
        }
    }

    private var gpuSection: some View {
        let peak = engine.gpuHistory.max() ?? 0
        return MetricBlock(title: "GPU",
                           value: engine.gpuAvailable ? Format.percent(engine.gpu) : "—",
                           caption: engine.gpuAvailable
                               ? "近 \(Int(Double(MetricsEngine.historyLength) * engine.interval)) 秒峰值 \(Format.percent(peak))"
                               : "未检测到 IOAccelerator",
                           tint: gpuTint) {
            Sparkline(values: engine.gpuHistory, maxValue: 1.0, tint: gpuTint)
        }
    }

    private var memorySection: some View {
        let ratio = engine.memoryTotal > 0 ? Double(engine.memoryUsed) / Double(engine.memoryTotal) : 0
        return MetricBlock(title: "内存",
                           value: Format.percent(ratio),
                           caption: "\(Format.size(engine.memoryUsed)) / \(Format.size(engine.memoryTotal))"
                               + (engine.swapUsed > 0 ? " · 交换 \(Format.size(engine.swapUsed))" : ""),
                           tint: memoryTint,
                           badge: pressureBadge) {
            SegmentedBar(segments: [
                .init(fraction: fraction(engine.memoryApp), color: memoryTint),
                .init(fraction: fraction(engine.memoryWired), color: memoryTint.opacity(0.75)),
                .init(fraction: fraction(engine.memoryCompressed), color: Color(red: 0.95, green: 0.85, blue: 0.4))
            ])
        }
    }

    private var diskSection: some View {
        TrafficBlock(title: "硬盘",
                     downValue: engine.diskRead,
                     upValue: engine.diskWrite,
                     downHistory: engine.readHistory,
                     upHistory: engine.writeHistory,
                     downTint: readTint,
                     upTint: writeTint,
                     floor: 1_000_000,
                     caption: engine.diskCapacity > 0
                         ? "可用 \(Format.size(engine.diskFree)) / \(Format.size(engine.diskCapacity))"
                         : "读 / 写")
    }

    private var networkSection: some View {
        TrafficBlock(title: "网络",
                     downValue: engine.networkDownload,
                     upValue: engine.networkUpload,
                     downHistory: engine.downloadHistory,
                     upHistory: engine.uploadHistory,
                     downTint: downloadTint,
                     upTint: uploadTint,
                     floor: 125_000,
                     caption: "\(engine.networkInterface) · 会话 ↓\(Format.size(engine.sessionReceived)) ↑\(Format.size(engine.sessionSent))")
    }

    /// 「已用」高不等于吃紧：macOS 会把空闲内存拿去做缓存，真正的信号是内存压力。
    private var pressureBadge: MetricBlock<SegmentedBar>.Badge {
        switch engine.memoryPressure {
        case 1.0: return .init(text: "压力紧急", color: Color(red: 0.98, green: 0.42, blue: 0.42))
        case 0.5: return .init(text: "压力警告", color: Color(red: 0.98, green: 0.78, blue: 0.35))
        default: return .init(text: "压力正常", color: Color(red: 0.45, green: 0.85, blue: 0.55))
        }
    }

    private func fraction(_ bytes: UInt64) -> Double {
        engine.memoryTotal > 0 ? Double(bytes) / Double(engine.memoryTotal) : 0
    }
}

// MARK: - 复用组件

struct MetricBlock<Content: View>: View {

    struct Badge {
        var text: String
        var color: Color
    }

    var title: String
    var value: String
    var caption: String
    var tint: Color
    var badge: Badge? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                if let badge {
                    HStack(spacing: 3) {
                        Circle().fill(badge.color).frame(width: 5, height: 5)
                        Text(badge.text)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(badge.color.opacity(0.9))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(badge.color.opacity(0.14), in: Capsule())
                }
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
            content
                .frame(height: 26)
            Text(caption)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
                .monospacedDigit()
        }
    }
}

struct SegmentedBar: View {

    struct Segment {
        var fraction: Double
        var color: Color
    }

    var segments: [Segment]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.09))
                HStack(spacing: 1) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: max(0, geometry.size.width * min(segment.fraction, 1)))
                    }
                    Spacer(minLength: 0)
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: 7)
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

/// 双向速率块：上行/下行（或读/写）共用一条基线的镜像折线。
struct TrafficBlock: View {

    var title: String
    var downValue: Double
    var upValue: Double
    var downHistory: [Double]
    var upHistory: [Double]
    var downTint: Color
    var upTint: Color
    /// 纵轴下限，避免完全空闲时把噪声放大成满屏尖峰
    var floor: Double
    var caption: String

    var body: some View {
        let peak = max((downHistory + upHistory).max() ?? 0, floor)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
                Label(Format.speed(downValue), systemImage: "arrow.down")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(downTint)
                    .monospacedDigit()
                Label(Format.speed(upValue), systemImage: "arrow.up")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(upTint)
                    .monospacedDigit()
            }
            MirroredSparkline(up: downHistory,
                              down: upHistory,
                              maxValue: peak,
                              upTint: downTint,
                              downTint: upTint)
                .frame(height: 30)
            Text("\(caption) · 峰值 \(Format.speed(peak))")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
