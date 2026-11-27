//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
@testable import Paint

/// Tests readable foregrounds, shadows and elevation.
final class ColorForegroundTests: XCTestCase {

    // MARK: - Foreground

    func testPreferredForeground() {
        let white = HEXColor("#FFFFFF")
        let black = HEXColor("#000000")
        let accent = HEXColor("#3B82F6")

        // Without a minimum, the most contrast wins
        XCTAssertEqual(HEXColor("#111111").contrast(.wcag).preferredForeground(among: [black, white]), white)
        XCTAssertEqual(HEXColor("#EEEEEE").contrast(.apca).preferredForeground(among: [white, black]), black)

        // With a minimum, the first candidate that meets it wins
        let dark = HEXColor("#0B1020")
        XCTAssertEqual(dark.contrast(.wcag).preferredForeground(among: [accent, white], minimum: 4.5), accent)
        XCTAssertEqual(dark.contrast(.wcag).preferredForeground(among: [accent, white], minimum: 7), white)

        // When none meets it, the most contrast wins
        let gray = HEXColor("#777777")
        XCTAssertEqual(gray.contrast(.wcag).preferredForeground(among: [HEXColor("#888888"), white], minimum: 21), white)

        XCTAssertNil(gray.contrast(.wcag).preferredForeground(among: [HEXColor](), minimum: 3))

        // Ties keep the first
        XCTAssertEqual(gray.contrast(.wcag).preferredForeground(among: [white, white.opacity(0.5)]), white)
    }

    func testTintedForeground() {
        let backgrounds: [HEXColor] = ["#DBEAFE", "#1E3A8A", "#FEF3C7", "#14532D", "#FFFFFF", "#000000", "#808080", "#FF0000"]
        for background in backgrounds {
            for minimum in [WCAGContrast.aa, .aaa] {
                let text = background.contrast(.wcag).tintedForeground(minimum: minimum)
                let best = max(HEXColor("#FFFFFF").contrast(.wcag).against(background), HEXColor("#000000").contrast(.wcag).against(background))
                if best.meets(minimum) {
                    XCTAssertTrue(text.contrast(.wcag).against(background).meets(minimum), "\(background) \(minimum) \(text)")
                } else {
                    // Where the minimum can't be met, the text has as much contrast as it can
                    XCTAssertEqual(text.contrast(.wcag).against(background).rawValue, best.rawValue, accuracy: 0.05, "\(background) \(minimum) \(text)")
                }
                XCTAssertEqual(text.alpha, 1)
                XCTAssertTrue(ColorGamut.displayP3.contains(text))
            }
            let apca = background.contrast(.apca).tintedForeground(minimum: 60)
            XCTAssertTrue(apca.contrast(.apca).against(background).meets(60) || background == "#808080" || background == "#FF0000", "\(background) \(apca)")
        }
        // The text takes the background's hue
        let blue = HEXColor("#DBEAFE")
        let text = blue.contrast(.wcag).tintedForeground(minimum: .aa).toOKLCHColor()
        XCTAssertGreaterThan(text.chroma, 0.01)
        XCTAssertEqual(text.hue.degrees, blue.toOKLCHColor().hue.degrees, accuracy: 5)
        // Grays give gray text
        XCTAssertLessThan(HEXColor("#EEEEEE").contrast(.wcag).tintedForeground(minimum: .aa).toOKLCHColor().chroma, 1e-3)
        // Light backgrounds get dark text, and dark backgrounds light text
        XCTAssertLessThan(text.lightness, 0.5)
        XCTAssertGreaterThan(HEXColor("#1E3A8A").contrast(.wcag).tintedForeground(minimum: .aa).toOKLCHColor().lightness, 0.5)
    }

    // MARK: - Shadows and Elevation

    func testShadowColor() {
        let background = HEXColor("#DBEAFE")
        let shadow = background.shadow()
        XCTAssertEqual(shadow.alpha, 0.25, accuracy: 1e-9)
        XCTAssertLessThan(shadow.lightness, 0.3)
        XCTAssertEqual(shadow.hue.degrees, background.toOKLCHColor().hue.degrees, accuracy: 5)
        XCTAssertGreaterThan(shadow.chroma, 0.01)
        XCTAssertTrue(ColorGamut.displayP3.contains(shadow))
        // Gray backgrounds give gray shadows
        XCTAssertLessThan(HEXColor("#F2F2F2").shadow().chroma, 1e-3)
        // Opacity is clamped
        XCTAssertEqual(background.shadow(opacity: 2).alpha, 1)
        XCTAssertEqual(background.shadow(opacity: -1).alpha, 0)
    }

    func testElevation() {
        let dark = HEXColor("#121212")
        let levels = (0...5).map { dark.elevated(level: $0).lightness }
        XCTAssertEqual(levels, levels.sorted())
        XCTAssertEqual(levels[0], dark.toOKLCHColor().lightness, accuracy: 1e-9)
        XCTAssertGreaterThan(levels[5] - levels[0], 0.05)
        // Levels are clamped
        XCTAssertEqual(dark.elevated(level: 9).lightness, levels[5], accuracy: 1e-9)
        XCTAssertEqual(dark.elevated(level: -1).lightness, levels[0], accuracy: 1e-9)

        // Light surfaces are unchanged
        let light = HEXColor("#FFFFFF")
        XCTAssertTrue(light.elevated(level: 3).isApproximatelyEqual(to: light, tolerance: 1e-9))

        // Tinted elevation works in both appearances
        let tint = HEXColor("#3B82F6")
        let tinted = light.elevated(level: 3, tint: tint)
        XCTAssertFalse(tinted.isApproximatelyEqual(to: light, tolerance: 0.01))
        XCTAssertEqual(tinted.hue.degrees, tint.toOKLCHColor().hue.degrees, accuracy: 10)
        XCTAssertGreaterThan(dark.elevated(level: 5, tint: tint).chroma, dark.elevated(level: 1, tint: tint).chroma)
        XCTAssertEqual(light.elevated(level: 3, tint: tint.opacity(0.5)).alpha, 1, accuracy: 1e-9)
    }
}
