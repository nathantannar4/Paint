//
// Copyright (c) Nathan Tannar
//

import Foundation

extension ColorConvertible {

    /// The perceptual difference between two colors: the Euclidean distance in Oklab
    /// (ΔE OK), as used by CSS Color 4 gamut mapping.
    ///
    /// `0` for identical colors. About `0.02` is the smallest difference most people
    /// notice, and black to white is `1`. Alpha is ignored.
    public func distance<
        Other: ColorConvertible
    >(
        to other: Other
    ) -> Double {
        let lhs = toOKLabColor()
        let rhs = other.toOKLabColor()
        let lightness = lhs.lightness - rhs.lightness
        let a = lhs.a - rhs.a
        let b = lhs.b - rhs.b
        return (lightness * lightness + a * a + b * b).squareRoot()
    }

    /// The CIEDE2000 color difference (ΔE00) between two colors, in CIE Lab.
    ///
    /// About `1` is the smallest difference most people notice, and `2` to `3` is
    /// noticeable at a glance. ΔE00 is the standard in print and textile industries.
    /// For most UI work, ``distance(to:)`` is cheaper and as accurate. Alpha is ignored.
    public func deltaE2000<
        Other: ColorConvertible
    >(
        to other: Other
    ) -> Double {
        CIELabColor.deltaE2000(toCIELabColor(), other.toCIELabColor())
    }

    /// Whether two colors look the same: their ``distance(to:)`` is at most
    /// `tolerance`, and their alphas differ by at most `alphaTolerance`.
    ///
    /// The default tolerance of `0.02` is about the smallest difference most people
    /// notice, and the default alpha tolerance is about one 8-bit step.
    public func isApproximatelyEqual<
        Other: ColorConvertible
    >(
        to other: Other,
        tolerance: Double = 0.02,
        alphaTolerance: Double = 0.004
    ) -> Bool {
        distance(to: other) <= tolerance
            && abs(toRGBAColor().alpha - other.toRGBAColor().alpha) <= alphaTolerance
    }
}

extension CIELabColor {

    /// The CIEDE2000 color difference (ΔE00) between two CIE Lab colors, with the
    /// parametric factors `kL`, `kC` and `kH` of `1`.
    ///
    /// Implements [Sharma, Wu and Dalal (2005)](https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/).
    public static func deltaE2000(_ lhs: CIELabColor, _ rhs: CIELabColor) -> Double {
        let degrees = 180 / Double.pi
        let radians = Double.pi / 180

        let c1 = (lhs.a * lhs.a + lhs.b * lhs.b).squareRoot()
        let c2 = (rhs.a * rhs.a + rhs.b * rhs.b).squareRoot()
        let meanC = (c1 + c2) / 2
        let meanC7 = pow(meanC, 7)
        let g = 0.5 * (1 - (meanC7 / (meanC7 + pow(25, 7))).squareRoot())

        let a1 = (1 + g) * lhs.a
        let a2 = (1 + g) * rhs.a
        let c1Prime = (a1 * a1 + lhs.b * lhs.b).squareRoot()
        let c2Prime = (a2 * a2 + rhs.b * rhs.b).squareRoot()

        func hue(_ b: Double, _ a: Double) -> Double {
            guard a != 0 || b != 0 else { return 0 }
            let h = atan2(b, a) * degrees
            return h < 0 ? h + 360 : h
        }
        let h1 = hue(lhs.b, a1)
        let h2 = hue(rhs.b, a2)

        let deltaL = rhs.lightness - lhs.lightness
        let deltaC = c2Prime - c1Prime
        var deltaH: Double
        if c1Prime * c2Prime == 0 {
            deltaH = 0
        } else {
            deltaH = h2 - h1
            if deltaH > 180 {
                deltaH -= 360
            } else if deltaH < -180 {
                deltaH += 360
            }
        }
        let deltaHPrime = 2 * (c1Prime * c2Prime).squareRoot() * sin(deltaH / 2 * radians)

        let meanL = (lhs.lightness + rhs.lightness) / 2
        let meanCPrime = (c1Prime + c2Prime) / 2
        var meanH: Double
        if c1Prime * c2Prime == 0 {
            meanH = h1 + h2
        } else if abs(h1 - h2) <= 180 {
            meanH = (h1 + h2) / 2
        } else if h1 + h2 < 360 {
            meanH = (h1 + h2 + 360) / 2
        } else {
            meanH = (h1 + h2 - 360) / 2
        }

        let t = 1
            - 0.17 * cos((meanH - 30) * radians)
            + 0.24 * cos(2 * meanH * radians)
            + 0.32 * cos((3 * meanH + 6) * radians)
            - 0.20 * cos((4 * meanH - 63) * radians)
        let deltaTheta = 30 * exp(-pow((meanH - 275) / 25, 2))
        let meanCPrime7 = pow(meanCPrime, 7)
        let rC = 2 * (meanCPrime7 / (meanCPrime7 + pow(25, 7))).squareRoot()
        let meanL50 = (meanL - 50) * (meanL - 50)
        let sL = 1 + 0.015 * meanL50 / (20 + meanL50).squareRoot()
        let sC = 1 + 0.045 * meanCPrime
        let sH = 1 + 0.015 * meanCPrime * t
        let rT = -sin(2 * deltaTheta * radians) * rC

        let l = deltaL / sL
        let c = deltaC / sC
        let h = deltaHPrime / sH
        return (l * l + c * c + h * h + rT * c * h).squareRoot()
    }
}

extension Sequence where Element: ColorConvertible {

    /// The element closest to `color` by ``ColorConvertible/distance(to:)``,
    /// or `nil` if the sequence is empty. Ties keep the first element.
    public func nearest<
        C: ColorConvertible
    >(
        to color: C
    ) -> Element? {
        let target = color.toOKLabColor()
        var best: (element: Element, distance: Double)?
        for element in self {
            let distance = element.distance(to: target)
            if best == nil || distance < best!.distance {
                best = (element, distance)
            }
        }
        return best?.element
    }

    /// The elements with near duplicates removed, keeping the first of each group
    /// of colors within `threshold` of each other by ``ColorConvertible/distance(to:)``.
    public func removingNearDuplicates(threshold: Double = 0.02) -> [Element] {
        var kept: [(element: Element, oklab: OKLabColor)] = []
        for element in self {
            let oklab = element.toOKLabColor()
            if kept.allSatisfy({ $0.oklab.distance(to: oklab) > threshold }) {
                kept.append((element, oklab))
            }
        }
        return kept.map { $0.element }
    }
}
