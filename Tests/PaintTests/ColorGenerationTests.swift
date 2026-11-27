//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
@testable import Paint

/// Tests color scales, meshes, hue shifted scales, subtle
/// gradients, names and sorting.
final class ColorGenerationTests: XCTestCase {

    // MARK: - ColorScale

    func testSequentialScale() {
        let scale = ColorScale.sequential(HEXColor("#E4572E"), domain: 0...100)
        // Lightness falls evenly from light to dark
        let lightness = (0...10).map { scale(Double($0) * 10).toOKLCHColor().lightness }
        XCTAssertEqual(lightness, lightness.sorted(by: >))
        XCTAssertGreaterThan(lightness.first!, 0.9)
        XCTAssertLessThan(lightness.last!, 0.4)
        // Values outside the domain are clamped
        assertEqual(scale(-50), scale(0))
        assertEqual(scale(500), scale(100))
        assertEqual(scale(.nan), scale(50))
        // Ordered with a color vision deficiency too
        let simulated = (0...10).map { scale(Double($0) * 10).simulating(.deuteranopia).toOKLCHColor().lightness }
        XCTAssertEqual(simulated, simulated.sorted(by: >))

        XCTAssertEqual(scale.colors(count: 5).count, 5)
        assertEqual(scale.colors(count: 5)[0], scale(0))
        assertEqual(scale.colors(count: 5)[4], scale(100))
        XCTAssertEqual(scale.colors(count: 0), [])
        assertEqual(scale.colors(count: 1)[0], scale(50))
    }

    func testDivergingScale() {
        let blue = HEXColor("#2563EB")
        let orange = HEXColor("#EA580C")
        let scale = ColorScale.diverging(from: blue, to: orange, domain: -20...100, midpoint: 0)
        // The midpoint is a light neutral
        let middle = scale(0).toOKLCHColor()
        XCTAssertGreaterThan(middle.lightness, 0.9)
        XCTAssertLessThan(middle.chroma, 0.0101)
        // The ends have the hues of the colors and the same lightness
        XCTAssertEqual(scale(-20).toOKLCHColor().hue.degrees, blue.toOKLCHColor().hue.degrees, accuracy: 5)
        XCTAssertEqual(scale(100).toOKLCHColor().hue.degrees, orange.toOKLCHColor().hue.degrees, accuracy: 5)
        XCTAssertEqual(scale(-20).toOKLCHColor().lightness, scale(100).toOKLCHColor().lightness, accuracy: 0.02)
        // Lightness rises to the middle and falls after it
        XCTAssertLessThan(scale(-10).toOKLCHColor().lightness, middle.lightness)
        XCTAssertLessThan(scale(50).toOKLCHColor().lightness, middle.lightness)

        XCTAssertEqual(scale.location(of: -20), 0)
        XCTAssertEqual(scale.location(of: -10), 0.25)
        XCTAssertEqual(scale.location(of: 0), 0.5)
        XCTAssertEqual(scale.location(of: 50), 0.75)
        XCTAssertEqual(scale.location(of: 100), 1)

        // Without a midpoint the domain is linear
        let linear = ColorScale(colors: [blue, orange], domain: 10...20)
        XCTAssertEqual(linear.location(of: 15), 0.5)
        XCTAssertEqual(linear.location(of: 12.5), 0.25)
        // An empty domain maps to the middle
        XCTAssertEqual(ColorScale(colors: [blue, orange], domain: 5...5).location(of: 5), 0.5)
        // A midpoint outside the domain is ignored
        XCTAssertEqual(ColorScale(colors: [blue, orange], domain: 0...10, midpoint: 20).location(of: 5), 0.5)

        try? assertRoundTrips(scale)
    }

    func testDistinguishability() {
        let red = HEXColor("#FF0000")
        let green = HEXColor("#00A000")
        let blue = HEXColor("#0072B2")
        let orange = HEXColor("#E69F00")

        XCTAssertEqual([red].minimumDistance(), .infinity)
        XCTAssertEqual([red, red].minimumDistance(), 0, accuracy: 1e-12)
        XCTAssertGreaterThan([red, green].minimumDistance(), 0.2)
        // Red and green look alike with deuteranopia
        XCTAssertLessThan([red, green].minimumDistance(simulating: .deuteranopia), [red, green].minimumDistance())
        XCTAssertFalse([HEXColor("#D62728"), HEXColor("#2CA02C")].isDistinguishable())
        XCTAssertTrue([HEXColor("#D62728"), HEXColor("#2CA02C")].isDistinguishable(for: []))
        // Blue and orange are safe
        XCTAssertTrue([blue, orange].isDistinguishable())
        XCTAssertFalse([blue, blue].isDistinguishable(for: []))
    }

