//
// Copyright (c) Nathan Tannar
//

import XCTest
@testable import Paint

final class ColorDescriptionTests: XCTestCase {

    private let blue = RGBAColor(red: 0, green: 0.478, blue: 1)

    func testColorModels() {
        XCTAssertEqual(blue.description, "rgb(0% 47.8% 100%)")
        XCTAssertEqual(blue.toHSBAColor().description, "hsb(211.32 100% 100%)")
        XCTAssertEqual(blue.toHSLAColor().description, "hsl(211.32 100% 50%)")
        XCTAssertEqual(blue.toHWBColor().description, "hwb(211.32 0% 0%)")
        XCTAssertEqual(blue.toCMYKColor().description, "device-cmyk(100% 52.2% 0% 0%)")
        XCTAssertEqual(blue.toOKLCHColor().description, "oklch(0.6025 0.2178 257.45)")
        XCTAssertEqual(blue.toOKLabColor().description, "oklab(0.6025 -0.0473 -0.2126)")
        XCTAssertEqual(blue.toXYZColor().description, "color(xyz-d65 0.2499 0.2111 0.9737)")
        XCTAssertEqual(blue.toCIELabColor().description, "lab(51.82 12.2 -75.32)")
        XCTAssertEqual(blue.toCIELCHColor().description, "lch(51.82 76.31 279.2)")
        XCTAssertEqual(ColorHue.degrees(211.76).description, "211.76°")
    }

    func testAlphaIsWrittenOnlyWhenTranslucent() {
        var translucent = blue
        translucent.alpha = 0.5
        XCTAssertEqual(translucent.description, "rgb(0% 47.8% 100% / 0.5)")
        XCTAssertEqual("\(OKLCHColor(lightness: 0.5, chroma: 0, hue: 0, alpha: 0.25))", "oklch(0.5 0 0 / 0.25)")
    }

    func testComponentsOutsideSRGBAreKept() {
        // Described as stored, without gamut mapping
        let red = RGBAColor(red: 1, green: 0, blue: 0, colorSpace: .displayP3)
        XCTAssertEqual(red.description, "rgb(109.31% -22.67% -15.01%)")
    }

    func testNames() {
        XCTAssertEqual(ColorGamut.displayP3.description, "Display P3")
        XCTAssertEqual(ColorSpace.linearDisplayP3.description, "Linear Display P3")
        XCTAssertEqual(ColorBlendMode.colorDodge.description, "colorDodge")
        XCTAssertEqual(ColorHarmony.splitComplementary.description, "splitComplementary")
        XCTAssertEqual(ColorInterpolationSpace.oklch.description, "oklch")
        XCTAssertEqual(HueInterpolation.shorter.description, "shorter")
        XCTAssertEqual(ColorProminence.secondary.description, "secondary")
        XCTAssertEqual(ColorVisionDeficiency.deuteranopia.description, "deuteranopia")
        XCTAssertEqual(CSSColorFormat.displayP3.description, "displayP3")
    }
}
