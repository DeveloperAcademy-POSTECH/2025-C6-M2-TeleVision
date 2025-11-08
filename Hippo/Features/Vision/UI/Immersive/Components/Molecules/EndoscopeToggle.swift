//
//  EndoscopeToggle.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct EndoscopeToggle: View {
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle("내시경", isOn: $isOn)
            .toggleStyle(SizedSwitchToggleStyle(width: 70, height: 40, onTint: .hippoPrimary))
            .frame(width: 127, height: 40)
    }
}

struct SizedSwitchToggleStyle: ToggleStyle {
    var width: CGFloat = 70
    var height: CGFloat = 40
    var onTint: Color = .hippoPrimary
    var offTint: Color = .gray.opacity(0.3)
    
    func makeBody(configuration: Configuration) -> some View {
        let knob = height - 4
        
        HStack(spacing: 4) {
            configuration.label
                .font(.headline)
                .foregroundStyle(.secondary)
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    configuration.isOn.toggle()
                }
            } label: {
                RoundedRectangle(cornerRadius: height/2, style: .continuous)
                    .fill(configuration.isOn ? onTint : offTint)
                    .frame(width: width, height: height)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: knob, height: knob)
                            .shadow(radius: 0.5, y: 0.5)
                            .padding(2)
                            .frame(maxWidth: .infinity,
                                   alignment: configuration.isOn ? .trailing : .leading)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    EndoscopeToggle(isOn: .constant(true))
}
