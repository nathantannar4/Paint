//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// Wide gamut colors, and HDR colors brighter than SDR white.
struct HDRDemo: View {

    @Environment(\.self) private var environment
    @State private var base = RGBAColor(red: 1, green: 0.5, blue: 0.1)
    @State private var exposure = 2.0
    @State private var stops = 1.0

    /// The base color brightened in linear light.
    private var hdr: RGBAColor {
        RGBAColor(linear: base.toLinearComponents() * exposure, alpha: base.alpha)
    }

    var body: some View {
        DemoPage("HDR & Wide Gamut") {
            DemoSection(
                "Wide Gamut",
                caption: "RGBAColor stores extended sRGB, so colors outside sRGB have components outside 0...1. These are Display P3 primaries, fitted to sRGB with toColorGamut(_:) on the right. Compare them on a P3 display."
            ) {
                VStack(spacing: 6) {
                    ForEach(["color(display-p3 1 0 0)", "color(display-p3 0 1 0)", "color(display-p3 0 0 1)"], id: \.self) { css in
                        let p3 = CSSColor(decoding: css)!.toRGBAColor()
                        HStack(spacing: 4) {
                            Swatch(p3, label: css)
                            Swatch(p3.toColorGamut(.sRGB), label: "sRGB", detail: p3.toColorGamut(.sRGB).toHEXColor().toString(includePrefix: true))
                        }
                    }
                }
                Text("Wide gamut colors aren't HDR: isHDR is false for all of these, since contentHeadroom is measured in Rec. 2020.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DemoSection(
                "HDR",
                caption: "contentHeadroom is how much brighter than SDR white a color is. On iOS 26 and macOS 26, Color, UIColor, NSColor and CGColor are tagged with it, so the system tone maps them for the display. toStandardDynamicRange() is the SDR fallback."
            ) {
                ColorField("Base", color: $base)
                LabeledSlider("Linear exposure", value: $exposure, in: 1...8, digits: 1)
                HStack(spacing: 4) {
                    Swatch(hdr, label: "HDR", height: 96)
                    Swatch(hdr.toStandardDynamicRange(), label: "toStandardDynamicRange()", height: 96)
                }
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    ValueRow("contentHeadroom", format(hdr.contentHeadroom, 2))
                    ValueRow("isHDR", "\(hdr.isHDR)")
                    ValueRow("toLinearComponents()", format(hdr.toLinearComponents().x, hdr.toLinearComponents().y, hdr.toLinearComponents().z, digits: 2))
                }
                Text(hdrNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DemoSection(
                "Reading HDR Colors",
                caption: "On iOS 26 and macOS 26, toRGBAColor(in:) resolves SwiftUI colors with resolveHDR(in:), so colors brightened with exposureAdjust(_:) keep their brightness, which resolve(in:) clips to SDR. UIColor and NSColor keep it too."
            ) {
                if #available(iOS 26.0, macOS 26.0, *) {
                    LabeledSlider("exposureAdjust", value: $stops, in: 0...3, digits: 1)
                    let color = base.toColor().exposureAdjust(stops)
                    let resolved = color.resolve(in: environment)
                    let rgba = color.toRGBAColor(in: environment)
                    HStack(spacing: 4) {
                        Swatch(rgba, label: "toRGBAColor(in:)", height: 72)
                        Swatch(
                            RGBAColor(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue)),
                            label: "resolve(in:)",
                            height: 72
                        )
                    }
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        ValueRow("contentHeadroom", format(rgba.contentHeadroom, 2))
                        ValueRow("isHDR", "\(rgba.isHDR)")
                    }
                } else {
                    Text("exposureAdjust(_:) requires iOS 26 or macOS 26.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var hdrNote: String {
        if #available(iOS 26.0, macOS 26.0, *) {
            "HDR colors are tagged with their headroom on this OS. On an HDR display, the left swatch is brighter than white."
        } else {
            "This OS predates content headroom, so HDR colors are untagged extended sRGB."
        }
    }
}

#Preview {
    NavigationStack { HDRDemo() }
}
