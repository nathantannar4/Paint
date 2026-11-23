//
// Copyright (c) Nathan Tannar
//

import SwiftUI
import Paint
import PaintUI

#if os(iOS) || os(visionOS)
import UIKit

/// `ColorPickerViewController`, embedded and presented as a sheet, and
/// `ColorPickerLabel`, next to the system `ColorPicker` to compare against.
struct ColorPickerDemo: View {

    @State private var color = RGBAColor(red: 0, green: 0.478, blue: 1)
    @State private var isPresented = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Paint's `ColorPickerLabel`, in a button that presents the picker
                Button {
                    isPresented = true
                } label: {
                    ColorPickerLabelRepresentable(color: color)
                        .frame(width: 28, height: 28)
                }
                Text(color.toHEXColor().toString(includePrefix: true))
                    .font(.body.monospaced())
                Spacer()
                // The system picker, to compare against, sharing the same color.
                // Through `CGColor`, so wide gamut colors aren't clipped to sRGB
                ColorPicker(
                    "System",
                    selection: Binding(
                        get: { color.toCGColor() },
                        set: { color = $0.toRGBAColor() ?? color }
                    ),
                    supportsOpacity: true
                )
                .fixedSize()
                Button("Present") {
                    isPresented = true
                }
                .padding(.leading, 8)
            }
            .padding()
            ColorPickerRepresentable(color: $color)
        }
        .navigationTitle("Color Picker")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresented) {
            ColorPickerRepresentable(color: $color)
                .presentationDetents([.medium, .large])
                .presentationBackground(.clear)
                .ignoresSafeArea()
        }
    }
}

private struct ColorPickerLabelRepresentable: UIViewRepresentable {

    var color: RGBAColor

    func makeUIView(context: Context) -> ColorPickerLabel {
        let label = ColorPickerLabel(color: color)
        // Taps go to the enclosing button
        label.isUserInteractionEnabled = false
        return label
    }

    func updateUIView(_ label: ColorPickerLabel, context: Context) {
        label.selectedColor = color
    }
}

private struct ColorPickerRepresentable: UIViewControllerRepresentable {

    @Binding var color: RGBAColor

    func makeUIViewController(context: Context) -> UINavigationController {
        let uiViewController = ColorPickerViewController(color: color, mode: .grid, colorSpace: .displayP3)
        uiViewController.delegate = context.coordinator
        return UINavigationController(rootViewController: uiViewController)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        context.coordinator.parent = self
        if let picker = uiViewController.viewControllers.first as? ColorPickerViewController, picker.selectedColor != color {
            picker.selectedColor = color
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: ColorPickerViewControllerDelegate {
        var parent: ColorPickerRepresentable

        init(parent: ColorPickerRepresentable) {
            self.parent = parent
        }

        func colorPickerViewController(
            _ viewController: ColorPickerViewController,
            didSelect color: RGBAColor,
            continuously: Bool
        ) {
            parent.color = color
        }
    }
}
#endif
