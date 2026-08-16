import SwiftUI

/// Full-screen LED panel. Renders the message as a dot matrix or neon glow,
/// animated according to the selected effect.
struct LEDBoardView: View {
    @ObservedObject var settings: BoardSettings

    /// Number of LED rows across the panel height. Keeping this constant makes
    /// the board look identical on every screen size (dots scale with height).
    private let targetRows: CGFloat = 44

    /// Redraw rate matched to what the effect actually needs, instead of
    /// repainting at full display refresh (up to 120 Hz) all the time.
    private var frameInterval: Double {
        switch settings.effect {
        case .marquee:
            if settings.look == .dot {
                // Offset moves in whole dots, so rendering faster than the dot
                // rate produces identical frames.
                return 1.0 / min(60.0, 6 + settings.speed * 7)
            }
            return 1.0 / 60.0 // neon scrolls smoothly; each frame is one image draw
        case .blink:
            return 0.1
        case .alternate:
            return 0.25
        case .static:
            return settings.rainbow ? 1.0 / 30.0 : 1.0
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: frameInterval)) { timeline in
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
        let pitchY = size.height / targetRows
        let rows = max(8, Int(targetRows))
        let screenCols = max(8, Int(size.width / pitchY))
        let pitchX = size.width / CGFloat(screenCols)
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
            ? Color(hue: rainbowHue(time: time, speed: speed),
                    saturation: 0.9, brightness: 1.0)
            : settings.textColor

        if settings.look == .dot {
            drawDots(context: &context, rows: rows, screenCols: screenCols,
                     pitchX: pitchX, pitchY: pitchY, text: renderText,
                     isMarquee: isMarquee, time: time, speed: speed, color: color)
        } else {
            drawNeon(context: &context, size: size, text: renderText,
                     isMarquee: isMarquee, time: time, speed: speed,
                     dotPitch: pitchY, color: color)
        }
    }

    /// Hue is quantized so cached content (e.g. the neon glow image) stays
    /// valid across frames instead of being rebuilt for every tiny hue step.
    private func rainbowHue(time: Double, speed: Double) -> Double {
        let hue = (time * 0.05 * speed).truncatingRemainder(dividingBy: 1)
        return (hue * 60).rounded() / 60
    }

    // MARK: - Dot matrix

    private func drawDots(context: inout GraphicsContext,
                          rows: Int, screenCols: Int,
                          pitchX: CGFloat, pitchY: CGFloat,
                          text: String, isMarquee: Bool,
                          time: Double, speed: Double, color: Color) {
        let (grid, litPath) = RasterCache.shared.litDots(text: text, font: settings.font,
                                                         sizeFraction: settings.size,
                                                         rows: rows,
                                                         fixedCols: isMarquee ? nil : screenCols,
                                                         pitchX: pitchX, pitchY: pitchY)

        // Horizontal scroll offset (in dots) for the marquee effect.
        var textLeftEdge = 0
        if isMarquee {
            let range = screenCols + grid.cols
            let dotsPerSecond = 6 + speed * 7
            let scrolled = Int((time * dotsPerSecond).truncatingRemainder(dividingBy: Double(range)))
            textLeftEdge = screenCols - scrolled
        }

        // Faint unlit dots give the panel a realistic LED texture.
        let unlit = RasterCache.shared.unlitDots(cols: screenCols, rows: rows,
                                                 pitchX: pitchX, pitchY: pitchY)
        context.fill(unlit, with: .color(color.opacity(0.07)))

        // Cached dot path; scrolling is just a translation.
        var scrolledContext = context
        scrolledContext.translateBy(x: CGFloat(textLeftEdge) * pitchX, y: 0)
        scrolledContext.fill(litPath, with: .color(color))
    }

    // MARK: - Neon glow

    private func drawNeon(context: inout GraphicsContext, size: CGSize,
                          text: String, isMarquee: Bool,
                          time: Double, speed: Double,
                          dotPitch: CGFloat, color: Color) {
        // Glow is baked into the cached image; a frame costs one image draw.
        let (image, padding) = RasterCache.shared.neonGlow(text: text, font: settings.font,
                                                           sizeFraction: settings.size,
                                                           panelSize: size,
                                                           fixedWidth: !isMarquee,
                                                           color: UIColor(color))
        let contentWidth = image.size.width - padding * 2

        var x: CGFloat = 0
        if isMarquee {
            let range = size.width + contentWidth
            let pointsPerSecond = (6 + speed * 7) * dotPitch
            let scrolled = (time * pointsPerSecond).truncatingRemainder(dividingBy: range)
            x = size.width - scrolled
        }

        let rect = CGRect(x: x - padding, y: -padding, size: image.size)
        context.draw(Image(uiImage: image), in: rect)
    }
}
