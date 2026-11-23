//
// Copyright (c) Nathan Tannar
//

import Foundation

extension UInt8 {

    /// `CharacterSet.whitespaces` for ASCII: spaces and tabs.
    @usableFromInline
    var isSpaceOrTab: Bool {
        self == 0x20 || self == 0x09
    }

    /// The whitespace that separates values: spaces, tabs and line feeds.
    @usableFromInline
    var isSeparator: Bool {
        isSpaceOrTab || self == 0x0A
    }

    /// `CharacterSet.whitespacesAndNewlines` for ASCII: spaces and `\t` through `\r`.
    @usableFromInline
    var isWhitespaceOrNewline: Bool {
        self == 0x20 || (0x09...0x0D).contains(self)
    }

    /// An ASCII digit, `0` through `9`.
    @usableFromInline
    var isDigit: Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(self)
    }

    /// An ASCII uppercase letter, `A` through `Z`.
    @usableFromInline
    var isUppercase: Bool {
        (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(self)
    }

    /// An ASCII letter, either case.
    @usableFromInline
    var isLetter: Bool {
        (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(self | 0x20)
    }

    /// The ASCII lowercase form of an uppercase letter, otherwise the byte unchanged.
    @usableFromInline
    func lowercased() -> UInt8 {
        isUppercase ? self | 0x20 : self
    }

    /// The value of an ASCII hex digit, case insensitive, or `nil` if it isn't one.
    @usableFromInline
    func toHexDigitValue() -> UInt32? {
        if isDigit {
            return UInt32(self &- UInt8(ascii: "0"))
        }
        let lowercased = lowercased()
        if (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(lowercased) {
            return UInt32(lowercased &- UInt8(ascii: "a") &+ 10)
        }
        return nil
    }
}
