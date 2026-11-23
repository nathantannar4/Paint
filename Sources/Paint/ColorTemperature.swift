//
// Copyright (c) Nathan Tannar
//

import Foundation
import simd

extension RGBAColor {

    /// The color of a black body radiator at a temperature in kelvin, such as `2700`
    /// for warm incandescent light or `6500` for daylight.
    ///
    /// The chromaticity follows the Planckian locus, using the approximation of
    /// Kim et al. (2002), which covers `1667...25000`. Temperatures outside that range
    /// are clamped. The color is scaled so that its brightest component is `1`, and
    /// clamped to sRGB, so very warm colors are the most saturated orange sRGB can show.
    public init(kelvin: Double, alpha: Double = 1) {
        let t = kelvin.isNaN ? 6500 : min(max(kelvin, 1667), 25000)
        let t2 = t * t
        let t3 = t2 * t
        let x: Double = t <= 4000
            ? -0.2661239e9 / t3 - 0.2343589e6 / t2 + 0.8776956e3 / t + 0.179910
            : -3.0258469e9 / t3 + 2.1070379e6 / t2 + 0.2226347e3 / t + 0.240390
        let x2 = x * x
        let x3 = x2 * x
        let y: Double
        if t <= 2222 {
            y = -1.1063814 * x3 - 1.34811020 * x2 + 2.18555832 * x - 0.20219683
        } else if t <= 4000 {
            y = -0.9549476 * x3 - 1.37418593 * x2 + 2.09137015 * x - 0.16748867
        } else {
            y = 3.0817580 * x3 - 5.87338670 * x2 + 3.75112997 * x - 0.37001483
        }
        let xyz = SIMD3(x / y, 1, (1 - x - y) / y)
        var linear = ColorSpaceMatrix.xyzD65ToLinearSRGB * xyz
        linear = linear.replacing(with: 0, where: linear .< 0)
        let maximum = linear.max()
        if maximum > 0 {
            linear /= maximum
        }
        self.init(linear: linear, alpha: alpha)
    }
}

extension ColorConvertible {

    /// The correlated color temperature (CCT) of the color in kelvin, estimated from
    /// its chromaticity with McCamy's formula, or `nil` for black and chromaticities
    /// where the formula is undefined.
    ///
    /// sRGB white is about `6504`, warmer colors are lower and cooler colors are
    /// higher. The estimate is accurate for near-white colors close to the Planckian
    /// locus, from about `2000` to `12500`; for saturated colors it describes a
    /// tendency towards warm or cool rather than a meaningful temperature.
    public func toCorrelatedColorTemperature() -> Double? {
        guard let chromaticity = toXYZColor().toChromaticity() else { return nil }
        // The formula divides by zero at McCamy's epicenter, y = 0.1858
        let denominator = 0.1858 - chromaticity.y
        guard abs(denominator) > 1e-9 else { return nil }
        let n = (chromaticity.x - 0.3320) / denominator
        let temperature = 449 * n * n * n + 3525 * n * n + 6823.3 * n + 5520.33
        return temperature.isFinite ? temperature : nil
    }

    /// The correlated color temperature in whole kelvin, like `"6505 K"` for sRGB
    /// white, with the alpha when translucent, like `"6505 K / 0.5"`.
    ///
    /// Returns `nil` when ``toCorrelatedColorTemperature()`` does, such as for black.
    public func toCorrelatedColorTemperatureString() -> String? {
        guard let kelvin = toCorrelatedColorTemperature() else { return nil }
        return ColorStringFormatter.temperature(kelvin, alpha: toRGBAColor().alpha)
    }
}
