//
// Copyright (c) Nathan Tannar
//

import XCTest
import SwiftUI
@testable import Paint

/// Tests interpolation, gradients, harmonies, tonal scales and generated colors.
final class ColorGradientTests: XCTestCase {

    private let black = RGBAColor(red: 0, green: 0, blue: 0)
    private let white = RGBAColor(red: 1, green: 1, blue: 1)
    private let blue = RGBAColor(red: 0, green: 0, blue: 1)
    private let yellow = RGBAColor(red: 1, green: 1, blue: 0)

    // MARK: Interpolation

    func testInterpolationSpaces() {
        assertEqual(black.interpolated(to: white, by: 0.5, in: .sRGB), RGBAColor(red: 0.5, green: 0.5, blue: 0.5))
        let linear = RGBAColor.delinearize(0.5)
        assertEqual(black.interpolated(to: white, by: 0.5, in: .linearSRGB), RGBAColor(red: linear, green: linear, blue: linear))
        // Ends are exact
        assertEqual(blue.interpolated(to: yellow, by: 0, in: .oklch), blue, accuracy: 1e-5)
        assertEqual(blue.interpolated(to: yellow, by: 1, in: .oklch), yellow, accuracy: 1e-5)

        // sRGB midpoints of complementary colors are gray, OKLCH midpoints are not
        let sRGB = blue.interpolated(to: yellow, by: 0.5, in: .sRGB).toOKLCHColor()
        let oklab = blue.interpolated(to: yellow, by: 0.5, in: .oklab).toOKLCHColor()
        let oklch = blue.interpolated(to: yellow, by: 0.5, in: .oklch).toOKLCHColor()
        XCTAssertLessThan(sRGB.chroma, 0.01)
        XCTAssertGreaterThan(oklch.chroma, 0.2)
        XCTAssertGreaterThan(oklab.lightness, sRGB.lightness)

        // Interpolating with transparent fades without changing the color
        let clear = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
        for space in ColorInterpolationSpace.allCases {
            let faded = blue.interpolated(to: clear, by: 0.5, in: space)
            XCTAssertEqual(faded.alpha, 0.5, accuracy: 1e-9, "\(space)")
            XCTAssertEqual(faded.blue, 1, accuracy: 1e-6, "\(space)")
        }

        // Achromatic colors take the other hue in OKLCH
        let red = RGBAColor(red: 1, green: 0, blue: 0)
        let toWhite = red.interpolated(to: white, by: 0.5, in: .oklch).toOKLCHColor()
        XCTAssertEqual(toWhite.hue.degrees, red.toOKLCHColor().hue.degrees, accuracy: 0.5)
    }

    func testHueInterpolation() {
        let start = OKLCHColor(lightness: 0.7, chroma: 0.05, hue: .degrees(10))
        let end = OKLCHColor(lightness: 0.7, chroma: 0.05, hue: .degrees(350))
        func midpointHue(_ hue: HueInterpolation) -> Double {
            start.interpolated(to: end, by: 0.5, in: .oklch, hue: hue).toOKLCHColor().hue.degrees
        }
        func angle(_ lhs: Double, _ rhs: Double) -> Double {
            let difference = abs(lhs - rhs).truncatingRemainder(dividingBy: 360)
            return min(difference, 360 - difference)
        }
        XCTAssertLessThan(angle(midpointHue(.shorter), 0), 0.5)
        XCTAssertLessThan(angle(midpointHue(.longer), 180), 0.5)
        XCTAssertLessThan(angle(midpointHue(.increasing), 180), 0.5)
        XCTAssertLessThan(angle(midpointHue(.decreasing), 0), 0.5)
    }

    // MARK: Gradient

