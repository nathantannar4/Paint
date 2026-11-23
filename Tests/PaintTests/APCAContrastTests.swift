//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif
@testable import Paint

/// Tests ``APCAContrast``, and adjusting colors to meet a contrast.
final class APCAContrastTests: XCTestCase {

    func testAPCAReferenceValues() {
        // From the apca-w3 README, for APCA-W3 0.0.98G-4g
        let white: HEXColor = "#FFFFFF"
        let black: HEXColor = "#000000"
        let gray: HEXColor = "#888888"
        XCTAssertEqual(gray.contrast(.apca).against(white).rawValue, 63.056469930209424, accuracy: 1e-9)
        XCTAssertEqual(white.contrast(.apca).against(gray).rawValue, -68.54146436644962, accuracy: 1e-9)
        XCTAssertEqual(black.contrast(.apca).against(white).rawValue, 106.04067321268862, accuracy: 1e-9)
        XCTAssertEqual(white.contrast(.apca).against(black).rawValue, -107.88473318309848, accuracy: 1e-9)
    }

    func testAPCALowContrastIsZero() {
        let white: HEXColor = "#FFFFFF"
        XCTAssertEqual(white.contrast(.apca).against(white).rawValue, 0)
        XCTAssertEqual(HEXColor("#FEFEFE").contrast(.apca).against(white).rawValue, 0)
        XCTAssertEqual(HEXColor("#010101").contrast(.apca).against(HEXColor("#000000")).rawValue, 0)
    }

    func testAPCAPolarity() {
        let white: HEXColor = "#FFFFFF"
        let black: HEXColor = "#000000"
        XCTAssertFalse(black.contrast(.apca).against(white).isLightOnDark)
        XCTAssertTrue(white.contrast(.apca).against(black).isLightOnDark)
        XCTAssertEqual(white.contrast(.apca).against(black).magnitude, 107.88473318309848, accuracy: 1e-9)
    }

    func testAPCATranslucentTextBlendsOverBackground() {
        let background: HEXColor = "#FFFFFF"
        let translucent = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        let blended = RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertEqual(
            translucent.contrast(.apca).against(background).rawValue,
            blended.contrast(.apca).against(background).rawValue,
            accuracy: 1e-12
        )
        // A transparent background is treated as opaque
        let transparentBackground = RGBAColor(red: 1, green: 1, blue: 1, alpha: 0)
        XCTAssertEqual(HEXColor("#888888").contrast(.apca).against(transparentBackground).rawValue, 63.056469930209424, accuracy: 1e-9)
    }

    func testAPCAComparesByMagnitude() {
        XCTAssertGreaterThan(APCAContrast(rawValue: -60), APCAContrast(rawValue: 50))
        XCTAssertLessThan(APCAContrast(rawValue: -60), APCAContrast(rawValue: 75))
        // Equal magnitudes are ordered by value, consistent with equality
        XCTAssertLessThan(APCAContrast(rawValue: -60), APCAContrast(rawValue: 60))
        XCTAssertNotEqual(APCAContrast(rawValue: -60), APCAContrast(rawValue: 60))
        XCTAssertEqual(
            [APCAContrast(rawValue: 75), APCAContrast(rawValue: -30), APCAContrast(rawValue: -90), APCAContrast(rawValue: 0)].sorted().map(\.rawValue),
            [0, -30, 75, -90]
        )

        // Choosing the more readable text color
        let background: HEXColor = "#3366CC"
        let onWhite = HEXColor("#FFFFFF").contrast(.apca).against(background)
        let onBlack = HEXColor("#000000").contrast(.apca).against(background)
        XCTAssertGreaterThan(onWhite, onBlack)
        XCTAssertEqual(max(onWhite, onBlack), onWhite)
    }

    func testAPCADescription() {
        XCTAssertEqual(HEXColor("#888888").contrast(.apca).against(HEXColor("#FFFFFF")).description, "Lc 63.1")
        XCTAssertEqual(APCAContrast(rawValue: -68.54).description, "Lc -68.5")
    }

