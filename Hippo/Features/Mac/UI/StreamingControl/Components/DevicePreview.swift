//
//  DevicePreview.swift
//  HippoMac
//
//  Video preview component using AVSampleBufferDisplayLayer
//

import SwiftUI
import AVFoundation

struct DevicePreview: NSViewRepresentable {
    let preview: AVSampleBufferDisplayLayer

    func makeNSView(context: Context) -> PreviewLayerView {
        let view = PreviewLayerView()
        view.displayLayer = preview

        // Configure the display layer
        preview.videoGravity = .resizeAspect
        preview.backgroundColor = NSColor.black.cgColor

        return view
    }

    func updateNSView(_ nsView: PreviewLayerView, context: Context) {
        // Update if needed
    }
}

// MARK: - PreviewLayerView

final class PreviewLayerView: NSView {
    var displayLayer: AVSampleBufferDisplayLayer? {
        didSet {
            setupLayer()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    private func setupLayer() {
        guard let layer = layer, let displayLayer = displayLayer else { return }

        // Remove old sublayer if exists
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        // Add display layer as sublayer
        layer.addSublayer(displayLayer)
        displayLayer.frame = layer.bounds
    }

    override func layout() {
        super.layout()

        // Update display layer frame when view bounds change
        if let layer = layer {
            displayLayer?.frame = layer.bounds
        }
    }
}
