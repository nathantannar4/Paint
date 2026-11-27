//
// Copyright (c) Nathan Tannar
//

import Foundation

/// An order for sorting colors perceptually, such as for a grid of swatches, see
/// ``Swift/Sequence/sorted(by:)``.
///
/// Every order uses OKLCH, so colors that look alike end up next to each other.
public struct ColorSortOrder: Hashable, Sendable {

    enum Kind: Hashable, Sendable {
        case hue(start: ColorHue)
        case lightness
        case chroma
        case stepped(segments: Int, start: ColorHue)
    }

    var kind: Kind

    /// Around the color wheel from red, then from light to dark within a hue. Grays,
    /// which have no hue, come last, from light to dark.
    public static var hue: ColorSortOrder {
        .hue(startingAt: .degrees(0))
    }

    /// Around the color wheel from a starting hue, then from light to dark within a
    /// hue. Grays, which have no hue, come last, from light to dark.
    public static func hue(startingAt start: ColorHue) -> ColorSortOrder {
        ColorSortOrder(kind: .hue(start: start))
    }

    /// From light to dark, by OKLCH lightness.
    public static var lightness: ColorSortOrder {
        ColorSortOrder(kind: .lightness)
    }

    /// From most to least colorful, by OKLCH chroma.
    public static var chroma: ColorSortOrder {
        ColorSortOrder(kind: .chroma)
    }

    /// Grouped into `8` slices of the color wheel from red, see
    /// ``stepped(segments:startingAt:)``.
    public static var stepped: ColorSortOrder {
        .stepped(segments: 8)
    }

    /// Grouped into `segments` slices of the color wheel, from a starting hue, then
    /// from light to dark within each slice, alternating direction between slices.
    ///
    /// Sorting by hue alone puts dark and light colors of almost the same hue next to
    /// each other, which looks noisy. Slicing the wheel, and snaking through the
    /// lightness of each slice, gives smooth runs of color, the way designers arrange
    /// palettes. Grays come last, from light to dark.
    public static func stepped(segments: Int, startingAt start: ColorHue = .degrees(0)) -> ColorSortOrder {
        ColorSortOrder(kind: .stepped(segments: max(segments, 1), start: start))
    }

    /// The chroma below which a color is treated as a gray, with no hue.
    static let grayChroma = 0.02
}

extension Sequence where Element: ColorConvertible {

    /// The colors sorted in a perceptual order, such as by hue for a grid of
    /// swatches.
    ///
    /// The sort is stable, so colors that compare equal keep their order. Alpha is
    /// ignored.
    ///
    /// ```swift
    /// let swatches = palette.sorted(by: .stepped)
    /// ```
    public func sorted(by order: ColorSortOrder) -> [Element] {
        let keyed = enumerated().map { (offset: $0.offset, element: $0.element, oklch: $0.element.toOKLCHColor()) }

        /// Compares keys in order, breaking the final tie by the original position.
        func isOrdered(_ lhs: (offset: Int, element: Element, oklch: OKLCHColor), _ rhs: (offset: Int, element: Element, oklch: OKLCHColor), keys: [(OKLCHColor) -> Double]) -> Bool {
            for key in keys {
                let l = key(lhs.oklch)
                let r = key(rhs.oklch)
                if l != r { return l < r }
            }
            return lhs.offset < rhs.offset
        }

        func isGray(_ color: OKLCHColor) -> Bool {
            color.chroma < ColorSortOrder.grayChroma
        }

        /// The hue in degrees from a start, in `0..<360`.
        func hue(_ color: OKLCHColor, from start: ColorHue) -> Double {
            var degrees = (color.hue.degrees - start.degrees).truncatingRemainder(dividingBy: 360)
            if degrees < 0 { degrees += 360 }
            // Rounded to a hundredth of a degree, so colors of the same hue that differ
            // only by floating point error sort by lightness
            degrees = (degrees * 100).rounded() / 100
            return degrees >= 360 ? 0 : degrees
        }

        let keys: [(OKLCHColor) -> Double]
        switch order.kind {
        case .lightness:
            keys = [{ -$0.lightness }]
        case .chroma:
            keys = [{ -$0.chroma }]
        case .hue(let start):
            keys = [
                { isGray($0) ? 1 : 0 },
                { isGray($0) ? 0 : hue($0, from: start) },
                { -$0.lightness },
            ]
        case .stepped(let segments, let start):
            let width = 360 / Double(segments)
            func segment(_ color: OKLCHColor) -> Double {
                Swift.min(floor(hue(color, from: start) / width), Double(segments - 1))
            }
            keys = [
                { isGray($0) ? 1 : 0 },
                { isGray($0) ? 0 : segment($0) },
                // Alternate direction, so neighboring slices meet at a similar lightness
                { color in
                    if isGray(color) { return -color.lightness }
                    return Int(segment(color)) % 2 == 0 ? -color.lightness : color.lightness
                },
            ]
        }
        return keyed.sorted { isOrdered($0, $1, keys: keys) }.map { $0.element }
    }
}
