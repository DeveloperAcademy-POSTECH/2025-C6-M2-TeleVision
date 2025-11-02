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
                    .font(.system(size: 6))
                Spacer()
                RecordingIndicator()
            }
            .padding(.horizontal, 4)
        }
        .contentShape(.capsule)
        .frame(width: 40, height: 20)
        .buttonStyle(.plain)
        .background(.clear)
        .overlay {
            Capsule()
                .stroke(.white, lineWidth: 0.5)
        }
    }
}

#Preview {
    RecordButton(action: {})
}
