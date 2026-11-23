//
// Copyright (c) Nathan Tannar
//

#if os(iOS) || os(visionOS)
import UIKit

import Paint

/// A capsule that previews a color selection: the original color on the leading
/// half and the selected color on the trailing half, like the swatch of
/// `UIColorPickerViewController`.
///
/// ``ColorPickerViewController`` shows one as the title view of its navigation item.
/// Translucent colors are drawn over a checkerboard.
///
/// Tapping the original color sends `.primaryActionTriggered`, so it can be used
/// to revert the selection. Tapping the selected color performs
/// ``selectedColorAction``, if there is one:
///
/// ```swift
/// let preview = ColorPickerSelectionPreviewView()
/// preview.originalColor = HEXColor("#0A84FF").toRGBAColor()
/// preview.selectedColor = HEXColor("#FF9F0A").toRGBAColor()
/// preview.addAction(UIAction { _ in revert() }, for: .primaryActionTriggered)
/// preview.selectedColorAction = UIAction(title: "Adjust") { _ in adjust() }
/// ```
@available(iOS 14.0, macCatalyst 14.0, *)
open class ColorPickerSelectionPreviewView: UIControl {

    /// The color before the selection changed, on the leading half, or `nil` to
    /// show the selected color across the whole capsule.
    public var originalColor: RGBAColor? {
        didSet {
            guard originalColor != oldValue else { return }
            updateColors()
        }
    }

    /// The selected color, on the trailing half, or `nil` for none.
    public var selectedColor: RGBAColor? {
        didSet {
            guard selectedColor != oldValue else { return }
            updateColors()
        }
    }

    /// An action performed when the selected color is tapped, or `nil` for the
    /// selected color not to be tappable.
    ///
    /// Its title names the action for VoiceOver, as a custom action.
    /// ``ColorPickerViewController`` shows a slider along the tonal scale of the
    /// selected color.
    public var selectedColorAction: UIAction? {
        didSet { updateAccessibilityActions() }
    }

    /// The halves of the capsule that can be tapped.
    private enum Segment: CaseIterable {
        case original
        case selected
    }

    /// The half being tapped.
    private var trackedSegment: Segment?

    private let checkerboardLayer = CALayer()
    private let originalLayer = CALayer()
    private let selectedLayer = CALayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        clipsToBounds = true
        layer.borderWidth = 1 / max(traitCollection.displayScale, 1)
        updateBorderColor()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) { (self: Self, _) in
                self.updateBorderColor()
            }
        }
        checkerboardLayer.backgroundColor = ColorPickerImage.checkerboard.cgColor
        layer.addSublayer(checkerboardLayer)
        layer.addSublayer(originalLayer)
        layer.addSublayer(selectedLayer)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "Original and selected color"
        accessibilityHint = "Reverts to the original color"
        updateColors()
        updateAccessibilityActions()
    }

    /// The frame of the selected color, the trailing half, or the whole capsule when
    /// there's no original color.
    var selectedColorFrame: CGRect {
        halves.trailing
    }

    open override var intrinsicContentSize: CGSize {
        CGSize(width: 76, height: 38)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        checkerboardLayer.frame = bounds
        let (leading, trailing) = halves
        if originalColor == nil {
            originalLayer.frame = .zero
            selectedLayer.frame = bounds
        } else {
            originalLayer.frame = leading
            selectedLayer.frame = trailing
        }
        CATransaction.commit()
    }

    #if !os(visionOS)
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Before iOS 17, which observes trait changes with `registerForTraitChanges`
        if #unavailable(iOS 17.0) {
            updateBorderColor()
        }
    }
    #endif

    private func updateBorderColor() {
        // `UIColor.separator` is dynamic, but a `CGColor` isn't
        layer.borderColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
    }

    /// The leading and trailing halves, flipped for right-to-left layouts.
    private var halves: (leading: CGRect, trailing: CGRect) {
        let (left, right) = bounds.divided(atDistance: (bounds.width / 2).rounded(), from: .minXEdge)
        return effectiveUserInterfaceLayoutDirection == .rightToLeft ? (right, left) : (left, right)
    }

    private func updateColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        originalLayer.backgroundColor = originalColor?.toCGColor()
        selectedLayer.backgroundColor = selectedColor?.toCGColor()
        let isTranslucent = (originalColor?.alpha ?? 1) < 1 || (selectedColor?.alpha ?? 1) < 1
        checkerboardLayer.isHidden = !isTranslucent
        CATransaction.commit()
        setNeedsLayout()

        func describe(_ color: RGBAColor?) -> String {
            guard let color else { return "none" }
            return color.toHEXColor().description
        }
        accessibilityValue = "Original \(describe(originalColor)), selected \(describe(selectedColor))"
    }

    // MARK: Tracking

    open override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: isHighlighted ? 0 : 0.2) {
                self.alpha = self.isHighlighted ? 0.6 : 1
            }
        }
    }

    private func frame(of segment: Segment) -> CGRect {
        switch segment {
        case .original: halves.leading
        case .selected: selectedColorFrame
        }
    }

    private func isTappable(_ segment: Segment) -> Bool {
        switch segment {
        case .original: originalColor != nil
        case .selected: selectedColor != nil && selectedColorAction != nil
        }
    }

    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        trackedSegment = Segment.allCases.first { isTappable($0) && frame(of: $0).contains(location) }
        return trackedSegment != nil
    }

    open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        let segment = trackedSegment
        trackedSegment = nil
        guard
            let segment,
            let touch,
            isTappable(segment),
            frame(of: segment).insetBy(dx: -8, dy: -8).contains(touch.location(in: self))
        else {
            return
        }
        switch segment {
        case .original:
            sendActions(for: .primaryActionTriggered)
        case .selected:
            if let selectedColorAction {
                sendAction(selectedColorAction)
            }
        }
    }

    open override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        trackedSegment = nil
    }

    /// Offers ``selectedColorAction`` to VoiceOver as a custom action, since
    /// activating the control reverts to the original color.
    private func updateAccessibilityActions() {
        guard let action = selectedColorAction else {
            accessibilityCustomActions = nil
            return
        }
        let name = action.title.isEmpty ? "Adjust selected color" : action.title
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: name) { [weak self] _ in
                guard let self, self.isTappable(.selected), let action = self.selectedColorAction else { return false }
                self.sendAction(action)
                return true
            },
        ]
    }

    open override func accessibilityActivate() -> Bool {
        guard originalColor != nil else { return false }
        sendActions(for: .primaryActionTriggered)
        return true
    }
}
#endif
