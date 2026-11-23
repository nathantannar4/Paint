//
// Copyright (c) Nathan Tannar
//

import XCTest
import simd
@testable import Paint

/// Tests color vision deficiency, blending, temperature, filter transforms and
/// chroma, hue and appearance adjustments.
final class ColorEffectTests: XCTestCase {

    private let black = RGBAColor(red: 0, green: 0, blue: 0)
    private let white = RGBAColor(red: 1, green: 1, blue: 1)
    private let red = RGBAColor(red: 1, green: 0, blue: 0)
    private let green = RGBAColor(red: 0, green: 0.6, blue: 0)

    // MARK: Color Vision Deficiency

    func testSimulation() {
        for deficiency in ColorVisionDeficiency.allCases {
            // White and black are unaffected, and severity 0 is normal vision
            assertEqual(white.simulating(deficiency), white, accuracy: 1e-4)
            assertEqual(black.simulating(deficiency), black)
            assertEqual(red.simulating(deficiency, severity: 0), red, accuracy: 1e-9)
            assertEqual(ColorTransform.simulating(deficiency, severity: 0), .identity)
        }
        // Red and green are much closer for protanopes and deuteranopes
        let normal = red.distance(to: green)
        XCTAssertLessThan(red.simulating(.protanopia).distance(to: green.simulating(.protanopia)), normal / 2)
        XCTAssertLessThan(red.simulating(.deuteranopia).distance(to: green.simulating(.deuteranopia)), normal / 2)
        // Partial severity is in between
        let partial = red.simulating(.deuteranopia, severity: 0.5).distance(to: green.simulating(.deuteranopia, severity: 0.5))
        XCTAssertLessThan(partial, normal)
        XCTAssertGreaterThan(partial, red.simulating(.deuteranopia).distance(to: green.simulating(.deuteranopia)))
        // Achromatopsia has no hue
        XCTAssertEqual(red.simulating(.achromatopsia).toOKLCHColor().chroma, 0, accuracy: 1e-6)

        // Daltonizing makes red and green easier to tell apart for deuteranopes
        let simulatedDistance = red.simulating(.deuteranopia).distance(to: green.simulating(.deuteranopia))
        let daltonizedDistance = red.daltonized(for: .deuteranopia).simulating(.deuteranopia)
            .distance(to: green.daltonized(for: .deuteranopia).simulating(.deuteranopia))
        XCTAssertGreaterThan(daltonizedDistance, simulatedDistance)
        assertEqual(red.daltonized(for: .achromatopsia), red, accuracy: 1e-9)
        // Grays are unchanged by daltonizing
        let gray = RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
        assertEqual(gray.daltonized(for: .protanopia), gray, accuracy: 1e-4)
    }

    // MARK: Blending