    func testAPCALiterals() {
        let integer: APCAContrast = 75
        XCTAssertEqual(integer, APCAContrast(rawValue: 75))
        let float: APCAContrast = 62.5
        XCTAssertEqual(float.rawValue, 62.5)
        let negative: APCAContrast = -60
        XCTAssertTrue(negative.isLightOnDark)
        XCTAssertEqual(APCAContrast(rawValue: 42), APCAContrast(rawValue: APCAContrast(rawValue: 42).rawValue))
    }

    func testAPCAMeets() {
        // Either polarity meets a minimum
        XCTAssertTrue(APCAContrast(rawValue: 80).meets(75))
        XCTAssertTrue(APCAContrast(rawValue: -80).meets(75))
        XCTAssertTrue(APCAContrast(rawValue: 75).meets(75))
        XCTAssertFalse(APCAContrast(rawValue: -74.9).meets(75))
        XCTAssertTrue(APCAContrast(rawValue: 80).meets(-75))

        // Gray on white is Lc 63
        let contrast = HEXColor("#888888").contrast(.apca).against(HEXColor("#FFFFFF"))
        XCTAssertTrue(contrast.meets(60))
        XCTAssertFalse(contrast.meets(75))
        XCTAssertGreaterThanOrEqual(contrast, 60)
    }

    func testAdjustedToContrast() {
        let white = RGBAColor(red: 1, green: 1, blue: 1)
        let black = RGBAColor(red: 0, green: 0, blue: 0)
        let orange: HEXColor = "#FF8000"
        XCTAssertFalse(orange.contrast(.apca).against(white).meets(75))

        // Darkens on a light background, keeping the hue
        let onWhite = orange.contrast(.apca).adjusted(toMinimum: 75, against: white)
        XCTAssertTrue(onWhite.contrast(.apca).against(white).meets(75))
        XCTAssertFalse(onWhite.contrast(.apca).against(white).isLightOnDark)
        XCTAssertLessThan(onWhite.toOKLCHColor().lightness, orange.toOKLCHColor().lightness)
        XCTAssertEqual(onWhite.toOKLCHColor().hue.degrees, orange.toOKLCHColor().hue.degrees, accuracy: 5)
        // It is the smallest change, so the contrast lands just above the minimum
        XCTAssertLessThan(onWhite.contrast(.apca).against(white).magnitude, 75.1)

        // Lightens on a dark background
        let navy: HEXColor = "#000040"
        let onBlack = navy.contrast(.apca).adjusted(toMinimum: 60, against: black)
        XCTAssertTrue(onBlack.contrast(.apca).against(black).meets(60))
        XCTAssertTrue(onBlack.contrast(.apca).against(black).isLightOnDark)

        // Colors that already meet the minimum are unchanged
        XCTAssertEqual(black.contrast(.apca).adjusted(toMinimum: 75, against: white), black)
        XCTAssertEqual(orange.contrast(.apca).adjusted(toMinimum: 15, against: white), orange.toRGBAColor())

        // On a mid gray, neither direction reaches Lc 90, so the best is returned
        let gray: HEXColor = "#777777"
        let best = HEXColor("#606060").contrast(.apca).adjusted(toMinimum: 90, against: gray)
        XCTAssertFalse(best.contrast(.apca).against(gray).meets(90))
        assertEqual(best, white, accuracy: 1e-6)

        // Alpha is kept
        XCTAssertEqual(RGBAColor(red: 1, green: 0.5, blue: 0, alpha: 0.9).contrast(.apca).adjusted(toMinimum: 60, against: white).alpha, 0.9)
    }

    func testAdjustedToContrastGamut() {
        // Display P3 keeps more chroma than sRGB where the adjusted lightness can't fit it
        let white = RGBAColor(red: 1, green: 1, blue: 1)
        let vivid = OKLCHColor(lightness: 0.85, chroma: 0.3, hue: .degrees(145))
        let p3 = vivid.contrast(.apca).adjusted(toMinimum: 75, against: white)
        let srgb = vivid.contrast(.apca).adjusted(toMinimum: 75, against: white, in: .sRGB)
        XCTAssertTrue(p3.contrast(.apca).against(white).meets(75))
        XCTAssertTrue(srgb.contrast(.apca).against(white).meets(75))
        XCTAssertTrue(ColorGamut.displayP3.contains(p3))
        XCTAssertTrue(ColorGamut.sRGB.contains(srgb))
        XCTAssertGreaterThan(p3.toOKLCHColor().chroma, srgb.toOKLCHColor().chroma)
        XCTAssertEqual(p3.toOKLCHColor().hue.degrees, 145, accuracy: 1)
        XCTAssertEqual(srgb.toOKLCHColor().hue.degrees, 145, accuracy: 1)
    }

