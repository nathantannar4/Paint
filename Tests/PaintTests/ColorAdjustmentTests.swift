//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif
@testable import Paint

/// Tests gamut mapping, lightening, mixing, prominence and disabled colors.
final class ColorAdjustmentTests: XCTestCase {

    func testOpacity() {
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        func check<C: ColorConvertible>(_ color: C, file: StaticString = #filePath, line: UInt = #line) {
            let alpha = color.toRGBAColor().alpha
            XCTAssertEqual(color.opacity(0.5).toRGBAColor().alpha, alpha * 0.5, accuracy: 1e-9, file: file, line: line)
            XCTAssertEqual(color.opacity(0).toRGBAColor().alpha, 0, file: file, line: line)
            // The result is clamped to `0...1`
            XCTAssertEqual(color.opacity(1.25).toRGBAColor().alpha, 1, accuracy: 1e-9, file: file, line: line)
            XCTAssertEqual(color.opacity(0.5).opacity(2).toRGBAColor().alpha, alpha, accuracy: 1e-9, file: file, line: line)
            XCTAssertEqual(color.opacity(4).toRGBAColor().alpha, 1, accuracy: 1e-9, file: file, line: line)
            XCTAssertEqual(color.opacity(-1).toRGBAColor().alpha, 0, file: file, line: line)
            // Only alpha changes
            assertEqual(color.opacity(0.5).toRGBAColor(), color.toRGBAColor().opacity(0.5), accuracy: 1e-6, file: file, line: line)
        }
        check(rgba)
        check(rgba.toHSBAColor())
        check(rgba.toHSLAColor())
        check(rgba.toHWBColor())
        check(rgba.toCMYKColor())
        check(rgba.toOKLCHColor())
        check(rgba.toOKLabColor())
        check(rgba.toXYZColor())
        check(rgba.toCIELabColor())
        check(rgba.toCIELCHColor())

        // HEX rounds to the nearest 8-bit alpha
        XCTAssertEqual(HEXColor(0xFF8000FF).opacity(0.5), HEXColor(0xFF800080))
        XCTAssertEqual(HEXColor(0xFF8000FF).opacity(0), HEXColor(0xFF800000))
        XCTAssertEqual(HEXColor(0xFF800080).opacity(2), HEXColor(0xFF8000FF))
        XCTAssertEqual(HEXColor(0xFF800080).opacity(1), HEXColor(0xFF800080))

        // CSS keeps the format of its string
        XCTAssertEqual(CSSColor("#FF8000").opacity(0.5).rawValue.prefix(1), "#")
        XCTAssertEqual(CSSColor("#FF8000").opacity(0.5).toRGBAColor().alpha, 0.5, accuracy: 1 / 255)
        XCTAssertTrue(CSSColor("hsl(30 100% 50%)").opacity(0.5).rawValue.hasPrefix("hsl("))
        XCTAssertTrue(CSSColor("oklch(0.7 0.15 250)").opacity(0.5).rawValue.hasPrefix("oklch("))
        XCTAssertTrue(CSSColor("color(display-p3 1 0.5 0)").opacity(0.5).rawValue.hasPrefix("color(display-p3"))
        XCTAssertEqual(CSSColor("oklch(0.7 0.15 250)").opacity(0.5).toRGBAColor().alpha, 0.5, accuracy: 1e-3)
        // Named colors have no alpha, so they're written as `rgb()`
        XCTAssertTrue(CSSColor("red").opacity(0.5).rawValue.hasPrefix("rgb("))
        XCTAssertEqual(CSSColor("rebeccapurple").opacity(1).rawValue, "rebeccapurple")
        XCTAssertEqual(CSSColor("rebeccapurple").opacity(2).rawValue, "rebeccapurple")
        XCTAssertEqual(CSSColor("rgb(255 128 0 / 0.5)").opacity(2).toRGBAColor().alpha, 1)
    }

