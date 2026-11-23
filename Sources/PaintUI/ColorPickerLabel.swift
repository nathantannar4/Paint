//
// Copyright (c) Nathan Tannar
//

#if os(iOS) || os(visionOS)
import UIKit

import Paint

/// A badge of a color inside a spectrum ring, like the well of SwiftUI's
/// `ColorPicker` and `UIColorWell`.
///
/// It only shows the color. To pick one, put it in a button that presents a
/// ``ColorPickerViewController``, and set ``selectedColor`` from the picker's
/// delegate:
///
/// ```swift
/// let label = ColorPickerLabel(color: HEXColor("#0A84FF"))
/// label.isUserInteractionEnabled = false
/// button.addSubview(label)
/// ```
///
/// Translucent colors are drawn over a checkerboard. Without a color, the ring is
/// drawn around an empty center.
open class ColorPickerLabel: UIView {

    /// The color in the center, or `nil` for none.
    public var selectedColor: RGBAColor? {
        didSet {
            guard selectedColor != oldValue else { return }
            updateColor()
        }
    }

    /// The width of the spectrum ring, or `nil` to scale it with the size of the
    /// label, as `UIColorWell` does.
    public var ringWidth: CGFloat? {
        didSet { setNeedsLayout() }
    }

    private let ringLayer = CAGradientLayer()
    private let ringMask = CAShapeLayer()
    private let checkerboardLayer = CALayer()
    private let fillLayer = CALayer()

    /// Creates a label with a color.
    public init<C: ColorConvertible>(color: C?) {
        self.selectedColor = color?.toRGBAColor()
        super.init(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
        setUp()
    }

    /// Creates a label without a color.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        // Fully saturated sRGB hues around the ring, like the system color well:
        // yellow at the top, turning clockwise through red, magenta and blue to green
        let angles = stride(from: 0.0, through: 360, by: 30)
        ringLayer.type = .conic
        ringLayer.colors = angles.map { angle in
            HSBAColor(hue: .degrees(60 - angle), saturation: 1, brightness: 1).toCGColor()
        }
        ringLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        ringLayer.endPoint = CGPoint(x: 0.5, y: 0)
        ringMask.fillColor = nil
        ringMask.strokeColor = UIColor.black.cgColor
        ringLayer.mask = ringMask
        layer.addSublayer(ringLayer)

        checkerboardLayer.backgroundColor = ColorPickerImage.checkerboard.cgColor
        checkerboardLayer.masksToBounds = true
        layer.addSublayer(checkerboardLayer)
        fillLayer.masksToBounds = true
        layer.addSublayer(fillLayer)

        isAccessibilityElement = true
        accessibilityTraits = .image
        accessibilityLabel = "Color"
        updateColor()
    }

    open override var intrinsicContentSize: CGSize {
        CGSize(width: 28, height: 28)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        let diameter = min(bounds.width, bounds.height)
        let square = CGRect(
            x: bounds.midX - diameter / 2,
            y: bounds.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
        let ringWidth = self.ringWidth ?? max(2, (diameter * 0.1).rounded())
        let gap = max(1.5, (diameter * 0.07).rounded())

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.frame = square
        ringMask.frame = ringLayer.bounds
        ringMask.lineWidth = ringWidth
        ringMask.path = UIBezierPath(ovalIn: ringLayer.bounds.insetBy(dx: ringWidth / 2, dy: ringWidth / 2)).cgPath

        let inner = square.insetBy(dx: ringWidth + gap, dy: ringWidth + gap)
        for layer in [checkerboardLayer, fillLayer] {
            layer.frame = inner
            layer.cornerRadius = inner.width / 2
        }
        CATransaction.commit()
    }

    private func updateColor() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let selectedColor {
            fillLayer.backgroundColor = selectedColor.toCGColor()
            checkerboardLayer.isHidden = selectedColor.alpha >= 1
            fillLayer.isHidden = false
            accessibilityValue = selectedColor.toHEXColor().description
        } else {
            fillLayer.isHidden = true
            checkerboardLayer.isHidden = true
            accessibilityValue = "None"
        }
        CATransaction.commit()
    }
}
#endif
