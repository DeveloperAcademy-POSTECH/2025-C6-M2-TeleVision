//
//  Demo3DSourceToggle.swift
//  Hippo
//
//  3단계: 3D Demo 모드에서 영상 소스 선택
//  General (bird) / Endoscopic (수술 영상)
//

import SwiftUI

/// 3D Demo 영상 소스 선택 토글
struct Demo3DSourceToggle: View {
    let selected: Demo3DVideoSource
    let onChange: (Demo3DVideoSource) -> Void
    var isSwitching: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Demo3DVideoSource.allCases, id: \.self) { source in
                SourceButton(
                    source: source,
                    isSelected: selected == source,
                    isDisabled: isSwitching
                ) {
                    if selected != source {
                        onChange(source)
                    }
                }
            }
        }
        .padding(6)
    }
}

// MARK: - Source Button Component

private struct SourceButton: View {
    let source: Demo3DVideoSource
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    private var icon: String {
        source == .bird ? "bird.fill" : "medical.thermometer.fill"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(source.displayLabel)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(
                    isSelected ? Color.blue.opacity(0.8) : Color.white.opacity(0.08)
                )
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .disabled(isDisabled)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        Demo3DSourceToggle(selected: .bird, onChange: { _ in })
        Demo3DSourceToggle(selected: .endoscope, onChange: { _ in })
    }
    .padding()
    .glassBackgroundEffect()
}
