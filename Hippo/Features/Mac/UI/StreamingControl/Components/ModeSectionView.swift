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
                    .disabled(isModeDisabled(mode))
                    .opacity(isModeDisabled(mode) ? 0.5 : 1.0)
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

    /// 카메라 입력 모드에 따라 비디오 모드 비활성화 여부 결정
    /// - Single: Mono만 허용
    /// - Single SBS: Full SBS, Half SBS만 허용 (Mono 비활성화)
    /// - Dual: 모든 모드 허용 (Mono 선택 시 didSet에서 Single로 전환)
    private func isModeDisabled(_ mode: VideoMode) -> Bool {
        switch cameraInputMode {
        case .single:
            return mode != .mono
        case .singleSBS:
            return mode == .mono
        case .dual:
            return false
        }
    }
}
