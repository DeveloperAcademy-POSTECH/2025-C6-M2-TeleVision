//
//  StreamingButton.swift
//  HippoMac
//
//  Streaming control button component
//

import SwiftUI

struct StreamingButton: View {
    let isStreaming: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isStreaming ? "stop.fill" : "video.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text(isStreaming ? "Stop Streaming" : "Start Streaming")
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(minWidth: 300)
            .padding(.vertical, 18)
            .padding(.horizontal, 40)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isStreaming ?
                          Color("HippoRed", bundle: nil) :
                          Color("HippoPrimary", bundle: nil))
            )
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}
