import SwiftUI
import UIKit

enum BoardEffect: String, CaseIterable, Identifiable {
    case marquee, `static`, blink, alternate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .marquee: return "Scroll"
        case .static: return "Static"
        case .blink: return "Blink"
        case .alternate: return "Alternate"
        }
    }
}

enum PanelLook: String, CaseIterable, Identifiable {
    case dot, neon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dot: return "Dot matrix"
        case .neon: return "Neon glow"
        }
    }
}

enum BoardFont: String, CaseIterable, Identifiable {
    case condensed, grotesk, mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .condensed: return "Condensed"
        case .grotesk: return "Grotesk"
        case .mono: return "Mono"
        }
    }

    func uiFont(size: CGFloat) -> UIFont {
        switch self {
        case .condensed:
            return UIFont(name: "BebasNeue-Regular", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: .bold)
        case .grotesk:
            return UIFont(name: "SpaceGrotesk-Bold", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: .bold)
        case .mono:
            return UIFont(name: "DMMono-Medium", size: size)
                ?? UIFont.monospacedSystemFont(ofSize: size, weight: .medium)
        }
    }
}

final class BoardSettings: ObservableObject {
    @Published var text: String = "Welcome Thao & Dung ❤️"
    @Published var effect: BoardEffect = .marquee
    @Published var rainbow: Bool = false
    @Published var speed: Double = 5        // 1...10
    @Published var size: Double = 0.6       // fraction of panel height (0.2...1.0)
    @Published var textColor: Color = Color(red: 1.0, green: 0.23, blue: 0.42)
    @Published var bgColor: Color = .black
    @Published var look: PanelLook = .dot
    @Published var font: BoardFont = .condensed
}
