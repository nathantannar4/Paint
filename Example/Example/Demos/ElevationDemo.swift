//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Tinted shadows, and surfaces raised by elevation.
struct ElevationDemo: View {

    @State private var background = RGBAColor(red: 0.86, green: 0.92, blue: 1)
    @State private var opacity = 0.35
    @State private var darkSurface = RGBAColor(red: 0.07, green: 0.07, blue: 0.08)
    @State private var lightSurface = RGBAColor(red: 0.98, green: 0.98, blue: 0.99)
    @State private var tint = RGBAColor(red: 0.23, green: 0.51, blue: 0.96)
    @State private var isTinted = false

    var body: some View {
        DemoPage("Shadows & Elevation") {
            DemoSection(
                "Tinted Shadows",
                caption: "shadow(opacity:) gives a shadow for content on a background: a darker version of the background, keeping its hue. A black shadow on a colored background looks gray and dirty; the tinted one looks rich."
            ) {
                ColorField("Background", color: $background)
                LabeledSlider("Opacity", value: $opacity, in: 0...1)
                HStack(spacing: 24) {
                    card(title: "Black", shadow: RGBAColor(red: 0, green: 0, blue: 0, alpha: opacity))
                    card(title: "shadow()", shadow: background.shadow(opacity: opacity).toRGBAColor())
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(Color(background), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Swatch(background.shadow(opacity: 1), label: "Shadow color, opaque")
            }

            DemoSection(
                "Elevation",
                caption: "Shadows are hard to see on dark backgrounds, so elevated(level:) shows elevation by lightening dark surfaces, for levels 1 to 5, as iOS and Material Design do. Light surfaces are unchanged. elevated(level:tint:) tints raised surfaces towards an accent, in both appearances."
            ) {
                ColorField("Dark surface", color: $darkSurface)
                ColorField("Light surface", color: $lightSurface)
                Toggle("Tint with elevated(level:tint:)", isOn: $isTinted)
                if isTinted {
                    ColorField("Tint", color: $tint)
                }
                elevationRow(surface: darkSurface)
                elevationRow(surface: lightSurface)
            }
        }
    }

    private func card(title: String, shadow: RGBAColor) -> some View {
        Text(title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color(shadow), radius: 16, y: 8)
    }

    private func elevationRow(surface: RGBAColor) -> some View {
        HStack(spacing: 8) {
            ForEach(0...5, id: \.self) { level in
                let color = isTinted ? surface.elevated(level: level, tint: tint) : surface.elevated(level: level)
                VStack(spacing: 2) {
                    Text("Level \(level)")
                        .font(.caption.weight(.semibold))
                    Text(color.toHEXColor().toString(includePrefix: true))
                        .font(.caption2.monospaced())
                }
                .foregroundStyle(color.contrast(.apca).isDark ? Color.white : .black)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Color(color), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color(surface.shadow(opacity: 0.08 * Double(level))), radius: Double(level) * 2, y: Double(level))
            }
        }
        .padding(12)
        .background(Color(surface), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack { ElevationDemo() }
}
