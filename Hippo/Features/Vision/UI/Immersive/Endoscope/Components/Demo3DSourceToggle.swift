//
//  Demo3DSourceToggle.swift
//  Hippo
//
//  3D Demo 모드 내에서 영상 소스를 전환하는 토글 UI
//  기본: Bird (순한 영상) / 선택: Endoscope (수술 영상)
//

import SwiftUI

/// 3D Demo 영상 소스 선택 토글
/// - Bird: 편안한 보기 (bird-3d.mov)
/// - Endoscope: 수술 장면 보기 (endoscope-demo.mp4)
struct Demo3DSourceToggle: View {
    let selected: Demo3DVideoSource
    let onChange: (Demo3DVideoSource) -> Void

    /// 전환 중 상태 (외부에서 주입)
    var isSwitching: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Demo3DVideoSource.allCases, id: \.self) { source in
                Button {
                    if selected != source {
                        onChange(source)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: source == .bird ? "bird.fill" : "medical.thermometer.fill")
                            .font(.system(size: 12))

                        Text(source.displayLabel)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(selected == source ? .white : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(selected == source
                                  ? Color.blue.opacity(0.8)
                                  : Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .disabled(isSwitching)
            }
        }
        .padding(6)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        Demo3DSourceToggle(
            selected: .bird,
            onChange: { _ in }
        )

        Demo3DSourceToggle(
            selected: .endoscope,
            onChange: { _ in }
        )
    }
    .padding()
    .glassBackgroundEffect()
}
