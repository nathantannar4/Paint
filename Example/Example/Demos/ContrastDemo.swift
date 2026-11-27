//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint

/// WCAG 2 and APCA contrast, and adjusting colors to meet a minimum.
struct ContrastDemo: View {

    @State private var text = RGBAColor(red: 0.55, green: 0.6, blue: 0.95)
    @State private var background = RGBAColor(red: 1, green: 1, blue: 1)
    @State private var darkBackground = RGBAColor(red: 0.11, green: 0.11, blue: 0.12)
    @State private var apcaTarget = 60.0
    @State private var wcagTarget = 4.5
    @State private var increase = 15.0

    private static let wcagLevels: [(String, WCAGContrast)] = [
        ("AA", .aa), ("AA Large", .aaLarge), ("AAA", .aaa), ("AAA Large", .aaaLarge), ("Non-text", .nonText),
    ]

    private static let apcaLevels: [APCAContrast] = [90, 75, 60, 45, 30, 15]

    var body: some View {
        DemoPage("Contrast") {
            DemoSection("Colors") {
                ColorField("Text", color: $text)
                ColorField("Background", color: $background)
                sample(text: text, background: background, title: "The quick brown fox")
            }

            DemoSection(
                "WCAG 2",
                caption: "contrast(.wcag).against(_:) returns a WCAGContrast, from 1 to 21, with levels such as .aa and .aaa."
            ) {
                let ratio = text.contrast(.wcag).against(background)
                Text(ratio.description)
                    .font(.title2.monospacedDigit().weight(.semibold))
                FlowBadges(items: Self.wcagLevels.map { ($0.0, ratio.meets($0.1)) })
            }

            DemoSection(
                "APCA",
                caption: "contrast(.apca).against(_:) returns an APCAContrast in Lc, which depends on which color is the text, and on polarity."
            ) {
                let contrast = text.contrast(.apca).against(background)
                HStack(alignment: .firstTextBaseline) {
                    Text(contrast.description)
                        .font(.title2.monospacedDigit().weight(.semibold))
                    Text(contrast.isLightOnDark ? "light on dark" : "dark on light")
                        .foregroundStyle(.secondary)
                }
                FlowBadges(items: Self.apcaLevels.map { ("Lc \(Int($0.rawValue))", contrast.meets($0)) })
            }

            DemoSection(
                "Adjusting to a Minimum",
                caption: "contrast(.apca).adjusted(toMinimum:against:) and contrast(.wcag).adjusted(toMinimum:against:) change only OKLCH lightness, as little as needed, keeping the hue."
            ) {
                LabeledSlider("APCA Lc", value: $apcaTarget, in: 15...100, digits: 0)
                let apca = text.contrast(.apca).adjusted(toMinimum: APCAContrast(rawValue: apcaTarget), against: background)
                sample(
                    text: apca,
                    background: background,
                    title: "contrast(.apca).adjusted",
                    detail: apca.contrast(.apca).against(background).description
                )
                LabeledSlider("WCAG ratio", value: $wcagTarget, in: 1...21, digits: 1)
                let wcag = text.contrast(.wcag).adjusted(toMinimum: WCAGContrast(rawValue: wcagTarget), against: background)
                sample(
                    text: wcag,
                    background: background,
                    title: "contrast(.wcag).adjusted",
                    detail: wcag.contrast(.wcag).against(background).description
                )
            }

            DemoSection(
                "Increased Contrast and Dark Mode",
                caption: "contrast(.apca).increased(against:by:) adds APCA contrast, for accessibility variants. adapted(from:to:) keeps the contrast a color has on one background on another."
            ) {
                LabeledSlider("Increase (Lc)", value: $increase, in: 0...40, digits: 0)
                let increased = text.contrast(.apca).increased(against: background, by: increase)
                sample(
                    text: increased,
                    background: background,
                    title: "contrast(.apca).increased",
                    detail: increased.contrast(.apca).against(background).description
                )
                ColorField("New background", color: $darkBackground)
                let adapted = text.adapted(from: background, to: darkBackground)
                sample(
                    text: adapted,
                    background: darkBackground,
                    title: "adapted(from:to:)",
                    detail: adapted.contrast(.apca).against(darkBackground).description
                )
            }

            DemoSection(
                "Best Text Color",
                caption: "contrast(.apca).isDark picks white or black text, whichever has more APCA contrast. WCAG 2 disagrees near the middle: contrast(.wcag).isDark calls more mid tones dark."
            ) {
                HStack(spacing: 4) {
                    ForEach(OKLCHColor.categorical(count: 8, lightness: 0.65), id: \.self) { color in
                        Text("Aa")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color(color), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .foregroundStyle(color.contrast(.apca).isDark ? .white : .black)
                    }
                }
            }

            DemoSection(
                "Preferred Text Color",
                caption: "contrast(.apca).preferredForeground(among:minimum:) picks the first candidate, in order of preference, that meets the minimum: here the text color, then white, then black. If none does, it picks the one with the most contrast."
            ) {
                LabeledSlider("Minimum (Lc)", value: $preferredMinimum, in: 15...90, digits: 0)
                let white = RGBAColor(red: 1, green: 1, blue: 1)
                let black = RGBAColor(red: 0, green: 0, blue: 0)
                HStack(spacing: 4) {
                    ForEach(OKLCHColor.categorical(count: 6, lightness: 0.55, chroma: 0.12), id: \.self) { color in
                        let foreground = color.contrast(.apca).preferredForeground(
                            among: [text, white, black],
                            minimum: APCAContrast(rawValue: preferredMinimum)
                        ) ?? black
                        Text("Aa")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color(color), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .foregroundStyle(Color(foreground))
                    }
                }
            }

            DemoSection(
                "Tinted Text",
                caption: "contrast(.wcag).tintedForeground(minimum:) gives text in the background's hue, which looks like it belongs on the background, rather than harsh black or white."
            ) {
                LabeledSlider("WCAG ratio", value: $tintedMinimum, in: 3...12, digits: 1)
                HStack(spacing: 4) {
                    ForEach(Self.badgeColors, id: \.self) { badge in
                        let tinted = badge.contrast(.wcag).tintedForeground(minimum: WCAGContrast(rawValue: tintedMinimum))
                        VStack(spacing: 2) {
                            Text("Badge")
                                .font(.headline)
                            Text(tinted.contrast(.wcag).against(badge).description)
                                .font(.caption2.monospacedDigit())
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(Color(tinted))
                        .background(Color(badge), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    @State private var preferredMinimum = 60.0
    @State private var tintedMinimum = 4.5

    private static let badgeColors: [HEXColor] = ["#DBEAFE", "#DCFCE7", "#FEF3C7", "#FCE7F3", "#1E3A8A", "#14532D"]

    private func sample(text: RGBAColor, background: RGBAColor, title: String, detail: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.callout.monospacedDigit())
            }
        }
        .foregroundStyle(Color(text))
        .padding()
        .background(Color(background), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quaternary)
        }
    }
}

/// Badges that wrap onto multiple lines.
struct FlowBadges: View {
    var items: [(String, Bool)]

    var body: some View {
        FlowLayout {
            ForEach(items.indices, id: \.self) { index in
                Badge(title: items[index].0, passes: items[index].1)
            }
        }
    }
}

#Preview {
    NavigationStack { ContrastDemo() }
}
