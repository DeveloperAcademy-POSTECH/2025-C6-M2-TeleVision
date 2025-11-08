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
                    .font(.headline)
                Spacer()
                RecordingIndicator()
            }
            .padding(.horizontal, 20)
        }
        .contentShape(.capsule)
        .frame(width: 140, height: 56)
        .buttonStyle(.plain)
        .background(.clear)
        .overlay {
            Capsule()
                .stroke(.white, lineWidth: 1)
        }
    }
}

#Preview {
    RecordButton(action: {})
}
