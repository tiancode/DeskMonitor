import SwiftUI

/// 固定槽位的迷你折线图：新数据从右侧推入，左侧不足处留空，
/// 这样曲线的横轴始终代表同一段时间跨度。
struct Sparkline: View {

    var values: [Double]
    var maxValue: Double
    var tint: Color

    var body: some View {
        GeometryReader { geometry in
            let shape = paths(in: geometry.size)
            ZStack {
                shape.area
                    .fill(LinearGradient(colors: [tint.opacity(0.45), tint.opacity(0.03)],
                                         startPoint: .top, endPoint: .bottom))
                shape.line
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// 一趟扫完同时产出折线和填充区，不铺中间数组。
    private func paths(in size: CGSize) -> (line: Path, area: Path) {
        let slots = MetricsEngine.historyLength
        let tail = values.suffix(slots)
        let leading = slots - tail.count                 // 左侧留空的槽位数
        let ceiling = max(maxValue, 0.0001)
        let step = size.width / CGFloat(max(slots - 1, 1))

        var line = Path()
        for index in 0..<slots {
            let value = index < leading ? 0 : tail[tail.startIndex + (index - leading)]
            let ratio = min(max(value / ceiling, 0), 1)
            let point = CGPoint(x: CGFloat(index) * step, y: size.height - CGFloat(ratio) * size.height)
            if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
        }

        var area = line
        area.addLine(to: CGPoint(x: CGFloat(slots - 1) * step, y: size.height))
        area.addLine(to: CGPoint(x: 0, y: size.height))
        area.closeSubpath()
        return (line, area)
    }
}

/// 两路数据共用一条基线，一路向上一路向下（硬盘的读/写、网络的下行/上行）。
struct MirroredSparkline: View {

    var up: [Double]
    var down: [Double]
    var maxValue: Double
    var upTint: Color
    var downTint: Color

    var body: some View {
        GeometryReader { geometry in
            let half = geometry.size.height / 2
            VStack(spacing: 0) {
                Sparkline(values: up, maxValue: maxValue, tint: upTint)
                    .frame(height: half)
                Sparkline(values: down, maxValue: maxValue, tint: downTint)
                    .frame(height: half)
                    .scaleEffect(y: -1, anchor: .center)
            }
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(height: 1)
            }
        }
    }
}
