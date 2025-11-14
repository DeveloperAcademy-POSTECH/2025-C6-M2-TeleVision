//
//  RecordButton.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct RecordButton: View {
    let action: () -> Void
    let isRecording: Bool

    var body: some View {
        Button(action: action) {
            HStack {
                Text("녹화")
                    .font(.callout)
                Spacer()
                RecordingIndicator(isRecording: isRecording)
            }
            .padding(.horizontal, 10)
            .frame(maxHeight: .infinity)
        }
        .contentShape(.capsule)
//        .frame(width: 100, height: 44)
        .frame(width: isRecording ? 130 : 100, height: 44)
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: .capsule, displayMode: .always)
        .background(.clear)
//        .overlay {
//            Capsule()
//                .stroke(.white.opacity(0.25), lineWidth: 1)
//        }
//        .shadow(color: .black.opacity(0.7), radius: 4, x: 2, y: 2)
        .overlay {
            Capsule()
                .stroke(isRecording ? Color.red.opacity(0.7) : .white.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: isRecording ? .red.opacity(0.3) : .black.opacity(0.5), radius: 10, x: 2, y: 2)
        .animation(.smooth(duration: 1.0), value: isRecording)
//        .animation(.spring(response: 1.0, dampingFraction: 0.5), value: isRecording)
    }
}

#Preview {
    RecordButton(action: {}, isRecording: true)
}
