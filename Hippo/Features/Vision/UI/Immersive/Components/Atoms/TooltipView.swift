//
//  tooltipView.swift
//  Hippo
//
//  Created by yunsly on 11/17/25.
//

import SwiftUI

struct TooltipView: View {
    var tooltipText: String
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack {
            Text(tooltipText)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassBackgroundEffect(displayMode: .always)
        .cornerRadius(200)
        .overlay {
            RoundedRectangle(cornerRadius: 200)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.75)
        }
    }
}