    // MARK: - ColorMesh

    func testColorMesh() {
        let colors: [HEXColor] = ["#0033FF", "#FFE600", "#FF0066", "#00CC88"]
        let mesh = ColorMesh(width: 2, height: 2, colors: colors)
        XCTAssertEqual(mesh.points, [SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 1), SIMD2(1, 1)])

        // Corners keep their colors
        assertEqual(mesh.color(column: 0, row: 0), colors[0].toRGBAColor(), accuracy: 1e-5)
        assertEqual(mesh.color(column: 1, row: 1), colors[3].toRGBAColor(), accuracy: 1e-5)
        // Edges interpolate in Oklab
        assertEqual(mesh.color(column: 0.5, row: 0), colors[0].interpolated(to: colors[1], by: 0.5), accuracy: 1e-6)

        let subdivided = mesh.subdivided(by: 4)
        XCTAssertEqual(subdivided.width, 5)
        XCTAssertEqual(subdivided.height, 5)
        XCTAssertEqual(subdivided.points.count, 25)
        XCTAssertEqual(subdivided.colors.count, 25)
        assertEqual(subdivided.colors[0], colors[0].toRGBAColor())
        assertEqual(subdivided.colors[24], colors[3].toRGBAColor())
        assertEqual(subdivided.colors[2], mesh.color(column: 0.5, row: 0), accuracy: 1e-9)
        XCTAssertEqual(subdivided.points[12].x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(subdivided.points[12].y, 0.5, accuracy: 1e-12)
        // The midpoint of blue and yellow isn't the gray of sRGB
        XCTAssertGreaterThan(subdivided.colors[2].toOKLCHColor().chroma, 0.05)
        XCTAssertEqual(mesh.subdivided(by: 1), mesh)

        // Incomplete meshes are completed
        let incomplete = ColorMesh(width: 3, height: 1, colors: [HEXColor("#FF0000")])
        XCTAssertEqual(incomplete.height, 2)
        XCTAssertEqual(incomplete.colors.count, 6)
        XCTAssertEqual(incomplete.points.count, 6)
    }

    func testAmbientMesh() throws {
        let colors: [HEXColor] = ["#FF5E3A", "#FF9500", "#5856D6", "#34AADC"]
        let mesh = ColorMesh.ambient(colors: colors, width: 4, height: 3, jitter: 0.3, seed: 7)
        XCTAssertEqual(mesh.points.count, 12)
        // Deterministic
        XCTAssertEqual(mesh, ColorMesh.ambient(colors: colors, width: 4, height: 3, jitter: 0.3, seed: 7))
        XCTAssertNotEqual(mesh, ColorMesh.ambient(colors: colors, width: 4, height: 3, jitter: 0.3, seed: 8))
        let palette = colors.map { $0.toRGBAColor() }
        for row in 0..<3 {
            for column in 0..<4 {
                let index = row * 4 + column
                XCTAssertTrue(palette.contains(mesh.colors[index]))
                // Neighbors differ
                if column > 0 { XCTAssertNotEqual(mesh.colors[index], mesh.colors[index - 1]) }
                if row > 0 { XCTAssertNotEqual(mesh.colors[index], mesh.colors[index - 4]) }
                // Edge points stay on their edges
                let point = mesh.points[index]
                if column == 0 { XCTAssertEqual(point.x, 0) }
                if column == 3 { XCTAssertEqual(point.x, 1) }
                if row == 0 { XCTAssertEqual(point.y, 0) }
                if row == 2 { XCTAssertEqual(point.y, 1) }
                XCTAssertEqual(point.x, Double(column) / 3, accuracy: 0.3 / 3 + 1e-12)
                XCTAssertEqual(point.y, Double(row) / 2, accuracy: 0.3 / 2 + 1e-12)
            }
        }
        // No jitter is a grid
        XCTAssertEqual(ColorMesh.ambient(colors: colors, jitter: 0).points, ColorMesh.grid(width: 3, height: 3))

        let around = ColorMesh.ambient(around: HEXColor("#3B82F6"))
        XCTAssertEqual(around.colors.count, 9)
        for color in around.colors {
            XCTAssertEqual(color.toOKLCHColor().hue.degrees, HEXColor("#3B82F6").toOKLCHColor().hue.degrees, accuracy: 31)
        }

        let swatches = ImageColorSwatches(dominant: HEXColor("#202020").toRGBAColor(), vibrant: HEXColor("#FF0000").toRGBAColor(), lightVibrant: nil, darkVibrant: nil, muted: nil, lightMuted: nil, darkMuted: nil)
        let fromSwatches = ColorMesh(swatches: swatches)
        XCTAssertTrue(fromSwatches.colors.allSatisfy { $0 == HEXColor("#FF0000").toRGBAColor() })
        XCTAssertTrue(ColorMesh(swatches: ImageColorSwatches(dominant: HEXColor("#202020").toRGBAColor(), vibrant: nil, lightVibrant: nil, darkVibrant: nil, muted: nil, lightMuted: nil, darkMuted: nil)).colors.allSatisfy { $0 == HEXColor("#202020").toRGBAColor() })

        try assertRoundTrips(mesh)
        // Decoding completes a mesh
        let decoded = try decode(ColorMesh.self, #"{"width": 2, "height": 2, "colors": [{"red": 1, "green": 0, "blue": 0, "alpha": 1}]}"#)
        XCTAssertEqual(decoded.points.count, 4)
        XCTAssertEqual(decoded.space, .oklab)
    }

    func testMeshGradient() throws {
        guard #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) else {
            throw XCTSkip("Requires iOS 18")
        }
        let mesh = ColorMesh(width: 2, height: 2, colors: [HEXColor("#0033FF"), HEXColor("#FFE600"), HEXColor("#FF0066"), HEXColor("#00CC88")])
        _ = mesh.toMeshGradient()
        _ = mesh.toMeshGradient(subdivisions: 1, background: .black, smoothsColors: false)
    }

