//
//  RecordingIndicator.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct RecordingIndicator: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .frame(width: 28, height: 28)
            
            Circle()
                .fill(.red)
                .frame(width: 20, height: 20)
        }
    }
}
