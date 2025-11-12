//
//  AssetListScrollView.swift
//  HippoVision
//
//  Created by yunsly on 11/2/25.
//

import SwiftUI

struct AssetListScrollView: View {
    let fileURLs: [URL]
    @Binding var selectedURL: URL?
    
    private let cardSize: CGFloat = 240
    private let cardSpacing: CGFloat = 30
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: cardSpacing) {
                Spacer()
                    .frame(width: 120)
                
                ForEach(fileURLs, id: \.self) { url in
                    let isSelected = (selectedURL == url)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 40)
                            .fill(.black.opacity(0.25))
                            .frame(width: 240, height: 240)
                            .glassBackgroundEffect(displayMode: .always)
                            .opacity(isSelected ? 1.0 : 0.0)
                        AssetListScrollCard(
                            url: url,
                            isSelected: selectedURL == url
                        )
                        .id(url) // 스크롤 위치 추적을 위한 ID
                        .scaleEffect(isSelected ? 1.0 : 0.9)
                        .opacity(isSelected ? 1.0 : 0.7)
                    }
                }
                Spacer()
                    .frame(width: 140)
            }
            .scrollTargetLayout()
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedURL)
        }
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .padding(.horizontal, 28)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selectedURL)
    }
}
