//
// Copyright (c) Nathan Tannar
//

import SwiftUI

/// Every page of the playground, one per area of the Paint API.
enum Demo: String, CaseIterable, Identifiable, Hashable {
    case models
    case adjustments
    case contrast
    case vision
    case palettes
    case gradients
    case blending
    case matrices
    case images
    case css
    case temperature
    case hdr
    case swiftUI
    #if os(iOS) || os(visionOS)
    case colorPicker
    #endif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .models: "Color Models"
        case .adjustments: "Adjustments"
        case .contrast: "Contrast"
        case .vision: "Color Vision"
        case .palettes: "Palettes"
        case .gradients: "Gradients"
        case .blending: "Blending"
        case .matrices: "Color Matrices"
        case .images: "Image Colors"
        case .css: "CSS & Strings"
        case .temperature: "Temperature"
        case .hdr: "HDR & Wide Gamut"
        case .swiftUI: "SwiftUI"
        #if os(iOS) || os(visionOS)
        case .colorPicker: "Color Picker"
        #endif
        }
    }

    var systemImage: String {
        switch self {
        case .models: "cube"
        case .adjustments: "slider.horizontal.3"
        case .contrast: "circle.lefthalf.filled"
        case .vision: "eye"
        case .palettes: "swatchpalette"
        case .gradients: "rectangle.fill"
        case .blending: "square.2.layers.3d"
        case .matrices: "camera.filters"
        case .images: "photo"
        case .css: "chevron.left.forwardslash.chevron.right"
        case .temperature: "thermometer.medium"
        case .hdr: "sun.max"
        case .swiftUI: "swift"
        #if os(iOS) || os(visionOS)
        case .colorPicker: "eyedropper"
        #endif
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .models: ModelsDemo()
        case .adjustments: AdjustmentsDemo()
        case .contrast: ContrastDemo()
        case .vision: VisionDemo()
        case .palettes: PalettesDemo()
        case .gradients: GradientsDemo()
        case .blending: BlendingDemo()
        case .matrices: ColorMatrixDemo()
        case .images: ImageColorsDemo()
        case .css: CSSDemo()
        case .temperature: TemperatureDemo()
        case .hdr: HDRDemo()
        case .swiftUI: SwiftUIDemo()
        #if os(iOS) || os(visionOS)
        case .colorPicker: ColorPickerDemo()
        #endif
        }
    }
}

struct ContentView: View {

    @State private var selection: Demo? = {
        #if os(macOS)
        return .models
        #else
        return nil
        #endif
    }()

    var body: some View {
        NavigationSplitView {
            List(Demo.allCases, selection: $selection) { demo in
                NavigationLink(value: demo) {
                    Label(demo.title, systemImage: demo.systemImage)
                }
            }
            .navigationTitle("Paint")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            #endif
        } detail: {
            NavigationStack {
                if let selection {
                    selection.destination
                        .id(selection)
                } else {
                    ContentUnavailableView("Select a Demo", systemImage: "paintpalette")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
