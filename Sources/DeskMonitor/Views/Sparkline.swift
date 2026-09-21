import SwiftUI

/// 固定槽位的迷你折线图：新数据从右侧推入，左侧不足处留空，
/// 这样曲线的横轴始终代表同一段时间跨度。
struct Sparkline: View {

    var values: [Double]
    var maxValue: Double
    var tint: Color

    var body: some View {
        GeometryReader { geometry in
            let points = normalized(width: geometry.size.width, height: geometry.size.height)
            ZStack {
                area(points, height: geometry.size.height)
                    .fill(LinearGradient(colors: [tint.opacity(0.45), tint.opacity(0.03)],
                                         startPoint: .top, endPoint: .bottom))
                line(points)
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func normalized(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let slots = MetricsEngine.historyLength
        let padded = Array(repeating: 0.0, count: max(0, slots - values.count)) + values.suffix(slots)
        let ceiling = max(maxValue, 0.0001)
        let step = width / CGFloat(max(slots - 1, 1))
        return padded.enumerated().map { index, value in
            let ratio = min(max(value / ceiling, 0), 1)
            return CGPoint(x: CGFloat(index) * step, y: height - CGFloat(ratio) * height)
        }
    }

    private func line(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    private func area(_ points: [CGPoint], height: CGFloat) -> Path {
        var path = line(points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.addLine(to: CGPoint(x: first.x, y: height))
        path.closeSubpath()
        return path
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
