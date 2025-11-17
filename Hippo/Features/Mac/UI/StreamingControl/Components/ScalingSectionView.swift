//
//  ScalingSectionView.swift
//  HippoMac
//
//  Resolution scaling selection section component
//

import SwiftUI

struct ScalingSectionView: View {
    @Binding var selectedScaling: ScalingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Resolution Scale")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)

            HStack(spacing: 8) {
                ForEach(ScalingMode.allCases, id: \.self) { mode in
                    ScalingButton(
                        mode: mode,
                        isSelected: selectedScaling == mode,
                        action: { selectedScaling = mode }
                    )
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

struct ScalingButton: View {
    let mode: ScalingMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(mode.rawValue)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .frame(minWidth: 120)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ?
                              Color("HippoPrimary", bundle: nil) :
                              Color.clear)
                )
                .foregroundColor(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}
