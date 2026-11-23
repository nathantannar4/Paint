//
// Copyright (c) Nathan Tannar
//

#if os(iOS) || os(visionOS)
import UIKit

import Paint

/// A popover with a slider along the ``TonalScale`` of a color, from white at `0` to
/// black at `1000`, and the standard steps from `50` to `950` below it.
///
/// ``ColorPickerViewController`` shows it when the selected color of its
/// ``ColorPickerSelectionPreviewView`` is tapped. The scale is generated from the
/// color the popover opened with, so dragging back and forth keeps its hue and chroma.
@available(iOS 14.0, macCatalyst 14.0, *)
final class ColorPickerToneViewController: UIViewController, UIPopoverPresentationControllerDelegate, ColorValueFieldToolbarProviding {

    /// Called with the new color, and whether it's still changing.
    var onChange: ((RGBAColor, Bool) -> Void)?

    /// The toolbar above the keyboard, shared with the picker that presents it,
    /// which isn't along its responder chain when presented from a container.
    let valueFieldToolbar: ColorValueFieldToolbar

    private let scale: TonalScale
    private let alpha: Double
    private let stack = UIStackView()
    private let stepRow = ColorSliderRow(
        title: "Tonal Scale",
        range: 0...1000,
        format: { "\(Int($0.rounded()))" },
        parse: ColorSliderRow.parseNumber
    )
    private var stepButtons: [(step: Int, button: UIButton)] = []

    /// Creates a popover for the tonal scale of a color, fitted to a gamut.
    init(color: RGBAColor, gamut: ColorGamut, valueFieldToolbar: ColorValueFieldToolbar) {
        self.valueFieldToolbar = valueFieldToolbar
        self.scale = TonalScale(seed: color, in: gamut)
        self.alpha = color.alpha
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .popover
        popoverPresentationController?.delegate = self
        stepRow.value = Self.step(of: color.toOKLCHColor(), in: scale)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.preservesSuperviewLayoutMargins = true
        view.addSubview(stack)
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        let margins = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: margins.topAnchor),
            stack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
        ])

        // The slider, along the whole scale
        let scale = scale
        stepRow.slider.accessibilityStep = 50.0 / 1000
        stepRow.slider.setTrack { t in
            scale.color(at: t * 1000).toRGBAColor()
        }
        stepRow.onChange = { [weak self] _, continuously in
            self?.update(sending: continuously)
        }
        stack.addArrangedSubview(stepRow)

        // The standard steps, as swatches that select them
        let steps = UIStackView()
        steps.axis = .horizontal
        steps.distribution = .fillEqually
        steps.spacing = 4
        for step in TonalScale.steps {
            let button = UIButton(type: .custom)
            button.backgroundColor = scale[step].toRGBAColor().toUIColor()
            button.layer.cornerRadius = 6
            button.layer.cornerCurve = .continuous
            button.accessibilityLabel = "Step \(step)"
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            button.addAction(UIAction { [weak self] _ in
                self?.select(step)
            }, for: .primaryActionTriggered)
            steps.addArrangedSubview(button)
            stepButtons.append((step, button))
        }
        stack.addArrangedSubview(steps)

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) { (self: Self, _) in
                self.updateSelection()
            }
        }

        update(sending: nil)

        view.layoutIfNeeded()
        preferredContentSize = view.systemLayoutSizeFitting(
            CGSize(width: 300, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
    }

    #if !os(visionOS)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Before iOS 17, which observes trait changes with `registerForTraitChanges`
        if #unavailable(iOS 17.0) {
            updateSelection()
        }
    }
    #endif

    // MARK: Updates

    /// The color at the slider's step, with the alpha of the original color.
    private var color: RGBAColor {
        var color = scale.color(at: stepRow.value).toRGBAColor()
        color.alpha = alpha
        return color
    }

    private func select(_ step: Int) {
        stepRow.value = Double(step)
        update(sending: false)
    }

    /// Updates the thumb and the selected step, and calls ``onChange`` unless
    /// `continuously` is `nil`.
    private func update(sending continuously: Bool?) {
        var opaque = color
        opaque.alpha = 1
        stepRow.slider.thumbColor = opaque
        updateSelection()
        if let continuously {
            onChange?(color, continuously)
        }
    }

    /// Outlines the standard step the slider is on, if it's on one.
    private func updateSelection() {
        let current = Int(stepRow.value.rounded())
        let borderColor = UIColor.label.resolvedColor(with: traitCollection).cgColor
        for (step, button) in stepButtons {
            let isSelected = step == current
            button.layer.borderWidth = isSelected ? 2 : 1 / max(traitCollection.displayScale, 1)
            button.layer.borderColor = isSelected ? borderColor : UIColor.separator.resolvedColor(with: traitCollection).cgColor
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    /// The step of the scale with the lightness of a color.
    ///
    /// Lightness falls from `1` at step `0` to `0` at step `1000`, so it's found by
    /// bisection.
    private static func step(of color: OKLCHColor, in scale: TonalScale) -> Double {
        var lower = 0.0
        var upper = 1000.0
        for _ in 0..<24 {
            let middle = (lower + upper) / 2
            if scale.color(at: middle).lightness > color.lightness {
                lower = middle
            } else {
                upper = middle
            }
        }
        return (lower + upper) / 2
    }

    // MARK: UIPopoverPresentationControllerDelegate

    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        // A popover on iPhone too, rather than a sheet
        .none
    }
}
#endif
