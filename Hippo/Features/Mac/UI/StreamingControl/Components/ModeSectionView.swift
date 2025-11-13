//
//  ModeSectionView.swift
//  HippoMac
//
//  Mode selection section component
//

import SwiftUI

struct ModeSectionView: View {
    @Binding var selectedMode: VideoMode
    let cameraInputMode: CameraInputMode

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Mode")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)

            HStack(spacing: 8) {
                ForEach(VideoMode.allCases, id: \.self) { mode in
                    ModeButton(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        action: { selectedMode = mode }
                    )
                    .disabled(cameraInputMode == .single && mode != .mono)
                    .opacity(cameraInputMode == .single && mode != .mono ? 0.5 : 1.0)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}