    func testColorGamut() throws {
        // The exact Display P3 green, rather than rounded components that are just outside it
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let p3Green = try XCTUnwrap(CGColor(colorSpace: colorSpace, components: [0, 1, 0, 1])?.toRGBAColor())
        let srgbGreen = RGBAColor(red: 0, green: 1, blue: 0)
        XCTAssertTrue(ColorGamut.sRGB.contains(srgbGreen))
        XCTAssertTrue(ColorGamut.displayP3.contains(srgbGreen))
        XCTAssertFalse(ColorGamut.sRGB.contains(p3Green))
        XCTAssertTrue(ColorGamut.displayP3.contains(p3Green))
        XCTAssertFalse(ColorGamut.displayP3.contains(RGBAColor(red: -0.6, green: 1.05, blue: -0.35)))
        // White and black are in every gamut, despite floating point error
        XCTAssertTrue(ColorGamut.displayP3.contains(RGBAColor(red: 1, green: 1, blue: 1)))
        XCTAssertTrue(ColorGamut.displayP3.contains(RGBAColor(red: 0, green: 0, blue: 0)))

        // Fitting reduces chroma, keeping lightness and hue
        let oklch = p3Green.toOKLCHColor()
        let fitted = oklch.toColorGamut(.sRGB)
        XCTAssertTrue(ColorGamut.sRGB.contains(fitted.toRGBAColor()))
        XCTAssertEqual(fitted.lightness, oklch.lightness)
        XCTAssertEqual(fitted.hue, oklch.hue)
        XCTAssertLessThan(fitted.chroma, oklch.chroma)
        // The chroma is as high as fits
        var next = fitted
        next.chroma += 0.001
        XCTAssertFalse(ColorGamut.sRGB.contains(next.toRGBAColor()))

        // Colors already in the gamut are unchanged
        XCTAssertEqual(oklch.toColorGamut(.displayP3), oklch)
        XCTAssertEqual(p3Green.toColorGamut(.displayP3), p3Green)
        // Lightness is clamped, and non-finite colors are left alone
        XCTAssertEqual(OKLCHColor(lightness: 1.2, chroma: 0.1, hue: .degrees(30)).toColorGamut(.sRGB).lightness, 1)
        XCTAssertTrue(OKLCHColor(lightness: 0.5, chroma: .nan, hue: 0).toColorGamut(.sRGB).chroma.isNaN)
        XCTAssertTrue(RGBAColor(red: .infinity, green: 0, blue: 0).toColorGamut(.sRGB).red.isInfinite)
    }

    func testLightenedAndDarkened() {
        let color = OKLCHColor(lightness: 0.5, chroma: 0.1, hue: .degrees(200), alpha: 0.5)
        let lighter = color.lightened(by: 0.2)
        XCTAssertEqual(lighter.lightness, 0.7, accuracy: 1e-12)
        XCTAssertEqual(lighter.chroma, color.chroma)
        XCTAssertEqual(lighter.hue, color.hue)
        XCTAssertEqual(lighter.alpha, color.alpha)
        XCTAssertEqual(color.darkened(by: 0.2).lightness, 0.3, accuracy: 1e-12)
        // Clamped to 0...1
        XCTAssertEqual(color.lightened(by: 2).lightness, 1)
        XCTAssertEqual(color.darkened(by: 2).lightness, 0)
        // Saturated colors are fitted to the gamut when lightened
        let red = RGBAColor(red: 1, green: 0, blue: 0)
        XCTAssertTrue(ColorGamut.sRGB.contains(red.lightened(by: 0.3, in: .sRGB).toRGBAColor()))
        XCTAssertTrue(ColorGamut.displayP3.contains(red.lightened(by: 0.3).toRGBAColor()))
        XCTAssertGreaterThan(red.lightened(by: 0.3).chroma, red.lightened(by: 0.3, in: .sRGB).chroma)
        XCTAssertEqual(red.darkened(by: 0.3, in: .sRGB).hue.degrees, red.toOKLCHColor().hue.degrees, accuracy: 1e-9)
        // Works from any color model
        XCTAssertEqual(HEXColor("#336699").lightened(by: 0.1).lightness, HEXColor("#336699").toOKLCHColor().lightness + 0.1, accuracy: 1e-12)
    }

    func testMixed() {
        let blue = RGBAColor(red: 0, green: 0, blue: 1)
        let yellow = RGBAColor(red: 1, green: 1, blue: 0)
        // Oklab's published matrices are only inverses to ~1e-7, magnified near black
        assertEqual(blue.mixed(with: yellow, by: 0).toRGBAColor(), blue, accuracy: 1e-5)
        assertEqual(blue.mixed(with: yellow, by: 1).toRGBAColor(), yellow, accuracy: 1e-5)

        // Lightness is interpolated in Oklab
        let mid = blue.mixed(with: yellow, by: 0.5)
        XCTAssertEqual(mid.lightness, (blue.toOKLCHColor().lightness + yellow.toOKLCHColor().lightness) / 2, accuracy: 1e-9)
        // Unlike sRGB, where the midpoint is a gray with almost no chroma
        let srgbMid = RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertGreaterThan(mid.lightness, srgbMid.toOKLCHColor().lightness)

        // Mixing a color with itself is the color
        let teal = OKLCHColor(lightness: 0.6, chroma: 0.1, hue: .degrees(190))
        let same = teal.mixed(with: teal, by: 0.3)
        XCTAssertEqual(same.lightness, teal.lightness, accuracy: 1e-12)
        XCTAssertEqual(same.chroma, teal.chroma, accuracy: 1e-12)
        XCTAssertEqual(same.hue.degrees, teal.hue.degrees, accuracy: 1e-9)

        // Alpha is premultiplied, so mixing with transparent only fades
        let red = RGBAColor(red: 1, green: 0, blue: 0)
        let faded = red.mixed(with: RGBAColor(red: 1, green: 1, blue: 1, alpha: 0), by: 0.5)
        assertEqual(faded.toRGBAColor(), RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.5), accuracy: 1e-5)

