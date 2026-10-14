import SwiftUI

/// Diagram explaining the airflow direction: the unit on the wall and the airflow arrow.
/// - Up/down: side view (wall on the left, floor below).
/// - Left/right: top view (wall on top, room below).
struct AirflowDiagram: View {
    let axis: Axis
    let angle: Double        // degrees, see `Axis.airAngle`
    let swinging: Bool
    let fixed: Bool          // a position is chosen (otherwise drawn faded)
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let structure = GraphicsContext.Shading.color(.secondary.opacity(0.7))
            let air = GraphicsContext.Shading.color(color.opacity(fixed || swinging ? 1 : 0.35))

            // Wall, floor and unit
            let origin: CGPoint
            let base: Double  // "straight" airflow direction, in degrees (0 = right, 90 = down)
            if axis == .vertical {
                var walls = Path()
                walls.move(to: CGPoint(x: s * 0.1, y: s * 0.06))
                walls.addLine(to: CGPoint(x: s * 0.1, y: s * 0.9))
                walls.addLine(to: CGPoint(x: s * 0.94, y: s * 0.9))
                context.stroke(walls, with: structure, lineWidth: 1.5)
                let unit = CGRect(x: s * 0.1, y: s * 0.14, width: s * 0.26, height: s * 0.14)
                context.fill(Path(roundedRect: unit, cornerRadius: 2), with: structure)
                origin = CGPoint(x: unit.maxX, y: unit.maxY - s * 0.02)
                base = 0
            } else {
                var wall = Path()
                wall.move(to: CGPoint(x: s * 0.06, y: s * 0.1))
                wall.addLine(to: CGPoint(x: s * 0.94, y: s * 0.1))
                context.stroke(wall, with: structure, lineWidth: 1.5)
                let unit = CGRect(x: s * 0.32, y: s * 0.1, width: s * 0.36, height: s * 0.12)
                context.fill(Path(roundedRect: unit, cornerRadius: 2), with: structure)
                origin = CGPoint(x: unit.midX, y: unit.maxY)
                base = 90
            }

            let length = s * (axis == .vertical ? 0.55 : 0.6)

            // Swinging: a fan covering the swept range
            if swinging {
                var fan = Path()
                fan.move(to: origin)
                fan.addArc(center: origin, radius: length,
                           startAngle: .degrees(base + axis.sweep.lowerBound),
                           endAngle: .degrees(base + axis.sweep.upperBound), clockwise: false)
                fan.closeSubpath()
                context.fill(fan, with: .color(color.opacity(0.22)))
                for edge in [axis.sweep.lowerBound, axis.sweep.upperBound] {
                    drawArrow(context, from: origin, degrees: base + edge, length: length, shading: air)
                }
            } else {
                drawArrow(context, from: origin, degrees: base + angle, length: length, shading: air)
            }
        }
    }

    private func drawArrow(_ context: GraphicsContext, from start: CGPoint, degrees: Double, length: CGFloat,
                           shading: GraphicsContext.Shading) {
        let radians = CGFloat(degrees * .pi / 180)
        let end = CGPoint(x: start.x + cos(radians) * length, y: start.y + sin(radians) * length)
        var line = Path()
        line.move(to: start)
        line.addLine(to: end)
        context.stroke(line, with: shading, style: StrokeStyle(lineWidth: 2, lineCap: .round))

        let head: CGFloat = 5
        var tip = Path()
        tip.move(to: end)
        tip.addLine(to: CGPoint(x: end.x - cos(radians - 0.5) * head, y: end.y - sin(radians - 0.5) * head))
        tip.move(to: end)
        tip.addLine(to: CGPoint(x: end.x - cos(radians + 0.5) * head, y: end.y - sin(radians + 0.5) * head))
        context.stroke(tip, with: shading, style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}
