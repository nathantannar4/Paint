//
// Copyright (c) Nathan Tannar
//

import XCTest
@testable import Paint

/// Tests ``ColorContrast``, the contrast of a color measured with ``APCAContrast`` or
/// ``WCAGContrast``.
final class ColorContrastTests: XCTestCase {

    private let white = RGBAColor(red: 1, green: 1, blue: 1)
    private let black = RGBAColor(red: 0, green: 0, blue: 0)
    private let orange: HEXColor = "#FF8000"

    func testLuminance() {
        // Each metric measures luminance its own way
        XCTAssertEqual(orange.contrast(.apca).luminance, APCAContrast.luminance(red: 1, green: 128.0 / 255, blue: 0), accuracy: 1e-12)
        XCTAssertEqual(orange.contrast(.wcag).luminance, WCAGContrast.relativeLuminance(red: 1, green: 128.0 / 255, blue: 0), accuracy: 1e-12)
        XCTAssertNotEqual(orange.contrast(.apca).luminance, orange.contrast(.wcag).luminance)
        XCTAssertEqual(black.contrast(.apca).luminance, 0)
        XCTAssertEqual(white.contrast(.apca).luminance, 1, accuracy: 1e-6)
        XCTAssertEqual(black.contrast(.wcag).luminance, 0)
        XCTAssertEqual(white.contrast(.wcag).luminance, 1, accuracy: 1e-9)
    }

    func testAgainst() {
        // The same as the metric's own initializer, as text on the background
        XCTAssertEqual(orange.contrast(.apca).against(white), APCAContrast(text: orange, background: white))
        XCTAssertEqual(orange.contrast(.wcag).against(white), WCAGContrast(text: orange, background: white))
        // APCA depends on which color is the text, WCAG 2 doesn't
        XCTAssertNotEqual(orange.contrast(.apca).against(white).rawValue, white.contrast(.apca).against(orange).rawValue)
        XCTAssertEqual(orange.contrast(.wcag).against(white), white.contrast(.wcag).against(orange))
        XCTAssertEqual(black.contrast(.wcag).against(white).rawValue, 21, accuracy: 1e-9)
    }

    func testIsDark() {
        XCTAssertTrue(black.contrast(.apca).isDark)
        XCTAssertTrue(white.contrast(.apca).isLight)
        XCTAssertTrue(black.contrast(.wcag).isDark)
        XCTAssertTrue(white.contrast(.wcag).isLight)
        XCTAssertNotEqual(orange.contrast(.wcag).isDark, orange.contrast(.wcag).isLight)

        // The metrics disagree on mid grays: WCAG 2 prefers black text on #808080, APCA
        // prefers white text
        let gray: HEXColor = "#808080"
        XCTAssertTrue(gray.contrast(.apca).isDark)
        XCTAssertFalse(gray.contrast(.wcag).isDark)
    }

    func testAdjusted() {
        // Each metric adjusts to its own minimum
        let apca = orange.contrast(.apca).adjusted(toMinimum: 75, against: white)
        XCTAssertTrue(apca.contrast(.apca).against(white).meets(75))
        let wcag = orange.contrast(.wcag).adjusted(toMinimum: .aa, against: white, in: .sRGB)
        XCTAssertTrue(wcag.contrast(.wcag).against(white).meets(.aa))
        XCTAssertLessThan(wcag.contrast(.wcag).against(white).rawValue, 4.6)
        // The hue is kept
        XCTAssertEqual(apca.toOKLCHColor().hue.degrees, orange.toOKLCHColor().hue.degrees, accuracy: 2)
        // Colors that already meet the minimum are unchanged
        XCTAssertEqual(black.contrast(.wcag).adjusted(toMinimum: .aaa, against: white), black)
    }

    func testIncreased() {
        let background = RGBAColor(red: 0.95, green: 0.95, blue: 0.97)
        let original = orange.contrast(.apca).against(background)
        let increased = orange.contrast(.apca).increased(against: background, by: 15)
        XCTAssertEqual(increased.contrast(.apca).against(background).magnitude, original.magnitude + 15, accuracy: 0.5)
    }

    func testColorIsKept() {
        // Any color model, including ones that aren't `BitwiseCopyable`
        let css = CSSColor(decoding: "rebeccapurple")!
        XCTAssertEqual(css.contrast(.apca).color, css.toRGBAColor())
        XCTAssertEqual(css.contrast(.wcag).against(white), WCAGContrast(text: css, background: white))
    }
}