        // Fully transparent mixes don't divide by zero
        let clear = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
        XCTAssertEqual(clear.mixed(with: clear, by: 0.5).alpha, 0)
        XCTAssertFalse(clear.mixed(with: clear, by: 0.5).lightness.isNaN)
    }

    func testProminence() {
        XCTAssertEqual(ColorProminence.allCases.map(\.opacity), [1, 0.6, 0.3, 0.18])

        // Translucent levels multiply alpha
        let rgba = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.5)
        XCTAssertEqual(rgba.withProminence(.primary), rgba)
        XCTAssertEqual(rgba.withProminence(.secondary), RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.3))
        XCTAssertEqual(HEXColor("#336699").withProminence(.tertiary).alpha, 0.3, accuracy: 1e-12)

        // Opaque levels mix towards the background, lowering contrast at each level
        let white = RGBAColor(red: 1, green: 1, blue: 1)
        let blue: HEXColor = "#007AFF"
        assertEqual(blue.withProminence(.primary, against: white).toRGBAColor(), blue.toRGBAColor(), accuracy: 1e-5)
        let contrasts = ColorProminence.allCases.map { blue.withProminence($0, against: white).contrast(.apca).against(white) }
        XCTAssertEqual(contrasts, contrasts.sorted(by: >))
        XCTAssertEqual(blue.withProminence(.secondary, against: white).lightness, blue.toOKLCHColor().lightness * 0.6 + 0.4, accuracy: 1e-6)
        // The color's alpha is kept
        XCTAssertEqual(rgba.withProminence(.quaternary, against: white).alpha, 0.5, accuracy: 1e-12)
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testColorStyle() throws {
        let style = ColorStyle(color: HEXColor("#336699"))
        let resolved = style.resolve(in: EnvironmentValues())
        assertEqual(resolved.toRGBAColor(in: EnvironmentValues()), style.light.toRGBAColor(), accuracy: 1e-6)

        // One color is used for every appearance
        var dark = EnvironmentValues()
        dark.colorScheme = .dark
        assertEqual(style.resolve(in: dark).toRGBAColor(in: dark), style.light.toRGBAColor(), accuracy: 1e-6)
        XCTAssertEqual(style.light, style.dark)
        XCTAssertEqual(style.lightHighContrast, style.light)
        XCTAssertEqual(style.darkHighContrast, style.light)
    }

    /// An environment with a color scheme and contrast.
    private func environment(_ colorScheme: ColorScheme, _ contrast: ColorSchemeContrast = .standard) -> EnvironmentValues {
        var environment = EnvironmentValues()
        environment.colorScheme = colorScheme
        environment._colorSchemeContrast = contrast
        return environment
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testColorStyleHighContrast() throws {
        // A different color, and color model, for each appearance
        let light = HEXColor("#336699")
        let dark = OKLCHColor(lightness: 0.8, chroma: 0.1, hue: .degrees(250))
        let lightHighContrast = RGBAColor(red: 0.05, green: 0.2, blue: 0.4)
        let darkHighContrast = OKLabColor(lightness: 0.92, a: -0.02, b: -0.05)
        let style = ColorStyle(
            light: light,
            dark: dark,
            lightHighContrast: lightHighContrast,
            darkHighContrast: darkHighContrast
        )
        let colors: [RGBAColor] = [light.toRGBAColor(), dark.toRGBAColor(), lightHighContrast, darkHighContrast.toRGBAColor()]
        for (index, color) in colors.enumerated() {
            for other in colors[(index + 1)...] {
                XCTAssertGreaterThan(color.distance(to: other), 0.05, "The colors must be distinguishable")
            }
        }

        func resolved(_ colorScheme: ColorScheme, _ contrast: ColorSchemeContrast = .standard) -> RGBAColor {
            let environment = environment(colorScheme, contrast)
            return style.resolve(in: environment).toRGBAColor(in: environment)
        }
        assertEqual(resolved(.light), light.toRGBAColor(), accuracy: 1e-6)
        assertEqual(resolved(.dark), dark.toRGBAColor(), accuracy: 1e-6)
        assertEqual(resolved(.light, .increased), lightHighContrast, accuracy: 1e-6)
        assertEqual(resolved(.dark, .increased), darkHighContrast.toRGBAColor(), accuracy: 1e-6)
        // The default environment is light, with standard contrast
        assertEqual(style.resolve(in: EnvironmentValues()).toRGBAColor(in: EnvironmentValues()), light.toRGBAColor(), accuracy: 1e-6)
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testColorStyleHighContrastDefaults() throws {
        // Without high contrast colors, increased contrast uses the light and dark colors
        let light = HEXColor("#336699")
        let dark = HEXColor("#99CCFF")
        let style = ColorStyle(light: light, dark: dark)
        XCTAssertEqual(style.lightHighContrast, light)
        XCTAssertEqual(style.darkHighContrast, dark)
        let increasedLight = environment(.light, .increased)
        let increasedDark = environment(.dark, .increased)
        assertEqual(style.resolve(in: increasedLight).toRGBAColor(in: increasedLight), light.toRGBAColor(), accuracy: 1e-6)
        assertEqual(style.resolve(in: increasedDark).toRGBAColor(in: increasedDark), dark.toRGBAColor(), accuracy: 1e-6)

        // One color is used for every appearance and contrast
        let single = ColorStyle(color: light)
        for environment in [environment(.light), environment(.dark), increasedLight, increasedDark] {
            assertEqual(single.resolve(in: environment).toRGBAColor(in: environment), light.toRGBAColor(), accuracy: 1e-6)
        }
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testColorStyleLightAndDark() throws {
        // Different colors, and different color models, for each appearance
        let lightColor = HEXColor("#336699")
        let darkColor = OKLCHColor(lightness: 0.8, chroma: 0.1, hue: .degrees(250))
        let style = ColorStyle(light: lightColor, dark: darkColor)
        XCTAssertGreaterThan(lightColor.distance(to: darkColor), 0.1)

        var light = EnvironmentValues()
        light.colorScheme = .light
        var dark = EnvironmentValues()
        dark.colorScheme = .dark
        func resolved(in environment: EnvironmentValues) -> RGBAColor {
            style.resolve(in: environment).toRGBAColor(in: environment)
        }
        assertEqual(resolved(in: light), lightColor.toRGBAColor(), accuracy: 1e-6)
        assertEqual(resolved(in: dark), darkColor.toRGBAColor(), accuracy: 1e-6)
        // The default environment is light
        assertEqual(resolved(in: EnvironmentValues()), lightColor.toRGBAColor(), accuracy: 1e-6)

        // Wide gamut colors aren't clipped in either appearance
        let p3Green = RGBAColor(red: 0, green: 1, blue: 0, colorSpace: .displayP3)
        let wide = ColorStyle(light: p3Green, dark: p3Green.darkened(by: 0.2))
        XCTAssertFalse(ColorGamut.sRGB.contains(wide.resolve(in: light).toRGBAColor(in: light)))
        XCTAssertFalse(ColorGamut.sRGB.contains(wide.resolve(in: dark).toRGBAColor(in: dark)))
    }

    func testDisabled() {
        let white = RGBAColor(red: 1, green: 1, blue: 1)
        let black = RGBAColor(red: 0, green: 0, blue: 0)
        let blue: HEXColor = "#007AFF"
        let enabled = blue.toOKLCHColor()

        // Mostly desaturated, halfway to the background, keeping the hue
        let onWhite = blue.disabled(against: white)
        XCTAssertEqual(onWhite.lightness, (enabled.lightness + 1) / 2, accuracy: 1e-6)
        XCTAssertEqual(onWhite.chroma, enabled.chroma * 0.1, accuracy: 1e-6)
        XCTAssertEqual(onWhite.hue.degrees, enabled.hue.degrees, accuracy: 1e-6)

        // Lower contrast than the enabled color, but still discernible
        let enabledContrast = blue.contrast(.apca).against(white)
        let disabledContrast = onWhite.contrast(.apca).against(white)
        XCTAssertLessThan(disabledContrast, enabledContrast)
        XCTAssertTrue(disabledContrast.meets(15))

        // Moves towards the background in dark appearances
        let onBlack = blue.disabled(against: black)
        XCTAssertLessThan(onBlack.lightness, enabled.lightness)
        XCTAssertLessThan(onBlack.contrast(.apca).against(black), blue.contrast(.apca).against(black))

        // Grays stay gray, and alpha is kept
        let gray = RGBAColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8).disabled(against: white)
        XCTAssertEqual(gray.chroma, 0, accuracy: 1e-6)
        XCTAssertEqual(gray.alpha, 0.8, accuracy: 1e-12)
        XCTAssertEqual(blue.disabled(against: white).alpha, 1, accuracy: 1e-12)
    }
}
