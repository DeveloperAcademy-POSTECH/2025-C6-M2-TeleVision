//
//  ModeButton.swift
//  HippoMac
//
//  Mode selection button component
//

import SwiftUI

struct ModeButton: View {
    let mode: VideoMode
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
