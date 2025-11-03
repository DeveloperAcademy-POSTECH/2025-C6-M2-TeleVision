//
//  OpacityControlSlider.swift
//  HippoVision
//
//  Created by yunsly on 11/3/25.
//

import SwiftUI

struct OpacityControlSlider: View {
    
    @Binding var currentOpacity: Float
    var selectedLayerIDS: Set<String>
    var isMixed: Bool
    
    private var sliderBinding: Binding<Float> {
        Binding<Float>(
            get: {
                return isMixed ? 0.0 : currentOpacity
            },
            set: { newValue in
                currentOpacity = newValue
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("불투명도")
                    .font(.headline)
                Text(isMixed ? "Mixed" : "\(Int(currentOpacity * 100))%")
                    .font(.title)
                    .animation(.none, value: isMixed)
            }
            .foregroundStyle(.secondary)
            
            Slider(value: sliderBinding, in: 0.0...1.0) {
                Text("Opacity")
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 200)
                .fill(.quaternary)
        )
        .frame(maxWidth: .infinity)
        .disabled(selectedLayerIDS.isEmpty)
    }
}

#Preview {
    @Previewable @State var previewOpacity: Float = 0.75
    
    OpacityControlSlider(
        currentOpacity: $previewOpacity,
        selectedLayerIDS: ["layer_id_1"],
        isMixed: false
    )
}


