import SwiftUI

struct ContentView: View {
    @StateObject private var settings = BoardSettings()
    @State private var showControls = true

    var body: some View {
        ZStack(alignment: .bottom) {
            LEDBoardView(settings: settings)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showControls.toggle()
                    }
                }

            if showControls {
                controlPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .statusBarHidden(!showControls)
        .preferredColorScheme(.dark)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Control panel

    private var controlPanel: some View {
        ScrollView {
            VStack(spacing: 14) {
                TextField("Your message", text: $settings.text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)

                Picker("Effect", selection: $settings.effect) {
                    ForEach(BoardEffect.allCases) { effect in
                        Text(effect.title).tag(effect)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Speed \(Int(settings.speed))")
                        .frame(width: 90, alignment: .leading)
                    Slider(value: $settings.speed, in: 1...10, step: 1)
                }

                HStack {
                    Text("Size \(Int(settings.size * 100))%")
                        .frame(width: 90, alignment: .leading)
                    Slider(value: $settings.size, in: 0.2...1.0, step: 0.05)
                }

                HStack {
                    ColorPicker("Text", selection: $settings.textColor, supportsOpacity: false)
                    Spacer()
                    ColorPicker("Background", selection: $settings.bgColor, supportsOpacity: false)
                }

                Toggle("Rainbow colour cycle", isOn: $settings.rainbow)

                Picker("Look", selection: $settings.look) {
                    ForEach(PanelLook.allCases) { look in
                        Text(look.title).tag(look)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Font", selection: $settings.font) {
                    ForEach(BoardFont.allCases) { font in
                        Text(font.title).tag(font)
                    }
                }
                .pickerStyle(.segmented)

                Text("Tap the board to hide this panel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .frame(maxHeight: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding()
    }

}

#Preview {
    ContentView()
}
