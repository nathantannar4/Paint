//
// Copyright (c) Nathan Tannar
//

import Foundation

/// A blend mode from the W3C [Compositing and Blending](https://www.w3.org/TR/compositing-1/)
/// spec, matching CSS `mix-blend-mode`, SwiftUI's `BlendMode` and Core Graphics.
///
/// Encodes as its case name, such as `"multiply"`.
@frozen
public enum ColorBlendMode: String, Hashable, Sendable, Codable, CaseIterable, CustomStringConvertible {
    /// The source color, composited over the backdrop.
    case normal
    /// Multiplies the colors, which always darkens.
    case multiply
    /// Inverts, multiplies and inverts the colors, which always lightens.
    case screen
    /// Multiplies dark backdrops and screens light ones, keeping the backdrop's highlights and shadows.
    case overlay
    /// The darker of the two colors, for each component.
    case darken
    /// The lighter of the two colors, for each component.
    case lighten
    /// Brightens the backdrop to reflect the source.
    case colorDodge
    /// Darkens the backdrop to reflect the source.
    case colorBurn
    /// Multiplies or screens, depending on the source, like a harsh spotlight.
    case hardLight
    /// Darkens or lightens, depending on the source, like a diffuse spotlight.
    case softLight
    /// The difference between the colors, for each component.
    case difference
    /// Like ``difference``, with lower contrast.
    case exclusion
    /// The hue of the source, with the saturation and luminosity of the backdrop.
    case hue
    /// The saturation of the source, with the hue and luminosity of the backdrop.
    case saturation
    /// The hue and saturation of the source, with the luminosity of the backdrop.
    case color
    /// The luminosity of the source, with the hue and saturation of the backdrop.
    case luminosity

    /// Blends opaque source and backdrop components, in `0...1`.
    func blend(source: SIMD3<Double>, backdrop: SIMD3<Double>) -> SIMD3<Double> {
        func separable(_ body: (Double, Double) -> Double) -> SIMD3<Double> {
            SIMD3(body(backdrop.x, source.x), body(backdrop.y, source.y), body(backdrop.z, source.z))
        }
        switch self {
        case .normal:
            return source
        case .multiply:
            return source * backdrop
        case .screen:
            return separable { cb, cs in cb.screened(with: cs) }
        case .overlay:
            return separable { cb, cs in cs.hardLit(by: cb) }
        case .darken:
            return separable { min($0, $1) }
        case .lighten:
            return separable { max($0, $1) }
        case .colorDodge:
            return separable { cb, cs in
                if cb == 0 { return 0 }
                if cs >= 1 { return 1 }
                return min(1, cb / (1 - cs))
            }
        case .colorBurn:
            return separable { cb, cs in
                if cb >= 1 { return 1 }
                if cs <= 0 { return 0 }
                return 1 - min(1, (1 - cb) / cs)
            }
        case .hardLight:
            return separable { cb, cs in cb.hardLit(by: cs) }
        case .softLight:
            return separable { cb, cs in
                if cs <= 0.5 {
                    return cb - (1 - 2 * cs) * cb * (1 - cb)
                }
                let d = cb <= 0.25 ? ((16 * cb - 12) * cb + 4) * cb : cb.squareRoot()
                return cb + (2 * cs - 1) * (d - cb)
            }
        case .difference:
            return separable { abs($0 - $1) }
        case .exclusion:
            return separable { cb, cs in cb + cs - 2 * cb * cs }
        case .hue:
            return source
                .withBlendSaturation(backdrop.blendSaturation)
                .withBlendLuminosity(backdrop.blendLuminosity)
        case .saturation:
            return backdrop
                .withBlendSaturation(source.blendSaturation)
                .withBlendLuminosity(backdrop.blendLuminosity)
        case .color:
            return source.withBlendLuminosity(backdrop.blendLuminosity)
        case .luminosity:
            return backdrop.withBlendLuminosity(source.blendLuminosity)
        }
    }

    /// The raw value, such as `"colorDodge"`.
    public var description: String {
        rawValue
    }
}

extension Double {

    /// `Screen(Cb, Cs)`
    fileprivate func screened(with cs: Double) -> Double {
        self + cs - self * cs
    }

    /// `HardLight(Cb, Cs)`
    fileprivate func hardLit(by cs: Double) -> Double {
        cs <= 0.5 ? self * 2 * cs : screened(with: 2 * cs - 1)
    }
}

extension SIMD3 where Scalar == Double {

    /// `Lum(C)`
    fileprivate var blendLuminosity: Double {
        0.3 * x + 0.59 * y + 0.11 * z
    }

    /// `Sat(C)`
    fileprivate var blendSaturation: Double {
        max() - min()
    }

    /// `SetLum(C, l)`
    fileprivate func withBlendLuminosity(_ l: Double) -> SIMD3<Double> {
        (self + (l - blendLuminosity)).clippedToBlendGamut()
    }

    /// `SetSat(C, s)`
    fileprivate func withBlendSaturation(_ s: Double) -> SIMD3<Double> {
        let maximum = max()
        let minimum = min()
        guard maximum > minimum else { return .zero }
        return (self - minimum) * s / (maximum - minimum)
    }

    /// `ClipColor(C)`
    fileprivate func clippedToBlendGamut() -> SIMD3<Double> {
        let l = blendLuminosity
        let n = min()
        let x = max()
        var c = self
        if n < 0 {
            c = SIMD3(repeating: l) + (c - l) * l / (l - n)
        }
        if x > 1 {
            c = SIMD3(repeating: l) + (c - l) * (1 - l) / (x - l)
        }
        return c
    }
}

extension ColorConvertible {

    /// The color composited over a backdrop with source-over, as when drawing a
    /// translucent color on top of another.
    ///
    /// Components are composited in gamma encoded sRGB, as browsers, SwiftUI and
    /// Core Graphics do. The result is opaque when the backdrop is.
    public func composited<
        Backdrop: ColorConvertible
    >(
        over backdrop: Backdrop
    ) -> RGBAColor {
        blended(over: backdrop, mode: .normal)
    }

    /// The color blended with a backdrop using a blend mode, then composited over it,
    /// as when drawing the color on top of the backdrop with the blend mode.
    ///
    /// Follows the W3C Compositing and Blending spec in gamma encoded sRGB, as
    /// browsers, SwiftUI and Core Graphics do. Components are clamped to sRGB first,
    /// since the blend formulas are defined for `0...1`.
    public func blended<
        Backdrop: ColorConvertible
    >(
        over backdrop: Backdrop,
        mode: ColorBlendMode
    ) -> RGBAColor {
        let source = toRGBAColor().toColorGamut(.sRGB).clamped()
        let backdrop = backdrop.toRGBAColor().toColorGamut(.sRGB).clamped()
        let alphaS = source.alpha
        let alphaB = backdrop.alpha
        let alpha = alphaS + alphaB * (1 - alphaS)
        guard alpha > 0 else {
            return RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
        // Where the backdrop is translucent, part of the source shows unblended
        let blended = mode.blend(source: source.components, backdrop: backdrop.components)
        let mixedSource = source.components * (1 - alphaB) + blended * alphaB
        let premultiplied = mixedSource * alphaS + backdrop.components * alphaB * (1 - alphaS)
        return RGBAColor(components: premultiplied / alpha, alpha: alpha)
    }
}
