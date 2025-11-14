//
//  AssetThumnailView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/14/25.
//

import SwiftUI

struct AssetThumnailView: View {
    @StateObject private var loader = ThumnailLoader()
    let url: URL
    let fileName: String
   
    var body: some View {
        VStack {
            Group {
                if let image = loader.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray)
                        .overlay(
                            ProgressView()
                                .controlSize(.small)
                        )
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(fileName)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(width: 80)
        .onAppear {
            loader.load(for: url)
        }
    }
}

#Preview {
    RootView()
}
