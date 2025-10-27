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
                Spacer()
                RecordingIndicator()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderless)
        .contentShape(.circle)
        .background(.clear)
        .frame(width: 130, height: 56)
        .overlay {
            Capsule()
                .stroke(.white, lineWidth: 1)
        }
    }
}

#Preview {
    RecordButton(action: {})
}