    func testGradient() {
        let gradient = ColorGradient(colors: [blue, yellow], in: .oklch)
        assertEqual(gradient.color(at: -1), blue)
        assertEqual(gradient.color(at: 2), yellow)
        assertEqual(gradient.color(at: 0.5), blue.interpolated(to: yellow, by: 0.5, in: .oklch))
        XCTAssertEqual(gradient.colors(count: 5).count, 5)
        XCTAssertEqual(gradient.colors(count: 0).count, 0)

        // Stops are sorted, and coincident stops make a hard edge
        let hard = ColorGradient(stops: [
            .init(color: white, location: 1),
            .init(color: black, location: 0),
            .init(color: blue, location: 0.5),
            .init(color: yellow, location: 0.5),
        ])
        XCTAssertEqual(hard.stops.map(\.location), [0, 0.5, 0.5, 1])
        assertEqual(hard.color(at: 0.5), yellow)
        XCTAssertGreaterThan(hard.color(at: 0.499).blue, 0.9)

        // SwiftUI gradients add stops between each pair, except at hard edges
        XCTAssertEqual(gradient.toGradient(stopsPerSegment: 8).stops.count, 9)
        XCTAssertEqual(hard.toGradient(stopsPerSegment: 4).stops.count, 4 + 1 + 4 + 1)
        // Even sRGB gradients get stops, since renderers don't all blend in sRGB
        XCTAssertGreaterThan(ColorGradient(colors: [blue, yellow], in: .sRGB).toGradient().stops.count, 2)

        XCTAssertEqual(ColorGradient(colors: [HEXColor]()).color(at: 0.5).alpha, 0)
        assertEqual(ColorGradient(colors: [blue]).color(at: 0.7), blue)
    }

    func testCSSInterpolationSpaces() {
        let red = RGBAColor(red: 1, green: 0, blue: 0)
        let green = RGBAColor(red: 0, green: 1, blue: 0)
        for space in ColorInterpolationSpace.allCases {
            // Ends are exact in every space
            assertEqual(blue.interpolated(to: yellow, by: 0, in: space), blue, accuracy: 1e-5)
            assertEqual(blue.interpolated(to: yellow, by: 1, in: space), yellow, accuracy: 1e-5)
        }
        // CIE Lab and LCh match their own components halfway
        let labMid = red.interpolated(to: green, by: 0.5, in: .lab).toCIELabColor()
        let (redLab, greenLab) = (red.toCIELabColor(), green.toCIELabColor())
        // Converted back from sRGB, so not exact
        XCTAssertEqual(labMid.lightness, (redLab.lightness + greenLab.lightness) / 2, accuracy: 1e-4)
        XCTAssertEqual(labMid.a, (redLab.a + greenLab.a) / 2, accuracy: 1e-3)
        let lchMid = red.interpolated(to: green, by: 0.5, in: .lch).toCIELCHColor()
        let (redLCH, greenLCH) = (red.toCIELCHColor(), green.toCIELCHColor())
        XCTAssertEqual(lchMid.chroma, (redLCH.chroma + greenLCH.chroma) / 2, accuracy: 1e-3)

        // HSL and HWB interpolate hue, so red to green passes through yellow
        for space in [ColorInterpolationSpace.hsl, .hwb] {
            assertEqual(red.interpolated(to: green, by: 0.5, in: space), RGBAColor(red: 1, green: 1, blue: 0), accuracy: 1e-9)
            assertEqual(red.interpolated(to: green, by: 0.5, in: space, hue: .longer), RGBAColor(red: 0, green: 0, blue: 1), accuracy: 1e-9)
        }

        // Achromatic colors take the other hue in every polar space, measured in its own hue
        func hue(_ color: RGBAColor, in space: ColorInterpolationSpace) -> Double {
            switch space {
            case .oklch: color.toOKLCHColor().hue.degrees
            case .lch: color.toCIELCHColor().hue.degrees
            case .hsl: color.toHSLAColor().hue.degrees
            default: color.toHWBColor().hue.degrees
            }
        }
        for space in ColorInterpolationSpace.allCases where space.isPolar {
            let difference = abs(hue(red.interpolated(to: white, by: 0.5, in: space), in: space) - hue(red, in: space))
            XCTAssertLessThan(min(difference, 360 - difference), 0.5, "\(space)")
        }
        XCTAssertEqual(ColorInterpolationSpace.allCases.filter(\.isPolar), [.oklch, .lch, .hsl, .hwb])
    }

    func testReversed() {
        let gradient = ColorGradient(stops: [.init(color: blue, location: 0), .init(color: yellow, location: 0.25)], in: .oklch)
        let reversed = gradient.reversed()
        XCTAssertEqual(reversed.stops.map(\.location), [0.75, 1])
        XCTAssertEqual(reversed.space, .oklch)
        for location in stride(from: 0.0, through: 1, by: 0.1) {
            assertEqual(reversed.color(at: 1 - location), gradient.color(at: location), accuracy: 1e-9)
        }
    }

