import SwiftUI

struct FlyOverlayView: View {
    static let viewSize: CGFloat = 120
    private let flyCount = 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas(opaque: false, colorMode: .extendedLinear) { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<flyCount {
                    let point = position(for: index, time: t, size: size)
                    drawFly(context: &context, at: point, angle: heading(for: index, time: t))
                }
            }
        }
        .frame(width: Self.viewSize, height: Self.viewSize)
        .background(.clear)
    }

    private func position(for index: Int, time: TimeInterval, size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let baseRadius = 12.0 + Double((index * 11) % 8) * 2.5
        let angularSpeed = 0.7 + Double((index * 13) % 7) * 0.12
        let phase = Double(index) * 1.37
        let wobble = sin(time * 2.8 + phase * 1.2) * 4.0
        let radius = baseRadius + wobble

        let x = center.x
            + CGFloat(cos(time * angularSpeed + phase) * radius)
            + CGFloat(sin(time * 4.4 + phase) * 2.5)
        let y = center.y
            + CGFloat(sin(time * (angularSpeed + 0.25) + phase * 0.9) * radius)
            + CGFloat(cos(time * 3.2 + phase) * 2.5)

        return CGPoint(
            x: min(max(6, x), size.width - 6),
            y: min(max(6, y), size.height - 6)
        )
    }

    private func heading(for index: Int, time: TimeInterval) -> CGFloat {
        let speed = 1.1 + Double((index * 7) % 5) * 0.2
        return CGFloat(time * speed + Double(index) * 0.8)
    }

    private func drawFly(context: inout GraphicsContext, at point: CGPoint, angle: CGFloat) {
        context.withCGContext { cg in
            cg.saveGState()
            cg.translateBy(x: point.x, y: point.y)
            cg.rotate(by: angle)

            // Wings — translucent
            cg.setFillColor(CGColor(red: 0.82, green: 0.87, blue: 0.95, alpha: 0.45))
            cg.fillEllipse(in: CGRect(x: -5.5, y: -2.5, width: 5.0, height: 3.0))
            cg.fillEllipse(in: CGRect(x: 0.5, y: -2.5, width: 5.0, height: 3.0))

            // Body — dark
            cg.setFillColor(CGColor(gray: 0.08, alpha: 0.92))
            cg.fillEllipse(in: CGRect(x: -1.8, y: -3.5, width: 3.6, height: 7.0))

            // Head
            cg.fillEllipse(in: CGRect(x: -1.2, y: -5.0, width: 2.4, height: 2.4))
            cg.restoreGState()
        }
    }
}
