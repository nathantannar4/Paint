//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Blend modes and compositing, compared with SwiftUI's own rendering.
struct BlendingDemo: View {

    @State private var source = RGBAColor(red: 0.95, green: 0.3, blue: 0.5, alpha: 0.8)
    @State private var backdrop = RGBAColor(red: 0.2, green: 0.6, blue: 0.9)

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        DemoPage("Blending") {
            DemoSection("Colors") {
                ColorField("Source", color: $source, supportsOpacity: true)
                ColorField("Backdrop", color: $backdrop, supportsOpacity: true)
                HStack(spacing: 4) {
                    Swatch(source, label: "Source")
                    Swatch(backdrop, label: "Backdrop")
                    Swatch(source.composited(over: backdrop), label: "composited(over:)")
                }
            }

            DemoSection(
                "Blend Modes",
                caption: "blended(over:mode:) follows the W3C Compositing and Blending spec. In each pair, the left is computed by Paint and the right is drawn by SwiftUI with blendMode(_:), so they should match."
            ) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ColorBlendMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(title: mode))
                                .font(.caption.weight(.medium))
                            HStack(spacing: 2) {
                                Swatch(source.blended(over: backdrop, mode: mode), height: 44)
                                ZStack {
                                    Checkerboard()
                                    ZStack {
                                        Color(backdrop)
                                        Color(source).blendMode(mode.swiftUI)
                                    }
                                    .compositingGroup()
                                }
                                .frame(height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
    }
}

extension ColorBlendMode {
    var swiftUI: BlendMode {
        switch self {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        case .overlay: .overlay
        case .darken: .darken
        case .lighten: .lighten
        case .colorDodge: .colorDodge
        case .colorBurn: .colorBurn
        case .hardLight: .hardLight
        case .softLight: .softLight
        case .difference: .difference
        case .exclusion: .exclusion
        case .hue: .hue
        case .saturation: .saturation
        case .color: .color
        case .luminosity: .luminosity
        }
    }
}

#Preview {
    NavigationStack { BlendingDemo() }
}
