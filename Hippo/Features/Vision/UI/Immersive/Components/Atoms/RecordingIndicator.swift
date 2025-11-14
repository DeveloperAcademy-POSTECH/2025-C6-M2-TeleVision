//
//  RecordingIndicator.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct RecordingIndicator: View {
    let isRecording: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .frame(width: 28, height: 28)

            if isRecording {
                Rectangle()
                    .fill(.red)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 0)
            } else {
                Circle()
                    .fill(.red)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 0)
            }
        }
    }
}
