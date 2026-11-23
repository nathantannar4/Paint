//
// Copyright (c) Nathan Tannar
//

import Foundation

extension Double {

    /// Clamps to a range.
    @usableFromInline
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }

    /// Multiplies an alpha by an opacity clamped to `0...1`.
    @usableFromInline
    func opacity(_ opacity: Double) -> Double {
        (self * opacity).clamped(to: 0...1)
    }
}
