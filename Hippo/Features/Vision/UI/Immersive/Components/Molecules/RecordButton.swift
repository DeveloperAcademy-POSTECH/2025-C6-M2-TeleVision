//
//  RecordButton.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct RecordButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text("녹화")
                    .font(.callout)
                Spacer()
                RecordingIndicator()
            }
            .padding(.horizontal, 10)
            .frame(maxHeight: .infinity)
        }
        .contentShape(.capsule)
        .frame(width: 100, height: 44)
        .buttonStyle(.plain)
        .glassBackgroundEffect(in: .capsule, displayMode: .always)
        .background(.clear)
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.7), radius: 4, x: 2, y: 2)
    }
}

#Preview {
    RecordButton(action: {})
}