    // MARK: - Hue Shift

    func testTonalScaleHueShift() throws {
        let seed = HEXColor("#22C55E")
        let flat = TonalScale(seed: seed)
        let shifted = TonalScale(seed: seed, hueShift: .degrees(15))
        let seedHue = seed.toOKLCHColor().hue.degrees
        // No shift keeps the hue
        for step in TonalScale.steps where flat[step].chroma > 1e-3 {
            XCTAssertEqual(flat[step].hue.degrees, seedHue, accuracy: 1e-6)
        }
        // Light steps turn towards warm, and dark steps towards cool, green sits between
        XCTAssertEqual(shifted[50].hue.degrees, seedHue - 15, accuracy: 1e-6)
        XCTAssertEqual(shifted[950].hue.degrees, seedHue + 15, accuracy: 1e-6)
        XCTAssertEqual(shifted[550].hue.degrees, seedHue, accuracy: 1e-6)
        XCTAssertLessThan(abs(shifted[300].hue.degrees - seedHue), 15)
        // Lightness is unchanged
        for step in TonalScale.steps {
            XCTAssertEqual(shifted[step].lightness, flat[step].lightness, accuracy: 1e-3)
        }
        // The shift never turns past the warm hue
        let orange = TonalScale(seed: OKLCHColor(lightness: 0.7, chroma: 0.15, hue: .degrees(65)), hueShift: .degrees(40))
        XCTAssertEqual(orange[50].hue.degrees, TonalScale.warmHue.degrees, accuracy: 1e-6)

        // Codable, and older scales without a shift decode
        try assertRoundTrips(shifted)
        let json = try assertRoundTrips(flat)
        XCTAssertFalse(json.contains("hueShift"))
        let decoded = try decode(TonalScale.self, #"{"seed": {"lightness": 0.7, "chroma": 0.1, "hue": 0.5, "alpha": 1}, "gamut": "sRGB"}"#)
        XCTAssertEqual(decoded.hueShift, .zero)
    }

    func testSubtleGradient() {
        let accent = HEXColor("#3B82F6")
        let gradient = ColorGradient.subtle(accent)
        XCTAssertEqual(gradient.stops.count, 3)
        let top = gradient.color(at: 0).toOKLCHColor()
        let middle = gradient.color(at: 0.5)
        let bottom = gradient.color(at: 1).toOKLCHColor()
        XCTAssertTrue(middle.isApproximatelyEqual(to: accent, tolerance: 1e-6))
        XCTAssertEqual(top.lightness - accent.toOKLCHColor().lightness, 0.05, accuracy: 0.01)
        XCTAssertEqual(bottom.lightness - accent.toOKLCHColor().lightness, -0.05, accuracy: 0.01)
        // Blue's highlight warms through cyan, and its shadow stays blue
        XCTAssertLessThan(top.hue.degrees, accent.toOKLCHColor().hue.degrees - 4)
        XCTAssertEqual(bottom.hue.degrees, TonalScale.coolHue.degrees, accuracy: 8.01)

        // Grays don't gain a hue
        let gray = ColorGradient.subtle(HEXColor("#808080"))
        XCTAssertLessThan(gray.color(at: 0).toOKLCHColor().chroma, 1e-4)
    }

    // MARK: - Names

    func testDescriptiveName() {
        let names: [(HEXColor, String)] = [
            ("#FFFFFF", "white"),
            ("#000000", "black"),
            ("#808080", "gray"),
            ("#D3D3D3", "light gray"),
            ("#333333", "dark gray"),
            ("#FF0000", "red"),
            ("#FF8000", "orange"),
            ("#FFFF00", "yellow"),
            ("#00FF00", "green"),
            ("#00FFFF", "cyan"),
            ("#0000FF", "blue"),
            ("#8000FF", "purple"),
            ("#FF00FF", "magenta"),
            ("#000080", "dark blue"),
            ("#800000", "dark red"),
            ("#8B4513", "brown"),
            ("#808000", "olive"),
            ("#FFC0CB", "light pink"),
            ("#708090", "grayish blue"),
        ]
        for (color, name) in names {
            XCTAssertEqual(color.toDescriptiveName(), name, "\(color)")
        }
        // Colors outside sRGB are vivid
        XCTAssertEqual(OKLCHColor(lightness: 0.87, chroma: 0.37, hue: .degrees(142)).toDescriptiveName(), "vivid green")
        XCTAssertTrue(HEXColor("#B0C4DE").toDescriptiveName().hasSuffix("blue"))
        XCTAssertTrue(HEXColor("#6B8E23").toDescriptiveName().contains("green") || HEXColor("#6B8E23").toDescriptiveName().contains("olive"))
    }

    func testNearestCSSNamedColor() {
        XCTAssertEqual(HEXColor("#FF0000").toNearestCSSNamedColor().rawValue, "red")
        XCTAssertEqual(HEXColor("#4682B5").toNearestCSSNamedColor().rawValue, "steelblue")
        XCTAssertEqual(HEXColor("#808080").toNearestCSSNamedColor().rawValue, "gray")
        XCTAssertEqual(HEXColor("#00FFFF").toNearestCSSNamedColor().rawValue, "aqua")
        XCTAssertEqual(RGBAColor(red: 0, green: 0, blue: 0, alpha: 0).toNearestCSSNamedColor().rawValue, "black")
        XCTAssertNotEqual(HEXColor("#FFFFFF").toNearestCSSNamedColor().rawValue, "transparent")
    }

    // MARK: - Sorting

    func testSorting() {
        let red = HEXColor("#FF0000")
        let darkRed = HEXColor("#800000")
        let green = HEXColor("#00FF00")
        let blue = HEXColor("#0000FF")
        let white = HEXColor("#FFFFFF")
        let gray = HEXColor("#808080")
        let colors = [gray, blue, white, darkRed, green, red]

        XCTAssertEqual(colors.sorted(by: .lightness), [white, green, red, gray, blue, darkRed])
        XCTAssertEqual(colors.sorted(by: .chroma).first, blue)
        XCTAssertEqual(colors.sorted(by: .hue), [red, darkRed, green, blue, white, gray])
        XCTAssertEqual(colors.sorted(by: .hue(startingAt: .degrees(100))), [green, blue, red, darkRed, white, gray])

        // Stepped snakes through lightness: light to dark, then dark to light
        let stepped = [HEXColor("#FFA0A0"), HEXColor("#800000"), HEXColor("#A0FFA0"), HEXColor("#006000")]
        XCTAssertEqual(stepped.sorted(by: .stepped(segments: 4, startingAt: .degrees(0))), [HEXColor("#FFA0A0"), HEXColor("#800000"), HEXColor("#006000"), HEXColor("#A0FFA0")])
        XCTAssertEqual(stepped.sorted(by: .stepped).count, 4)

        // Stable for equal colors
        let a = RGBAColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let b = RGBAColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        XCTAssertEqual([a, b].sorted(by: .lightness), [a, b])
        XCTAssertEqual([b, a].sorted(by: .lightness), [b, a])
        XCTAssertEqual([HEXColor]().sorted(by: .hue), [])
    }
}
