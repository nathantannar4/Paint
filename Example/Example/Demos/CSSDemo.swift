//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Decoding and writing CSS Color 4 strings with `CSSColor`, parsing any color string
/// with `ColorParseStrategy`, and formatting with `ColorFormatStyle`.
struct CSSDemo: View {

    @State private var input = "oklch(0.7 0.15 250)"
    @State private var edited = RGBAColor(red: 1, green: 0.5, blue: 0)
    @State private var editedFormat = CSSColorFormat.hex

    private let examples = [
        "rebeccapurple",
        "#FF800080",
        "FF8000",
        "rgb(255 128 0 / 50%)",
        "hsl(120deg 60% 45%)",
        "hwb(200 10% 20%)",
        "lab(50 40 -20)",
        "oklch(0.7 0.15 250)",
        "color(display-p3 1 0 0)",
        "color(rec2020 0 1 0)",
        "transparent",
    ]

    var body: some View {
        DemoPage("CSS & Strings") {
            DemoSection(
                "Decode",
                caption: "CSSColor(decoding:) decodes CSS Color 4: HEX, the 148 named colors, rgb(), hsl(), hwb(), lab(), lch(), oklab(), oklch() and color(). It keeps the string exactly as written, as rawValue."
            ) {
                TextField("CSS color", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                FlowLayout {
                    ForEach(examples, id: \.self) { example in
                        Button(example) { input = example }
                            .buttonStyle(.bordered)
                            .font(.caption.monospaced())
                    }
                }
                if let color = CSSColor(decoding: input) {
                    Swatch(color, label: color.rawValue, height: 72)
                } else {
                    Label("Not a supported CSS color", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            DemoSection(
                "Any Color String",
                caption: "ColorParseStrategy parses any HEX or CSS color string, including HEX without a leading #, like FF8000, which isn't valid CSS. CSSColor(decoding:) and HEXColor(decoding:) each accept only their own strings."
            ) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    ValueRow("ColorParseStrategy", (try? ColorParseStrategy().parse(input)).map { $0.toHEXColor().toString(includePrefix: true) } ?? "throws")
                    ValueRow("CSSColor(decoding:)", CSSColor(decoding: input).map { $0.toHEXColor().toString(includePrefix: true) } ?? "nil")
                    ValueRow("HEXColor(decoding:)", HEXColor(decoding: input).map { $0.toString(includePrefix: true) } ?? "nil")
                }
            }

            DemoSection(
                "Format Styles",
                caption: "ColorFormatStyle is a Foundation ParseableFormatStyle. color.formatted(.hex), color.formatted(.css(_:)) and color.formatted(.name) write a color, and TextField(value:format:) edits one, parsing any HEX or CSS string with ColorParseStrategy. Press return to commit."
            ) {
                Picker("Format", selection: $editedFormat) {
                    ForEach(CSSColorFormat.allCases, id: \.self) { Text(".\($0.rawValue)").tag($0) }
                }
                TextField("Color", value: $edited, format: .css(editedFormat))
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                Swatch(edited, height: 56)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    ValueRow(".formatted(.hex)", edited.formatted(.hex))
                    ValueRow(".formatted(.css())", edited.formatted(.css()))
                    ValueRow(".formatted(.css(.\(editedFormat.rawValue)))", edited.formatted(.css(editedFormat)))
                    ValueRow(".formatted(.name)", edited.formatted(.name))
                    let hex = edited.toHEXColor()
                    ValueRow("HEXColor.toString()", hex.toString())
                    ValueRow("toString(includePrefix: true)", hex.toString(includePrefix: true))
                    ValueRow("toString(prefersOpaqueAlpha: true)", hex.toString(prefersOpaqueAlpha: true))
                    ValueRow("HEXColor.description", hex.description)
                }
            }

            if let color = CSSColor(decoding: input) {
                DemoSection(
                    "Write",
                    caption: "toCSSColor() writes any color as a CSSColor: rgb() in sRGB, and oklch() otherwise, so wide gamut colors aren't clipped. toCSSColor(_:) writes any CSSColorFormat; formats limited to sRGB gamut map first."
                ) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        // Converted through `RGBAColor`, since a `CSSColor` converts to itself
                        ValueRow("toCSSColor()", color.toRGBAColor().toCSSColor().rawValue)
                        ForEach(CSSColorFormat.allCases, id: \.self) { format in
                            ValueRow(".\(format.rawValue)", color.toCSSColor(format).rawValue)
                        }
                    }
                }

                DemoSection(
                    "Gamut",
                    caption: "toColorGamut(_:) keeps the string of colors already in the gamut, and rewrites fitted colors in a format that holds the gamut."
                ) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        ForEach(ColorGamut.all, id: \.self) { gamut in
                            ValueRow(gamut.title, color.toColorGamut(gamut).rawValue)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { CSSDemo() }
}
