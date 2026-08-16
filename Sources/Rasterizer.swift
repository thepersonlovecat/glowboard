import UIKit
import SwiftUI

/// A sampled LED grid: one boolean per dot, row-major.
struct LEDGrid {
    let cols: Int
    let rows: Int
    let lit: [Bool]
}

/// Renders text into dot grids / glow images and memoizes the last result,
/// since the Canvas redraws every animation frame with identical input.
enum Rasterizer {

    // MARK: - Dot matrix

    static func grid(text: String, font: BoardFont, sizeFraction: Double,
                     rows: Int, fixedCols: Int?) -> LEDGrid {
        let rows = max(4, rows)
        let fontSize = max(4, CGFloat(rows) * CGFloat(sizeFraction))
        let uiFont = font.uiFont(size: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: uiFont,
            .foregroundColor: UIColor.white
        ]

        let lines = text.components(separatedBy: "\n")
        let lineHeight = uiFont.lineHeight * 1.08
        let contentH = lineHeight * CGFloat(lines.count)

        var contentW: CGFloat = 1
        for line in lines {
            contentW = max(contentW, (line as NSString).size(withAttributes: attrs).width)
        }

        let cols: Int
        if let fixed = fixedCols {
            cols = max(4, fixed)
        } else {
            cols = max(4, Int(ceil(contentW)) + 2)
        }

        guard let ctx = makeContext(cols: cols, rows: rows) else {
            return LEDGrid(cols: cols, rows: rows, lit: [Bool](repeating: false, count: cols * rows))
        }

        // CGContext origin is bottom-left; flip so UIKit draws top-down
        // and memory row 0 matches the top row of the panel.
        ctx.translateBy(x: 0, y: CGFloat(rows))
        ctx.scaleBy(x: 1, y: -1)

        UIGraphicsPushContext(ctx)
        let startY = (CGFloat(rows) - contentH) / 2
        for (i, line) in lines.enumerated() {
            let w = (line as NSString).size(withAttributes: attrs).width
            let x: CGFloat = fixedCols != nil ? (CGFloat(cols) - w) / 2 : 1
            (line as NSString).draw(at: CGPoint(x: x, y: startY + CGFloat(i) * lineHeight),
                                    withAttributes: attrs)
        }
        UIGraphicsPopContext()

        var lit = [Bool](repeating: false, count: cols * rows)
        if let data = ctx.data {
            let ptr = data.bindMemory(to: UInt8.self, capacity: cols * rows * 4)
            for i in 0..<(cols * rows) {
                let r = ptr[i * 4], g = ptr[i * 4 + 1], b = ptr[i * 4 + 2]
                lit[i] = max(r, max(g, b)) > 90
            }
        }
        return LEDGrid(cols: cols, rows: rows, lit: lit)
    }

    // MARK: - Neon glow

    /// Renders the text as a colored image sized to exactly cover the panel,
    /// ready to be drawn with shadow filters for the neon look.
    static func neonImage(text: String, font: BoardFont, sizeFraction: Double,
                          panelSize: CGSize, fixedWidth: Bool, color: UIColor) -> UIImage {
        // All measurements below are in points; the renderer scale keeps it crisp.
        let fontSize = max(8, panelSize.height * CGFloat(sizeFraction))
        let uiFont = font.uiFont(size: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: uiFont,
            .foregroundColor: color
        ]

        let lines = text.components(separatedBy: "\n")
        let lineHeight = uiFont.lineHeight * 1.08
        let contentH = lineHeight * CGFloat(lines.count)

        var contentW: CGFloat = 1
        for line in lines {
            contentW = max(contentW, (line as NSString).size(withAttributes: attrs).width)
        }

        let width = fixedWidth ? panelSize.width : contentW + 8
        let size = CGSize(width: ceil(width), height: ceil(panelSize.height))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let startY = (size.height - contentH) / 2
            for (i, line) in lines.enumerated() {
                let w = (line as NSString).size(withAttributes: attrs).width
                let x: CGFloat = fixedWidth ? (size.width - w) / 2 : 4
                (line as NSString).draw(at: CGPoint(x: x, y: startY + CGFloat(i) * lineHeight),
                                        withAttributes: attrs)
            }
        }
    }

    // MARK: - Helpers

    private static func makeContext(cols: Int, rows: Int) -> CGContext? {
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil, width: cols, height: rows,
                                  bitsPerComponent: 8, bytesPerRow: cols * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: info) else { return nil }
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: cols, height: rows))
        return ctx
    }
}

/// Memoization for rasterized content, keyed by everything that affects output.
/// The Canvas redraws many times per second, so anything that does not change
/// between frames (dot paths, glow images) is built once and reused.
final class RasterCache {
    static let shared = RasterCache()

    private struct GridKey: Hashable {
        let text: String
        let font: BoardFont
        let sizeFraction: Double
        let rows: Int
        let fixedCols: Int?
    }

