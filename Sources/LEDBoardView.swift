import SwiftUI

/// Full-screen LED panel. Renders the message as a dot matrix or neon glow,
/// animated according to the selected effect.
struct LEDBoardView: View {
    @ObservedObject var settings: BoardSettings

    /// Target spacing between LED dots, in points.
    private let dotPitch: CGFloat = 7

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { ctx, size in
                var context = ctx
                draw(context: &context, size: size,
                     time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .background(settings.bgColor)
        .ignoresSafeArea()
    }

    private func draw(context: inout GraphicsContext, size: CGSize, time: Double) {
        let rows = max(8, Int(size.height / dotPitch))
        let screenCols = max(8, Int(size.width / dotPitch))
        let pitchX = size.width / CGFloat(screenCols)
        let pitchY = size.height / CGFloat(rows)
        let speed = settings.speed

        // MARK: Effect state
        var visible = true
        var text = settings.text

        switch settings.effect {
        case .blink:
            let period = max(0.2, 1.6 - 0.13 * speed)
            visible = time.truncatingRemainder(dividingBy: period * 2) < period * 1.4
        case .alternate:
            let lines = settings.text.components(separatedBy: "\n").filter { !$0.isEmpty }
            if lines.count > 1 {
                let period = max(0.3, 2.4 - 0.2 * speed)
                text = lines[Int(time / period) % lines.count]
            }
        case .marquee, .static:
            break
        }

        guard visible, !text.isEmpty else { return }

        let isMarquee = settings.effect == .marquee
        let renderText = isMarquee
            ? text.components(separatedBy: "\n").joined(separator: "   ")
            : text

        let color: Color = settings.rainbow
            ? Color(hue: (time * 0.05 * speed).truncatingRemainder(dividingBy: 1),
                    saturation: 0.9, brightness: 1.0)
            : settings.textColor

        if settings.look == .dot {
            drawDots(context: &context, size: size, rows: rows, screenCols: screenCols,
                     pitchX: pitchX, pitchY: pitchY, text: renderText,
                     isMarquee: isMarquee, time: time, speed: speed, color: color)
        } else {
            drawNeon(context: &context, size: size, text: renderText,
                     isMarquee: isMarquee, time: time, speed: speed, color: color)
        }
    }

    // MARK: - Dot matrix

    private func drawDots(context: inout GraphicsContext, size: CGSize,
                          rows: Int, screenCols: Int,
                          pitchX: CGFloat, pitchY: CGFloat,
                          text: String, isMarquee: Bool,
                          time: Double, speed: Double, color: Color) {
        let grid = RasterCache.shared.grid(text: text, font: settings.font,
                                           sizeFraction: settings.size,
                                           rows: rows,
                                           fixedCols: isMarquee ? nil : screenCols)

        // Horizontal scroll offset (in dots) for the marquee effect.
        var textLeftEdge = 0
        if isMarquee {
            let range = screenCols + grid.cols
            let dotsPerSecond = 6 + speed * 7
            let scrolled = Int((time * dotsPerSecond).truncatingRemainder(dividingBy: Double(range)))
            textLeftEdge = screenCols - scrolled
        }

        // Faint unlit dots give the panel a realistic LED texture.
        var unlit = Path()
        var litPath = Path()
        let dotW = pitchX * 0.72
        let dotH = pitchY * 0.72

        for r in 0..<rows {
            let y = CGFloat(r) * pitchY + (pitchY - dotH) / 2
            for c in 0..<screenCols {
                let rect = CGRect(x: CGFloat(c) * pitchX + (pitchX - dotW) / 2,
                                  y: y, width: dotW, height: dotH)
                let sourceCol = c - textLeftEdge
                let isLit = sourceCol >= 0 && sourceCol < grid.cols
                    && grid.lit[r * grid.cols + sourceCol]
                if isLit {
                    litPath.addEllipse(in: rect)
                } else {
                    unlit.addEllipse(in: rect)
                }
            }
        }

        context.fill(unlit, with: .color(color.opacity(0.07)))
        context.fill(litPath, with: .color(color))
    }

    // MARK: - Neon glow

    private func drawNeon(context: inout GraphicsContext, size: CGSize,
                          text: String, isMarquee: Bool,
                          time: Double, speed: Double, color: Color) {
        let uiColor = UIColor(color)
        let image = RasterCache.shared.neonImage(text: text, font: settings.font,
                                                 sizeFraction: settings.size,
                                                 panelSize: size,
                                                 fixedWidth: !isMarquee,
                                                 color: uiColor)
        let pointSize = image.size // already in points

        var x: CGFloat = 0
        if isMarquee {
            let range = size.width + pointSize.width
            let pointsPerSecond = (6 + speed * 7) * dotPitch
            let scrolled = (time * pointsPerSecond).truncatingRemainder(dividingBy: range)
            x = size.width - scrolled
        }

        let rect = CGRect(origin: CGPoint(x: x, y: 0), size: pointSize)
        let resolved = context.resolve(Image(uiImage: image))

        // Layered shadows create the glow; final pass is the bright core.
        var glow = context
        glow.addFilter(.shadow(color: color.opacity(0.9), radius: 18))
        glow.addFilter(.shadow(color: color.opacity(0.7), radius: 8))
        glow.draw(resolved, in: rect)
        context.draw(resolved, in: rect)
    }
}