    func testBlending() {
        let color = RGBAColor(red: 0.2, green: 0.4, blue: 0.8)
        assertEqual(white.blended(over: color, mode: .multiply), color)
        assertEqual(black.blended(over: color, mode: .screen), color)
        assertEqual(color.blended(over: color, mode: .difference), black)
        assertEqual(color.blended(over: white, mode: .normal), color)
        assertEqual(RGBAColor(red: 0.5, green: 0.5, blue: 0.5).blended(over: color, mode: .multiply), RGBAColor(red: 0.1, green: 0.2, blue: 0.4))
        // Luminosity keeps the backdrop's hue
        let luminosity = white.blended(over: red, mode: .luminosity)
        XCTAssertEqual(luminosity.red, 1, accuracy: 1e-9)
        // Color takes the source hue and backdrop luminosity
        let colored = red.blended(over: RGBAColor(red: 0.5, green: 0.5, blue: 0.5), mode: .color)
        XCTAssertGreaterThan(colored.red, colored.green)
        // Every mode gives valid colors
        for mode in ColorBlendMode.allCases {
            let result = color.blended(over: red, mode: mode)
            for component in [result.red, result.green, result.blue] {
                XCTAssertTrue((-1e-9...(1 + 1e-9)).contains(component), "\(mode)")
            }
        }

        // Compositing
        assertEqual(RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.5).composited(over: white), RGBAColor(red: 0.5, green: 0.5, blue: 0.5))
        let clear = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
        XCTAssertEqual(clear.composited(over: clear).alpha, 0)
        let translucent = RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.5).composited(over: RGBAColor(red: 0, green: 0, blue: 1, alpha: 0.5))
        XCTAssertEqual(translucent.alpha, 0.75, accuracy: 1e-9)
        XCTAssertEqual(translucent.red, 2.0 / 3, accuracy: 1e-9)
        // Blending over a transparent backdrop is the source
        assertEqual(color.blended(over: clear, mode: .multiply), color)
    }

    // MARK: Temperature

    func testTemperature() throws {
        let cct = try XCTUnwrap(white.toCorrelatedColorTemperature())
        XCTAssertEqual(cct, 6504, accuracy: 10)
        XCTAssertNil(black.toCorrelatedColorTemperature())
        // McCamy's formula is undefined at y = 0.1858
        XCTAssertNil(XYZColor(x: 0.3, y: 0.1858, z: 0.5142).toCorrelatedColorTemperature())

        let warm = RGBAColor(kelvin: 2700)
        XCTAssertEqual(warm.red, 1, accuracy: 1e-9)
        XCTAssertLessThan(warm.blue, 0.7)
        let cool = RGBAColor(kelvin: 10000)
        XCTAssertEqual(cool.blue, 1, accuracy: 1e-9)
        XCTAssertLessThan(cool.red, 0.9)
        let daylight = RGBAColor(kelvin: 6500)
        XCTAssertLessThan(daylight.distance(to: white), 0.02)

        for kelvin in [3000.0, 4000, 5000, 6500, 8000] {
            let estimated = try XCTUnwrap(RGBAColor(kelvin: kelvin).toCorrelatedColorTemperature())
            XCTAssertEqual(estimated, kelvin, accuracy: kelvin * 0.02, "\(kelvin)K")
        }
        XCTAssertGreaterThan(try XCTUnwrap(RGBAColor(kelvin: 2000).toCorrelatedColorTemperature()), try XCTUnwrap(RGBAColor(kelvin: 1000).toCorrelatedColorTemperature()) - 1)
    }

    func testTemperatureString() throws {
        // Whole kelvin with the symbol, and alpha only when translucent
        XCTAssertEqual(ColorStringFormatter.temperature(6504.4, alpha: 1), "6504 K")
        XCTAssertEqual(ColorStringFormatter.temperature(2700.5, alpha: 1), "2701 K")
        XCTAssertEqual(ColorStringFormatter.temperature(6504, alpha: 0.5), "6504 K / 0.5")
        XCTAssertEqual(ColorStringFormatter.temperature(6504, alpha: 0), "6504 K / 0")
        XCTAssertEqual(ColorStringFormatter.temperature(6504, alpha: 0.9999), "6504 K")

        // McCamy's estimate for sRGB white is 6505.08
        XCTAssertEqual(white.toCorrelatedColorTemperatureString(), "6505 K")
        var translucent = white.toRGBAColor()
        translucent.alpha = 0.25
        XCTAssertEqual(translucent.toCorrelatedColorTemperatureString(), "6505 K / 0.25")
        XCTAssertNil(black.toCorrelatedColorTemperatureString())

        // Matches the estimate for every color model
        let colors: [any ColorConvertible] = [
            RGBAColor(kelvin: 2700),
            RGBAColor(kelvin: 5000, alpha: 0.5),
            HEXColor("#FFD8A8"),
            OKLCHColor(lightness: 0.9, chroma: 0.03, hue: .degrees(240)),
        ]
        for color in colors {
            let kelvin = try XCTUnwrap(color.toCorrelatedColorTemperature())
            XCTAssertEqual(
                color.toCorrelatedColorTemperatureString(),
                ColorStringFormatter.temperature(kelvin, alpha: color.toRGBAColor().alpha),
                "\(color)"
            )
        }
    }

    // MARK: Filter Transforms

    func testColorTransformStorage() {
        // Named factors map onto the simd transform, indexed by column then row
        var colorTransform = ColorTransform(r2: 5, g5: 0.25, a3: 2)
        XCTAssertEqual(colorTransform.transform[1][0], 5)
        XCTAssertEqual(colorTransform.transform[2][3], 2)
        XCTAssertEqual(colorTransform.offset, SIMD4(0, 0.25, 0, 0))
        colorTransform.transform[0][2] = 3
        XCTAssertEqual(colorTransform.b1, 3)
        XCTAssertEqual(ColorTransform(transform: colorTransform.transform, offset: colorTransform.offset), colorTransform)

        // Applying matches the simd product, at the color's Double precision
        let color = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let expected = colorTransform.transform * SIMD4<Float>(0.2, 0.4, 0.6, 0.8) + colorTransform.offset
        let applied = color.applying(colorTransform)
        XCTAssertEqual(applied.red, Double(expected.x), accuracy: 1e-6)
        XCTAssertEqual(applied.green, Double(expected.y), accuracy: 1e-6)
        XCTAssertEqual(applied.blue, Double(expected.z), accuracy: 1e-6)
        XCTAssertEqual(applied.alpha, Double(expected.w), accuracy: 1e-6)

        // 3x3 conversions embed in the RGB part, leaving alpha alone
        let embedded = ColorTransform(matrix_identity_double3x3 * 2)
        assertEqual(embedded, ColorTransform(r1: 2, g2: 2, b3: 2))
    }

    func testFilterTransforms() {
        assertEqual(ColorTransform.saturation(1), .identity)
        assertEqual(ColorTransform.hueRotation(0), .identity)
        assertEqual(ColorTransform.grayscale(0), .identity)
        assertEqual(ColorTransform.sepia(0), .identity)
        assertEqual(ColorTransform.inversion(0), .identity)
        assertEqual(ColorTransform.brightness(1), .identity)
        assertEqual(ColorTransform.contrast(1), .identity)
        assertEqual(ColorTransform.opacity(1), .identity)
        assertEqual(ColorTransform.opacity(2), .identity)
        assertEqual(ColorTransform.opacity(-1), ColorTransform.opacity(0))

        let color = RGBAColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.5)
        let gray = color.applying(.saturation(0))
        XCTAssertEqual(gray.red, gray.green, accuracy: 1e-6)
        XCTAssertEqual(gray.green, gray.blue, accuracy: 1e-6)
        assertEqual(color.applying(.grayscale()), color.applying(.saturation(0)), accuracy: 0.01)
        assertEqual(color.applying(.inversion()), RGBAColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 0.5), accuracy: 1e-6)
        assertEqual(color.applying(.contrast(0)), RGBAColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5), accuracy: 1e-6)
        XCTAssertEqual(color.applying(.opacity(0.5)).alpha, 0.25, accuracy: 1e-6)
        // A full turn is the identity
        assertEqual(ColorTransform.hueRotation(.degrees(359.9999)), .identity, accuracy: 1e-4)
        // Simulation transforms keep white
        assertEqual(white.applying(.simulating(.protanopia)), white, accuracy: 1e-5)
    }

    // MARK: Adjustments

    func testChromaAndHueAdjustments() {
        let color = OKLCHColor(lightness: 0.6, chroma: 0.1, hue: .degrees(250), alpha: 0.5)
        XCTAssertEqual(color.saturated(by: 0.05).chroma, 0.15, accuracy: 1e-9)
        XCTAssertEqual(color.desaturated(by: 0.05).chroma, 0.05, accuracy: 1e-9)
        XCTAssertEqual(color.desaturated(by: 1).chroma, 0)
        // Saturating is limited by the gamut
        XCTAssertTrue(ColorGamut.sRGB.contains(color.saturated(by: 1, in: .sRGB)))
        XCTAssertEqual(color.hueRotated(by: .degrees(20)).hue.degrees, 270, accuracy: 1e-9)
        XCTAssertEqual(color.hueRotated(by: .degrees(20)).lightness, 0.6)

        let gray = color.grayscale()
        XCTAssertEqual(gray.chroma, 0)
        XCTAssertEqual(gray.lightness, 0.6)
        XCTAssertEqual(gray.alpha, 0.5)

        assertEqual(red.inverted(), RGBAColor(red: 0, green: 1, blue: 1))
        XCTAssertTrue(white.contrast(.apca).isLight)
        XCTAssertFalse(black.contrast(.apca).isLight)
    }

    func testAppearanceVariants() {
        let accent = HEXColor("#0A84FF")
        let lightBackground = HEXColor("#FFFFFF")
        let darkBackground = HEXColor("#1C1C1E")

        let original = accent.contrast(.apca).against(lightBackground)
        let dark = accent.adapted(from: lightBackground, to: darkBackground)
        let adapted = dark.contrast(.apca).against(darkBackground)
        XCTAssertFalse(original.isLightOnDark)
        XCTAssertTrue(adapted.isLightOnDark)
        XCTAssertEqual(adapted.magnitude, original.magnitude, accuracy: 0.5)
        XCTAssertEqual(dark.toOKLCHColor().hue.degrees, accent.toOKLCHColor().hue.degrees, accuracy: 2)

        // Unreachable contrast gives the most possible
        let black = HEXColor("#000000")
        XCTAssertEqual(black.adapted(from: lightBackground, to: HEXColor("#808080")).toHEXColor(), "#FFFFFF")

        let increased = accent.contrast(.apca).increased(against: lightBackground)
        XCTAssertEqual(increased.contrast(.apca).against(lightBackground).magnitude, original.magnitude + 15, accuracy: 0.5)
    }

    #if os(macOS)
    @available(macOS 11.0, *)
    func testDynamicNSColor() throws {
        func resolved(_ color: NSColor, _ name: NSAppearance.Name) throws -> RGBAColor {
            try XCTUnwrap(color.toRGBAColor(for: try XCTUnwrap(NSAppearance(named: name))))
        }
        let color = NSColor(light: HEXColor("#FF0000"), dark: HEXColor("#0000FF"))
        assertEqual(try resolved(color, .aqua), red, accuracy: 1e-6)
        assertEqual(try resolved(color, .darkAqua), RGBAColor(red: 0, green: 0, blue: 1), accuracy: 1e-6)

        // The high contrast colors don't change the standard ones. `NSAppearance(named:)`
        // returns the standard appearance for the high contrast names, which only
        // apply when the system setting is on, so they can't be resolved here.
        let highContrast = NSColor(
            light: HEXColor("#FF0000"),
            dark: HEXColor("#0000FF"),
            lightHighContrast: HEXColor("#800000"),
            darkHighContrast: HEXColor("#00FF00")
        )
        assertEqual(try resolved(highContrast, .aqua), red, accuracy: 1e-6)
        assertEqual(try resolved(highContrast, .darkAqua), RGBAColor(red: 0, green: 0, blue: 1), accuracy: 1e-6)
    }
    #endif

    #if os(iOS) || os(tvOS) || os(visionOS)
    func testDynamicUIColor() throws {
        func resolved(_ color: UIColor, _ style: UIUserInterfaceStyle, _ contrast: UIAccessibilityContrast = .normal) throws -> RGBAColor {
            try XCTUnwrap(color.toRGBAColor(compatibleWith: UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: style),
                UITraitCollection(accessibilityContrast: contrast),
            ])))
        }
        let color = UIColor(light: HEXColor("#FF0000"), dark: HEXColor("#0000FF"))
        assertEqual(try resolved(color, .light), red, accuracy: 1e-6)
        assertEqual(try resolved(color, .dark), RGBAColor(red: 0, green: 0, blue: 1), accuracy: 1e-6)
        // Without high contrast colors, high contrast uses the light and dark colors
        assertEqual(try resolved(color, .light, .high), red, accuracy: 1e-6)
        assertEqual(try resolved(color, .dark, .high), RGBAColor(red: 0, green: 0, blue: 1), accuracy: 1e-6)

        let highContrast = UIColor(
            light: HEXColor("#FF0000"),
            dark: HEXColor("#0000FF"),
            lightHighContrast: HEXColor("#800000"),
            darkHighContrast: HEXColor("#00FF00")
        )
        assertEqual(try resolved(highContrast, .light), red, accuracy: 1e-6)
        assertEqual(try resolved(highContrast, .dark), RGBAColor(red: 0, green: 0, blue: 1), accuracy: 1e-6)
        assertEqual(try resolved(highContrast, .light, .high), HEXColor("#800000").toRGBAColor(), accuracy: 1e-6)
        assertEqual(try resolved(highContrast, .dark, .high), RGBAColor(red: 0, green: 1, blue: 0), accuracy: 1e-6)
    }
    #endif
}
