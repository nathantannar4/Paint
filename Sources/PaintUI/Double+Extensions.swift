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
}