    // MARK: Curves

    func testCurveShapes() {
        typealias Curve = ColorGradient.Curve
        let samples = stride(from: 0.05, to: 1, by: 0.05).map { $0 }
        for curve in [Curve.linear, .easeIn, .easeOut, .easeInOut] {
            XCTAssertEqual(curve.value(at: 0), 0, accuracy: 1e-9, "\(curve)")
            XCTAssertEqual(curve.value(at: 1), 1, accuracy: 1e-9, "\(curve)")
            // Always moving forward
            XCTAssertEqual(samples.map(curve.value(at:)), samples.map(curve.value(at:)).sorted(), "\(curve)")
        }
        for x in samples {
            XCTAssertEqual(Curve.linear.value(at: x), x)
            XCTAssertLessThan(Curve.easeIn.value(at: x), x)
            XCTAssertGreaterThan(Curve.easeOut.value(at: x), x)
            // Symmetric about the middle
            XCTAssertEqual(Curve.easeInOut.value(at: x) + Curve.easeInOut.value(at: 1 - x), 1, accuracy: 1e-9)
        }
        XCTAssertEqual(Curve.easeInOut.value(at: 0.5), 0.5, accuracy: 1e-9)
        // Progress outside `0...1` is clamped
        XCTAssertEqual(Curve.easeIn.value(at: -1), 0)
        XCTAssertEqual(Curve.easeIn.value(at: 2), 1)
        XCTAssertEqual(Curve.easeIn.value(at: .nan), 0)
    }

