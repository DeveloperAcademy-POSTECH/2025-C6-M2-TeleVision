//
//  AssetThumbnailView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/14/25.
//

import SwiftUI

struct AssetThumbnailView: View {
    @State private var loader = ThumbnailLoader()
    let url: URL
    let fileName: String
    var onDelete: (() -> Void)? = nil
    // Enable dimming on hover only when requested by the caller (e.g., OperationInputView)
    var enableHoverDimming: Bool = false
    @State private var isHovered: Bool = false

    var body: some View {
        VStack {
            Group {
                if let image = loader.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.hippoGray500)
                        .overlay(
                            ProgressView()
                                .controlSize(.small)
                        )
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                ZStack {
                    if enableHoverDimming && isHovered {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.25))
                    }
                    if enableHoverDimming && isHovered, let onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }

            )
            .onHover { hovering in
                if enableHoverDimming {
                    isHovered = hovering
                }
            }

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
