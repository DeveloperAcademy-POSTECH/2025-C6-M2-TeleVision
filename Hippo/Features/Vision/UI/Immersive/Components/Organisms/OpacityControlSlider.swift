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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 4) {
                Text("불투명도")
                    .font(.callout)
                Text(isMixed ? "Mixed" : "\(Int(currentOpacity * 100))%")
                    .font(.title3)
                    .animation(.none, value: isMixed)
            }
            .foregroundStyle(.secondary)
            
            Slider(value: sliderBinding, in: 0.0...1.0) {
                Text("Opacity")
            }
            .controlSize(.small)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 2, y: 2)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 200)
                .fill(selectedLayerIDS.isEmpty ? AnyShapeStyle(Color.black.opacity(0.25)) : AnyShapeStyle(.quaternary))
        )
        .overlay(
            selectedLayerIDS.isEmpty
            ? AnyView(
                RoundedRectangle(cornerRadius: 200, style: .continuous)
                    .stroke(Color.black.opacity(0.25), lineWidth: 4)
                    .blur(radius: 2)
                    .offset(x: 1, y: 1)
                    .mask(
                        RoundedRectangle(cornerRadius: 200).fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.black, .clear]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
            )
            : AnyView(EmptyView())
        )
        //        .animation(.easeInOut, value: selectedLayerIDS.isEmpty)
        .frame(maxWidth: .infinity)
        .disabled(selectedLayerIDS.isEmpty)
        .glassBackgroundEffect(in: .capsule, displayMode: .always)
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
