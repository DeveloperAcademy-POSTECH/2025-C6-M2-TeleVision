//
//  ScalingSectionView.swift
//  HippoMac
//
//  Resolution scaling and bitrate selection section component
//

import SwiftUI

struct ScalingSectionView: View {
    @Binding var selectedScaling: ScalingMode
    @Binding var isHalfBitrateEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Resolution & Bitrate")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)

            HStack(alignment: .top, spacing: 24) {
                // Resolution Scale
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resolution Scale")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(ScalingMode.allCases.filter { [.none, .half, .quarter].contains($0) }, id: \.self) { mode in
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

                // Bitrate Toggle
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bitrate")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Toggle(isOn: $isHalfBitrateEnabled) {
                            HStack(spacing: 8) {
                                Text("Half")
                                    .font(.system(size: 14, weight: .medium))
                                Text(isHalfBitrateEnabled ? "15 Mbps" : "30 Mbps")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                }
            }
        }
        .padding(12)
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
                .padding(.horizontal, 28)
                .padding(.vertical, 8)
                .frame(minWidth: 95)
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
