//
//  CameraInputToggle.swift
//  HippoMac
//
//  Camera input mode toggle component
//

import SwiftUI

struct CameraInputToggle: View {
    @Binding var selectedMode: CameraInputMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CameraInputMode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .frame(minWidth: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedMode == mode ?
                                      Color("HippoGray", bundle: nil) :
                                      Color.clear)
                        )
                        .foregroundColor(selectedMode == mode ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
}