    func testCurveReversed() {
        typealias Curve = ColorGradient.Curve
        XCTAssertEqual(Curve.easeIn.reversed(), .easeOut)
        XCTAssertEqual(Curve.easeOut.reversed(), .easeIn)
        XCTAssertEqual(Curve.easeInOut.reversed(), .easeInOut)
        XCTAssertEqual(Curve.easeIn.reversed().reversed(), .easeIn)
        let custom = Curve.bezier(x1: 0.1, y1: 0.6, x2: 0.3, y2: 1)
        for x in stride(from: 0.0, through: 1, by: 0.1) {
            XCTAssertEqual(custom.reversed().value(at: x), 1 - custom.value(at: 1 - x), accuracy: 1e-9)
        }
        // Control points move forward, but can overshoot
        let clamped = Curve.bezier(x1: -1, y1: 2, x2: 3, y2: -1)
        XCTAssertEqual(clamped.x1, 0)
        XCTAssertEqual(clamped.y1, 2)
        XCTAssertEqual(clamped.x2, 1)
        XCTAssertEqual(clamped.y2, -1)
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func testCurveMatchesUnitCurve() {
        for (curve, unitCurve) in [(ColorGradient.Curve.easeIn, UnitCurve.easeIn), (.easeOut, .easeOut), (.easeInOut, .easeInOut), (.linear, .linear)] {
            for x in stride(from: 0.0, through: 1, by: 0.1) {
                XCTAssertEqual(curve.value(at: x), unitCurve.value(at: x), accuracy: 1e-3, "\(curve) at \(x)")
            }
        }
    }

    func testGradientWithCurve() throws {
        let linear = ColorGradient(colors: [black, white], in: .sRGB)
        let easeIn = ColorGradient(from: black, to: white, curve: .easeIn, in: .sRGB)
        let easeInOut = ColorGradient(from: black, to: white, curve: .easeInOut, in: .sRGB)
        // The curve sets how far each location has moved between the stops
        assertEqual(easeIn.color(at: 0.25), black.interpolated(to: white, by: ColorGradient.Curve.easeIn.value(at: 0.25), in: .sRGB))
        XCTAssertLessThan(easeIn.color(at: 0.25).red, linear.color(at: 0.25).red)
        assertEqual(easeInOut.color(at: 0.5), linear.color(at: 0.5), accuracy: 1e-9)
        assertEqual(easeIn.color(at: 0), black)
        assertEqual(easeIn.color(at: 1), white)

        // Each segment between stops is eased
        let threeStops = ColorGradient(colors: [black, white, black], in: .sRGB, curve: .easeIn)
        assertEqual(threeStops.color(at: 0.25), easeIn.color(at: 0.5), accuracy: 1e-9)

        // Reversed gradients look the same, flipped
        let reversed = easeIn.reversed()
        XCTAssertEqual(reversed.curve, .easeOut)
        for location in stride(from: 0.0, through: 1, by: 0.1) {
            assertEqual(reversed.color(at: 1 - location), easeIn.color(at: location), accuracy: 1e-9)
        }
    }

    func testGradientWithCurveRendering() {
        for curve in [ColorGradient.Curve.easeIn, .easeOut, .easeInOut] {
            let gradient = ColorGradient(from: blue, to: yellow, curve: curve)
            let stops = gradient.toRenderingStops()
            // Renderers follow the curve, so its bends get stops
            XCTAssertLessThanOrEqual(maximumError(of: stops, against: gradient), ColorGradient.defaultTolerance * 1.5, "\(curve)")
            XCTAssertGreaterThan(stops.count, 2, "\(curve)")
        }
    }

    func testGradientCurveCodable() throws {
        let gradient = ColorGradient(from: blue, to: yellow, curve: .easeInOut, in: .oklch)
        let data = try JSONEncoder().encode(gradient)
        XCTAssertEqual(try JSONDecoder().decode(ColorGradient.self, from: data), gradient)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains(#""curve""#))
        // Gradients encoded without a curve are linear
        let old = #"{"stops":[{"color":{"red":0,"green":0,"blue":1,"alpha":1},"location":0},{"color":{"red":1,"green":1,"blue":0,"alpha":1},"location":1}],"space":"oklab","hue":"shorter"}"#
        XCTAssertEqual(try JSONDecoder().decode(ColorGradient.self, from: Data(old.utf8)).curve, .linear)
    }

    // MARK: Stops for renderers

    /// The largest rendering error of stops, sampled densely between each pair.
    ///
    /// Pieces split to the limit, 1/256 of a segment, are skipped: they can exceed the
    /// tolerance right next to black, where renderers disagree most.
    private func maximumError(of stops: [ColorGradient.Stop], against gradient: ColorGradient) -> Double {
        var maximum = 0.0
        for (start, end) in zip(stops, stops.dropFirst()) where end.location - start.location > 1.0 / 256 + 1e-12 {
            for sample in stride(from: 0.0, through: 1, by: 1.0 / 32) {
                let location = start.location + (end.location - start.location) * sample
                let expected = ColorGradient.displayed(gradient.color(at: location))
                for renderer in ColorGradient.renderers {
                    let rendered = ColorGradient.rendered(from: start.color, to: end.color, by: sample, with: renderer)
                    maximum = max(maximum, ColorGradient.renderingError(expected, ColorGradient.displayed(rendered)))
                }
            }
        }
        return maximum
    }

    func testAdaptiveStopsStayWithinTolerance() {
        let red = RGBAColor(red: 1, green: 0, blue: 0)
        let clear = RGBAColor(red: 0, green: 0, blue: 1, alpha: 0)
        let pairs: [(RGBAColor, RGBAColor)] = [(blue, yellow), (black, white), (red, clear), (red, blue)]
        for space in ColorInterpolationSpace.allCases {
            for hue in HueInterpolation.allCases where space.isPolar || hue == .shorter {
                for (start, end) in pairs {
                    let gradient = ColorGradient(colors: [start, end], in: space, hue: hue)
                    for tolerance in [0.02, ColorGradient.defaultTolerance] {
                        let stops = gradient.toRenderingStops(tolerance: tolerance)
                        // Checked at three points per split, so allow a little over
                        XCTAssertLessThanOrEqual(maximumError(of: stops, against: gradient), tolerance * 1.5, "\(space) \(hue) \(start) \(end) \(tolerance)")
                        XCTAssertLessThanOrEqual(stops.count, 257 + 1)
                        XCTAssertEqual(stops.first, gradient.stops.first)
                        XCTAssertEqual(stops.last, gradient.stops.last)
                        XCTAssertEqual(stops.map(\.location), stops.map(\.location).sorted())
                    }
                }
            }
        }
    }

    func testAdaptiveStopsAreAddedOnlyWhereNeeded() {
        // Similar colors need no stops, however they're blended
        XCTAssertEqual(ColorGradient(colors: [blue, RGBAColor(red: 0, green: 0.02, blue: 1)]).toRenderingStops().count, 2)
        // A fade to transparent needs stops, since some renderers don't premultiply
        let fade = ColorGradient(colors: [blue, RGBAColor(red: 1, green: 0, blue: 0, alpha: 0)], in: .sRGB)
        XCTAssertGreaterThan(fade.toRenderingStops().count, 2)

        // Sweeping through every hue needs more stops than the short way around
        let short = ColorGradient(colors: [blue, yellow], in: .oklch).toRenderingStops().count
        let long = ColorGradient(colors: [blue, yellow], in: .oklch, hue: .longer).toRenderingStops().count
        XCTAssertGreaterThan(long, short)
        // A looser tolerance needs fewer stops
        let gradient = ColorGradient(colors: [blue, yellow])
        XCTAssertLessThan(gradient.toRenderingStops(tolerance: 0.02).count, gradient.toRenderingStops().count)
        // A typical gradient needs a modest number of stops
        XCTAssertLessThanOrEqual(gradient.toRenderingStops().count, 33)

        // Hard edges are kept, without stops between coincident stops
        let hard = ColorGradient(stops: [
            .init(color: blue, location: 0), .init(color: blue, location: 0.5),
            .init(color: yellow, location: 0.5), .init(color: yellow, location: 1),
        ])
        XCTAssertEqual(hard.toRenderingStops().map(\.location), [0, 0.5, 0.5, 1])
        XCTAssertEqual(ColorGradient(colors: [blue]).toRenderingStops().count, 1)
        XCTAssertEqual(ColorGradient(colors: [RGBAColor]()).toRenderingStops().count, 0)
    }

    func testCoreGraphicsStops() throws {
        let gradient = ColorGradient(colors: [blue, yellow], in: .oklch)
        let stops = gradient.toRenderingStops()
        let (colors, locations) = gradient.toCGColorsAndLocations()
        XCTAssertEqual(colors.count, stops.count)
        XCTAssertEqual(locations, stops.map { CGFloat($0.location) })
        for (color, stop) in zip(colors, stops) {
            assertEqual(try XCTUnwrap(color.toRGBAColor()), stop.color, accuracy: 1e-12)
        }
        XCTAssertNotNil(gradient.toCGGradient())
        XCTAssertNil(ColorGradient(colors: [RGBAColor]()).toCGGradient())
        XCTAssertEqual(gradient.toGradient().stops.count, stops.count)
    }

    /// Draws into an 8-bit sRGB bitmap, and returns the color of each column.
    private func renderColumns(width: Int, draw: (CGContext) -> Void) throws -> [RGBAColor] {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: 1, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        draw(context)
        let pixels = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: width * 4)
        return (0..<width).map { x in
            let alpha = Double(pixels[x * 4 + 3]) / 255
            func component(_ offset: Int) -> Double {
                alpha > 0 ? Double(pixels[x * 4 + offset]) / 255 / alpha : 0
            }
            return RGBAColor(red: component(0), green: component(1), blue: component(2), alpha: alpha)
        }
    }

    func testCoreGraphicsInterpolatesLikeTheModel() throws {
        // A black to white sRGB gradient has its sRGB midpoint, gray 0.5, while linear
        // light would be much lighter.
        let gradient = ColorGradient(colors: [black, white], in: .sRGB)
        let width = 101
        let columns = try renderColumns(width: width) { context in
            context.drawLinearGradient(
                try! XCTUnwrap(gradient.toCGGradient()),
                start: CGPoint(x: 0.5, y: 0),
                end: CGPoint(x: CGFloat(width) - 0.5, y: 0),
                options: []
            )
        }
        XCTAssertEqual(columns[50].red, 0.5, accuracy: 2.0 / 255)

        // A perceptual gradient drawn from its stops matches the gradient
        let perceptual = ColorGradient(colors: [blue, yellow], in: .oklch)
        let drawn = try renderColumns(width: width) { context in
            context.drawLinearGradient(
                try! XCTUnwrap(perceptual.toCGGradient()),
                start: CGPoint(x: 0.5, y: 0),
                end: CGPoint(x: CGFloat(width) - 0.5, y: 0),
                options: []
            )
        }
        for x in stride(from: 0, to: width, by: 10) {
            // 8-bit rounding is up to about 0.005 in Oklab
            XCTAssertLessThan(drawn[x].distance(to: perceptual.color(at: Double(x) / Double(width - 1)).clamped()), 0.01, "\(x)")
        }
    }

    @MainActor
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    func testSwiftUIRendersLikeTheGradient() throws {
        // SwiftUI blends two stops darker than sRGB, so the added stops matter even
        // for an sRGB gradient
        let width = 101
        func render(_ gradient: Gradient) throws -> [RGBAColor] {
            let renderer = ImageRenderer(content: LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing)
                .frame(width: CGFloat(width), height: 1))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.cgImage)
            return try renderColumns(width: width) { $0.draw(image, in: CGRect(x: 0, y: 0, width: width, height: 1)) }
        }
        let twoStops = try render(Gradient(colors: [.black, .white]))
        XCTAssertLessThan(twoStops[50].red, 0.45)
        let gray = try render(ColorGradient(colors: [black, white], in: .sRGB).toGradient())
        XCTAssertEqual(gray[50].red, 0.5, accuracy: 3.0 / 255)