    func testLuminance() {
        XCTAssertEqual(HEXColor("#000000").contrast(.apca).luminance, 0)
        XCTAssertEqual(HEXColor("#FFFFFF").contrast(.apca).luminance, 1, accuracy: 1e-6)
        // A simple 2.4 exponent, weighted by the sRGB coefficients
        let value = 136.0 / 255
        XCTAssertEqual(HEXColor("#888888").contrast(.apca).luminance, pow(value, 2.4), accuracy: 1e-6)
        XCTAssertEqual(RGBAColor(red: 1, green: 0, blue: 0).contrast(.apca).luminance, 0.2126729, accuracy: 1e-12)
        XCTAssertEqual(RGBAColor(red: 0, green: 1, blue: 0).contrast(.apca).luminance, 0.7151522, accuracy: 1e-12)
        XCTAssertEqual(RGBAColor(red: 0, green: 0, blue: 1).contrast(.apca).luminance, 0.0721750, accuracy: 1e-12)
        // Alpha is ignored
        XCTAssertEqual(RGBAColor(red: 1, green: 1, blue: 1, alpha: 0).contrast(.apca).luminance, HEXColor("#FFFFFF").contrast(.apca).luminance)
        // Display P3 green is measured as it is, close to APCA's Display P3 luminance of 0.69175
        let p3Green = RGBAColor(red: -0.5116, green: 1.0183, blue: -0.3107)
        XCTAssertEqual(p3Green.contrast(.apca).luminance, 0.69175, accuracy: 0.01)
        XCTAssertGreaterThan(p3Green.contrast(.apca).luminance, RGBAColor(red: 0, green: 0, blue: 0).contrast(.apca).luminance)
        // Colors outside Display P3 are gamut mapped, so they stay in range
        let beyond = RGBAColor(red: 1.5, green: -0.5, blue: 0)
        XCTAssertGreaterThanOrEqual(beyond.contrast(.apca).luminance, 0)
        XCTAssertLessThanOrEqual(beyond.contrast(.apca).luminance, 1)
        // Floating point error near black never makes luminance negative
        XCTAssertEqual(APCAContrast.luminance(red: -1e-8, green: 1e-9, blue: -1e-8), 0)
        XCTAssertTrue(RGBAColor(red: -1e-8, green: 0, blue: -1e-8).contrast(.apca).against(RGBAColor(red: 1, green: 1, blue: 1)).meets(100))
        // Every model agrees
        let rgba = RGBAColor(red: 0.2, green: 0.6, blue: 0.4)
        XCTAssertEqual(rgba.toHSBAColor().contrast(.apca).luminance, rgba.contrast(.apca).luminance, accuracy: 1e-12)
        XCTAssertEqual(rgba.toOKLCHColor().contrast(.apca).luminance, rgba.contrast(.apca).luminance, accuracy: 1e-7)
    }

    func testIsDark() {
        let dark: [HEXColor] = ["#000000", "#333333", "#0000FF", "#3366CC", "#800000", "#1C1C1E"]
        let light: [HEXColor] = ["#FFFFFF", "#DDDDDD", "#FFFF00", "#00FF00", "#F2F2F7", "#FFCC00"]
        for color in dark {
            XCTAssertTrue(color.contrast(.apca).isDark, "\(color)")
        }
        for color in light {
            XCTAssertFalse(color.contrast(.apca).isDark, "\(color)")
        }
        // Grays switch from dark to light exactly once
        let grays = (0...255).map { HEXColor(red: Double($0) / 255, green: Double($0) / 255, blue: Double($0) / 255) }
        let firstLight = try? XCTUnwrap(grays.firstIndex { !$0.contrast(.apca).isDark })
        XCTAssertNotNil(firstLight)
        if let firstLight {
            XCTAssertTrue(grays[..<firstLight].allSatisfy { $0.contrast(.apca).isDark })
            XCTAssertTrue(grays[firstLight...].allSatisfy { !$0.contrast(.apca).isDark })
        }
    }
}
