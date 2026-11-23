//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Adaptive colors: transforming system colors, and colors for each appearance.
struct SwiftUIDemo: View {

    @Environment(\.self) private var environment
    @State private var lightColor = RGBAColor(red: 0.04, green: 0.52, blue: 1)

    /// A background with a color for each appearance, backed by a dynamic `UIColor` or
    /// `NSColor`, so it's a `Color` that `transformed(with:_:)` can resolve.
    private let background = Self.dynamicColor(light: HEXColor("#FFFFFF"), dark: HEXColor("#1C1C1E"))

    /// A SwiftUI `Color` backed by a dynamic `UIColor` or `NSColor`.
    private static func dynamicColor<Light: ColorConvertible, Dark: ColorConvertible>(
        light: Light,
        dark: Dark
    ) -> Color {
        #if os(macOS)
        Color(nsColor: NSColor(light: light, dark: dark))
        #else
        Color(uiColor: UIColor(light: light, dark: dark))
        #endif
    }

    /// A SwiftUI `Color` backed by a dynamic `UIColor` or `NSColor`, with high contrast
    /// colors.
    private static func dynamicColor<
        Light: ColorConvertible,
        Dark: ColorConvertible,
        LightHighContrast: ColorConvertible,
        DarkHighContrast: ColorConvertible
    >(
        light: Light,
        dark: Dark,
        lightHighContrast: LightHighContrast,
        darkHighContrast: DarkHighContrast
    ) -> Color {
        #if os(macOS)
        Color(nsColor: NSColor(light: light, dark: dark, lightHighContrast: lightHighContrast, darkHighContrast: darkHighContrast))
        #else
        Color(uiColor: UIColor(light: light, dark: dark, lightHighContrast: lightHighContrast, darkHighContrast: darkHighContrast))
        #endif
    }

    private let systemColors: [(String, Color)] = [
        ("accentColor", .accentColor),
        ("blue", .blue),
        ("orange", .orange),
        ("green", .green),
        ("primary", .primary),
    ]

    var body: some View {
        DemoPage("SwiftUI") {
            DemoSection(
                "Transforming System Colors",
                caption: "System colors have different components in light and dark mode, so they can't be transformed once. Color.transformed(_:) returns a ShapeStyle that resolves the color in its environment first."
            ) {
                HStack(alignment: .top, spacing: 12) {
                    transformedColumn.environment(\.colorScheme, .light)
                    transformedColumn.environment(\.colorScheme, .dark)
                }
            }

            DemoSection(
                "Relative to Another Color",
                caption: "transformed(with:_:) resolves two colors in the same environment, so a color can be adjusted against an adaptive background."
            ) {
                HStack(spacing: 12) {
                    readableSample.environment(\.colorScheme, .light)
                    readableSample.environment(\.colorScheme, .dark)
                }
            }

            DemoSection(
                "Color for Each Appearance",
                caption: "ColorStyle(light:dark:lightHighContrast:darkHighContrast:) is a ShapeStyle that resolves for the color scheme and contrast, keeping each color in its own model. UIColor and NSColor have the same initializer for dynamic colors. The dark color is derived with adapted(from:to:), and the high contrast colors with contrast(.apca).increased(against:by:)."
            ) {
                ColorField("Light", color: $lightColor)
                let dark = lightColor.adapted(from: HEXColor("#FFFFFF"), to: HEXColor("#1C1C1E"))
                let adaptive = Self.dynamicColor(
                    light: lightColor,
                    dark: dark,
                    lightHighContrast: lightColor.contrast(.apca).increased(against: HEXColor("#FFFFFF")),
                    darkHighContrast: dark.contrast(.apca).increased(against: HEXColor("#1C1C1E"))
                )
                Text("UIColor / NSColor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    appearanceSample(adaptive, "Light").environment(\.colorScheme, .light)
                    appearanceSample(adaptive, "Dark").environment(\.colorScheme, .dark)
                    appearanceSample(adaptive, "Light, Increased").environment(\.colorScheme, .light).environment(\._colorSchemeContrast, .increased)
                    appearanceSample(adaptive, "Dark, Increased").environment(\.colorScheme, .dark).environment(\._colorSchemeContrast, .increased)
                }
                let style = ColorStyle(
                    light: lightColor,
                    dark: dark,
                    lightHighContrast: lightColor.contrast(.apca).increased(against: HEXColor("#FFFFFF")),
                    darkHighContrast: dark.contrast(.apca).increased(against: HEXColor("#1C1C1E"))
                )
                Text("ColorStyle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    appearanceSample(style, "Light").environment(\.colorScheme, .light)
                    appearanceSample(style, "Dark").environment(\.colorScheme, .dark)
                    appearanceSample(style, "Light, Increased").environment(\.colorScheme, .light).environment(\._colorSchemeContrast, .increased)
                    appearanceSample(style, "Dark, Increased").environment(\.colorScheme, .dark).environment(\._colorSchemeContrast, .increased)
                }
            }

            DemoSection(
                "Resolving",
                caption: "toRGBAColor(in:) resolves a SwiftUI color in an environment. toRGBAColor() reads colors backed by a CGColor without resolving, and is nil for system colors."
            ) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    ForEach(systemColors, id: \.0) { name, color in
                        let resolved = color.toRGBAColor(in: environment)
                        GridRow {
                            Circle().fill(color).frame(width: 16, height: 16)
                            Text(".\(name)")
                            Text(resolved.toHEXColor().toString(includePrefix: true)).font(.body.monospaced())
                            Text(color.toRGBAColor() == nil ? "toRGBAColor(): nil" : "toRGBAColor(): ✓")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var transformedColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Original").frame(maxWidth: .infinity)
                Text("darkened").frame(maxWidth: .infinity)
                Text("secondary").frame(maxWidth: .infinity)
            }
            .font(.caption2)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.secondary)
            ForEach(systemColors, id: \.0) { _, color in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 6).fill(color)
                    RoundedRectangle(cornerRadius: 6).fill(color.transformed { $0.darkened(by: 0.1) })
                    RoundedRectangle(cornerRadius: 6).fill(color.transformed { $0.withProminence(.secondary) })
                }
                .frame(height: 28)
            }
        }
        .padding(10)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var readableSample: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Original yellow")
                .foregroundStyle(Color.yellow)
            Text("Adjusted to Lc 60")
                .foregroundStyle(Color.yellow.transformed(with: background) {
                    $0.contrast(.apca).adjusted(toMinimum: 60, against: $1)
                })
        }
        .font(.headline)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func appearanceSample<S: ShapeStyle>(_ style: S, _ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(style)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    NavigationStack { SwiftUIDemo() }
}
