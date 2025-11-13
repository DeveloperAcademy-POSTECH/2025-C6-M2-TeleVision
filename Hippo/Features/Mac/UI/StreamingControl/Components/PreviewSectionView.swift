//
//  PreviewSectionView.swift
//  HippoMac
//
//  Preview section component
//

import SwiftUI
import AVFoundation

struct PreviewSectionView: View {
    let videoLayer: AVSampleBufferDisplayLayer

    var body: some View {
        VStack {
            DevicePreview(preview: videoLayer)
                .frame(maxWidth: .infinity)
                .frame(height: 350)
                .background(Color.black.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}
