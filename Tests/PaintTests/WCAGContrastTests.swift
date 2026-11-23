//
// Copyright (c) Nathan Tannar
//

import XCTest
@testable import Paint

/// Tests WCAG 2 contrast ratios and color difference.
final class WCAGContrastTests: XCTestCase {

    private let white = HEXColor("#FFFFFF")
    private let black = HEXColor("#000000")

    func testContrastRatio() {
        XCTAssertEqual(black.contrast(.wcag).against(white).rawValue, 21, accuracy: 1e-9)
        XCTAssertEqual(white.contrast(.wcag).against(black).rawValue, 21, accuracy: 1e-9)
        XCTAssertEqual(white.contrast(.wcag).against(white).rawValue, 1, accuracy: 1e-9)
        // The classic AA boundary grays
        XCTAssertEqual(HEXColor("#777777").contrast(.wcag).against(white).rawValue, 4.48, accuracy: 0.01)
        XCTAssertFalse(HEXColor("#777777").contrast(.wcag).against(white).meets(.aa))
        XCTAssertTrue(HEXColor("#767676").contrast(.wcag).against(white).meets(.aa))
        XCTAssertTrue(HEXColor("#777777").contrast(.wcag).against(white).meets(.aaLarge))
        XCTAssertEqual(HEXColor("#767676").contrast(.wcag).against(white).description, "4.54:1")

        XCTAssertEqual(white.contrast(.wcag).luminance, 1, accuracy: 1e-9)
        XCTAssertEqual(black.contrast(.wcag).luminance, 0)

        // Translucent text is blended over the background
        let halfBlack = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        let blended = RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertEqual(halfBlack.contrast(.wcag).against(white).rawValue, blended.contrast(.wcag).against(white).rawValue, accuracy: 1e-9)

        XCTAssertLessThan(WCAGContrast.aa, WCAGContrast.aaa)
    }

    func testAdjustedToContrastRatio() {
        let orange = HEXColor("#FF9500")
        XCTAssertFalse(orange.contrast(.wcag).against(white).meets(.aa))
        let adjusted = orange.contrast(.wcag).adjusted(toMinimum: .aa, against: white, in: .sRGB)
        XCTAssertTrue(adjusted.contrast(.wcag).against(white).meets(.aa))
        XCTAssertEqual(adjusted.toOKLCHColor().hue.degrees, orange.toOKLCHColor().hue.degrees, accuracy: 1)
        // Only just meets it, since the adjustment is as small as possible
        XCTAssertLessThan(adjusted.contrast(.wcag).against(white).rawValue, 4.6)
        // Already passing colors are unchanged
        XCTAssertEqual(black.contrast(.wcag).adjusted(toMinimum: .aaa, against: white), black.toRGBAColor())
        // Unreachable ratios give the best possible
        let gray = HEXColor("#808080")
        XCTAssertEqual(white.contrast(.wcag).adjusted(toMinimum: 21, against: gray, in: .sRGB).toHEXColor(), black)
    }

    func testDistance() {
        XCTAssertEqual(white.distance(to: white), 0)
        XCTAssertEqual(black.distance(to: white), 1, accuracy: 1e-4)
        XCTAssertTrue(HEXColor("#808080").isApproximatelyEqual(to: HEXColor("#818181")))
        XCTAssertFalse(HEXColor("#808080").isApproximatelyEqual(to: HEXColor("#909090")))
        XCTAssertFalse(HEXColor("#80808080").isApproximatelyEqual(to: HEXColor("#808080")))
    }

    func testDeltaE2000() {
        // Test data from Sharma, Wu and Dalal (2005)
        let pairs: [(CIELabColor, CIELabColor, Double)] = [
            (CIELabColor(lightness: 50, a: 2.6772, b: -79.7751), CIELabColor(lightness: 50, a: 0, b: -82.7485), 2.0425),
            (CIELabColor(lightness: 50, a: 0, b: 0), CIELabColor(lightness: 50, a: -1, b: 2), 2.3669),
            (CIELabColor(lightness: 50, a: 2.49, b: -0.001), CIELabColor(lightness: 50, a: -2.49, b: 0.0011), 7.2195),
            (CIELabColor(lightness: 50, a: 2.5, b: 0), CIELabColor(lightness: 73, a: 25, b: -18), 27.1492),
            (CIELabColor(lightness: 60.2574, a: -34.0099, b: 36.2677), CIELabColor(lightness: 60.4626, a: -34.1751, b: 39.4387), 1.2644),
            (CIELabColor(lightness: 2.0776, a: 0.0795, b: -1.135), CIELabColor(lightness: 0.9033, a: -0.0636, b: -0.5514), 0.9082),
        ]
        for (lhs, rhs, expected) in pairs {
            XCTAssertEqual(CIELabColor.deltaE2000(lhs, rhs), expected, accuracy: 1e-4, "\(lhs) vs \(rhs)")
            XCTAssertEqual(CIELabColor.deltaE2000(rhs, lhs), expected, accuracy: 1e-4, "symmetric")
        }
        XCTAssertEqual(white.deltaE2000(to: white), 0, accuracy: 1e-9)
    }

    func testNearestAndDuplicates() {
        let palette: [HEXColor] = ["#FF0000", "#00FF00", "#0000FF"]
        XCTAssertEqual(palette.nearest(to: HEXColor("#E01020")), "#FF0000")
        XCTAssertEqual(palette.nearest(to: HEXColor("#2040F0")), "#0000FF")
        XCTAssertNil([HEXColor]().nearest(to: white))

        let colors: [HEXColor] = ["#808080", "#818181", "#FF0000", "#FE0101", "#0000FF"]
        XCTAssertEqual(colors.removingNearDuplicates(), ["#808080", "#FF0000", "#0000FF"])
    }
}
