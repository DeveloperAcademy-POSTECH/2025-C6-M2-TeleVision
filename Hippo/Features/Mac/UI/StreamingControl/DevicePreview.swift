//
//  DevicePreview.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

//MARK: DevicePreview.swift
import SwiftUI
import AVFoundation

struct DevicePreview: UIViewRepresentable {
    let preview: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoLayer = preview
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoLayer !== preview {
            uiView.videoLayer = preview
        }
    }
}

final class PreviewView: UIView {
    var videoLayer: AVSampleBufferDisplayLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let l = videoLayer {
                l.frame = bounds
                l.videoGravity = .resizeAspect
                layer.addSublayer(l)
                setNeedsLayout()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoLayer?.frame = bounds
    }
}