        let gradient = ColorGradient(colors: [blue, yellow], in: .oklch)
        let drawn = try render(gradient.toGradient())
        for x in stride(from: 0, to: width, by: 10) {
            XCTAssertLessThan(drawn[x].distance(to: gradient.color(at: Double(x) / Double(width - 1)).clamped()), 0.01, "\(x)")
        }
    }

    #if canImport(QuartzCore) && !os(watchOS)
    func testCAGradientLayer() throws {
        let gradient = ColorGradient(colors: [blue, yellow], in: .oklch)
        let layer = CAGradientLayer()
        layer.setGradient(gradient)
        let (colors, locations) = gradient.toCGColorsAndLocations()
        XCTAssertEqual((layer.colors as? [CGColor])?.count, colors.count)
        XCTAssertEqual(layer.locations?.map(\.doubleValue), locations.map(Double.init))

        // One color fills the layer
        layer.setGradient(ColorGradient(colors: [blue]))
        XCTAssertEqual(layer.colors?.count, 2)
        XCTAssertEqual(layer.locations, [0, 1])

        // Core Animation blends lighter than sRGB, but with the added stops a black to
        // white sRGB gradient still has its sRGB midpoint
        let width = 101
        let rendered = CAGradientLayer()
        rendered.setGradient(ColorGradient(colors: [black, white], in: .sRGB))
        rendered.frame = CGRect(x: 0, y: 0, width: width, height: 1)
        rendered.startPoint = CGPoint(x: 0, y: 0.5)
        rendered.endPoint = CGPoint(x: 1, y: 0.5)
        let columns = try renderColumns(width: width) { rendered.render(in: $0) }
        XCTAssertEqual(columns[50].red, 0.5, accuracy: 3.0 / 255)

        let perceptual = CAGradientLayer()
        perceptual.setGradient(gradient)
        perceptual.frame = rendered.frame
        perceptual.startPoint = rendered.startPoint
        perceptual.endPoint = rendered.endPoint
        let drawn = try renderColumns(width: width) { perceptual.render(in: $0) }
        // Core Animation appears to sample gradients at a limited resolution: this one
        // changes fastest in its first 1/256, which it draws as one flat color, so the
        // first pixel is skipped
        for x in stride(from: 10, to: width, by: 10) {
            // Core Animation spans the layer from edge to edge, so pixel centers are
            // half a pixel in
            let location = (Double(x) + 0.5) / Double(width)
            XCTAssertLessThan(drawn[x].distance(to: gradient.color(at: location).clamped()), 0.01, "\(x)")
        }
    }
    #endif

    // MARK: Harmony

    func testHarmony() {
        let base = OKLCHColor(lightness: 0.7, chroma: 0.1, hue: .degrees(40))
        for harmony in ColorHarmony.allCases {
            let colors = base.harmony(harmony)
            XCTAssertEqual(colors.count, harmony.hueRotations.count)
            XCTAssertEqual(colors[0], base)
            for color in colors {
                XCTAssertEqual(color.lightness, 0.7, accuracy: 1e-9)
            }
        }
        XCTAssertEqual(base.harmony(.triadic).map { $0.hue.degrees.rounded() }, [40, 160, 280])
        XCTAssertEqual(base.complement().hue.degrees, 220, accuracy: 1e-9)
    }

    // MARK: Tonal Scale

    func testTonalScale() {
        let seed = HEXColor("#3B82F6")
        let scale = TonalScale(seed: seed, in: .sRGB)
        let colors = scale.colors
        XCTAssertEqual(colors.count, 11)
        for (lighter, darker) in zip(colors, colors.dropFirst()) {
            XCTAssertGreaterThan(lighter.lightness, darker.lightness)
        }
        for color in colors {
            XCTAssertTrue(ColorGamut.sRGB.contains(color))
            XCTAssertEqual(color.hue, seed.toOKLCHColor().hue)
        }
        XCTAssertGreaterThan(scale[50].lightness, 0.95)
        XCTAssertLessThan(scale[950].lightness, 0.3)
        // Chroma peaks in the middle
        XCTAssertGreaterThan(scale[500].chroma, scale[50].chroma)
        XCTAssertGreaterThan(scale[500].chroma, scale[950].chroma)
        XCTAssertEqual(scale.seedStep, 500)
        // Interpolated and clamped steps
        XCTAssertLessThan(scale[150].lightness, scale[100].lightness)
        XCTAssertGreaterThan(scale[150].lightness, scale[200].lightness)
        XCTAssertEqual(scale[-10].lightness, 1)
        XCTAssertEqual(scale.color(tone: 40).lightness, 0.4, accuracy: 1e-9)
    }

    // MARK: Generation

    func testCategorical() {
        let colors = OKLCHColor.categorical(count: 8, in: .sRGB)
        XCTAssertEqual(colors.count, 8)
        // Adding categories doesn't change the existing colors
        XCTAssertEqual(Array(OKLCHColor.categorical(count: 12, in: .sRGB).prefix(8)), colors)
        for (index, lhs) in colors.enumerated() {
            XCTAssertTrue(ColorGamut.sRGB.contains(lhs))
            for rhs in colors[(index + 1)...] {
                XCTAssertGreaterThan(lhs.distance(to: rhs), 0.05)
            }
        }
        XCTAssertTrue(OKLCHColor.categorical(count: 0).isEmpty)
    }

    func testHashingAndRandom() {
        XCTAssertEqual(OKLCHColor(hashing: "nathan"), OKLCHColor(hashing: "nathan"))
        XCTAssertNotEqual(OKLCHColor(hashing: "nathan"), OKLCHColor(hashing: "nathan2"))
        let hues = Set(["a", "b", "c", "d", "e", "f"].map { OKLCHColor(hashing: $0).hue })
        XCTAssertEqual(hues.count, 6)
        XCTAssertEqual(OKLCHColor(hashing: "x").lightness, 0.7)

        var lhs = SplitMix64(seed: 42)
        var rhs = SplitMix64(seed: 42)
        let a = OKLCHColor.random(lightness: 0.4...0.6, using: &lhs)
        let b = OKLCHColor.random(lightness: 0.4...0.6, using: &rhs)
        XCTAssertEqual(a, b)
        XCTAssertTrue((0.4...0.6).contains(a.lightness))
        XCTAssertTrue(ColorGamut.displayP3.contains(OKLCHColor.random()))
    }

    func testRGBAHashingAndRandom() {
        XCTAssertEqual(RGBAColor(hashing: "nathan"), OKLCHColor(hashing: "nathan").toRGBAColor())
        XCTAssertNotEqual(RGBAColor(hashing: "nathan"), RGBAColor(hashing: "nathan2"))
        XCTAssertTrue(ColorGamut.sRGB.contains(RGBAColor(hashing: "nathan")))

        var lhs = SplitMix64(seed: 42)
        var rhs = SplitMix64(seed: 42)
        let a = RGBAColor.random(red: 0.2...0.4, blue: 0.9...1, using: &lhs)
        let b = RGBAColor.random(red: 0.2...0.4, blue: 0.9...1, using: &rhs)
        XCTAssertEqual(a, b)
        XCTAssertTrue((0.2...0.4).contains(a.red))
        XCTAssertTrue((0...1).contains(a.green))
        XCTAssertTrue((0.9...1).contains(a.blue))
        XCTAssertEqual(a.alpha, 1)
        XCTAssertTrue(ColorGamut.sRGB.contains(RGBAColor.random()))
    }
}