    private struct PathKey: Hashable {
        let grid: GridKey
        let pitchX: CGFloat
        let pitchY: CGFloat
    }

    private struct UnlitKey: Hashable {
        let cols: Int
        let rows: Int
        let pitchX: CGFloat
        let pitchY: CGFloat
    }

    private struct NeonKey: Hashable {
        let text: String
        let font: BoardFont
        let sizeFraction: Double
        let panelW: CGFloat
        let panelH: CGFloat
        let fixedWidth: Bool
        let color: UIColor
    }

    private var gridKey: GridKey?
    private var gridValue: LEDGrid?
    private var pathKey: PathKey?
    private var litPath: Path?
    private var unlitKey: UnlitKey?
    private var unlitPath: Path?
    private var neonKey: NeonKey?
    private var neonValue: (image: UIImage, padding: CGFloat)?

    func grid(text: String, font: BoardFont, sizeFraction: Double,
              rows: Int, fixedCols: Int?) -> LEDGrid {
        let key = GridKey(text: text, font: font, sizeFraction: sizeFraction,
                          rows: rows, fixedCols: fixedCols)
        if key == gridKey, let value = gridValue { return value }
        let value = Rasterizer.grid(text: text, font: font, sizeFraction: sizeFraction,
                                    rows: rows, fixedCols: fixedCols)
        gridKey = key
        gridValue = value
        return value
    }

    /// Grid + pre-built dot path in panel coordinates. The caller only needs to
    /// translate the context when scrolling, instead of rebuilding thousands of
    /// ellipses every frame.
    func litDots(text: String, font: BoardFont, sizeFraction: Double,
                 rows: Int, fixedCols: Int?,
                 pitchX: CGFloat, pitchY: CGFloat) -> (grid: LEDGrid, path: Path) {
        let value = grid(text: text, font: font, sizeFraction: sizeFraction,
                         rows: rows, fixedCols: fixedCols)
        let key = PathKey(grid: gridKey!, pitchX: pitchX, pitchY: pitchY)
        if key == pathKey, let path = litPath { return (value, path) }

        let dotW = pitchX * 0.72
        let dotH = pitchY * 0.72
        var path = Path()
        for r in 0..<value.rows {
            let y = CGFloat(r) * pitchY + (pitchY - dotH) / 2
            for c in 0..<value.cols where value.lit[r * value.cols + c] {
                path.addEllipse(in: CGRect(x: CGFloat(c) * pitchX + (pitchX - dotW) / 2,
                                           y: y, width: dotW, height: dotH))
            }
        }
        pathKey = key
        litPath = path
        return (value, path)
    }

    /// Static background of faint unlit dots; depends only on panel geometry.
    func unlitDots(cols: Int, rows: Int, pitchX: CGFloat, pitchY: CGFloat) -> Path {
        let key = UnlitKey(cols: cols, rows: rows, pitchX: pitchX, pitchY: pitchY)
        if key == unlitKey, let path = unlitPath { return path }

        let dotW = pitchX * 0.72
        let dotH = pitchY * 0.72
        var path = Path()
        for r in 0..<rows {
            let y = CGFloat(r) * pitchY + (pitchY - dotH) / 2
            for c in 0..<cols {
                path.addEllipse(in: CGRect(x: CGFloat(c) * pitchX + (pitchX - dotW) / 2,
                                           y: y, width: dotW, height: dotH))
            }
        }
        unlitKey = key
        unlitPath = path
        return path
    }

    /// Neon text with the glow baked into a single image, so each frame is just
    /// one image draw instead of re-applying expensive shadow filters.
    func neonGlow(text: String, font: BoardFont, sizeFraction: Double,
                  panelSize: CGSize, fixedWidth: Bool, color: UIColor) -> (image: UIImage, padding: CGFloat) {
        let key = NeonKey(text: text, font: font, sizeFraction: sizeFraction,
                          panelW: panelSize.width, panelH: panelSize.height,
                          fixedWidth: fixedWidth, color: color)
        if key == neonKey, let value = neonValue { return value }

        let base = Rasterizer.neonImage(text: text, font: font, sizeFraction: sizeFraction,
                                        panelSize: panelSize, fixedWidth: fixedWidth,
                                        color: color)
        let padding: CGFloat = 32
        let glowSize = CGSize(width: base.size.width + padding * 2,
                              height: base.size.height + padding * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: glowSize, format: format).image { rctx in
            let cg = rctx.cgContext
            let rect = CGRect(origin: CGPoint(x: padding, y: padding), size: base.size)
            cg.setShadow(offset: .zero, blur: 22,
                         color: color.withAlphaComponent(0.9).cgColor)
            base.draw(in: rect)
            cg.setShadow(offset: .zero, blur: 9,
                         color: color.withAlphaComponent(0.8).cgColor)
            base.draw(in: rect)
            cg.setShadow(offset: .zero, blur: 0, color: nil)
            base.draw(in: rect)
        }
        let value = (image, padding)
        neonKey = key
        neonValue = value
        return value
    }
}
