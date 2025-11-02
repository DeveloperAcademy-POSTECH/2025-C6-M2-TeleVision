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
                .frame(width: 12, height: 12)
            
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
        }
    }
}
