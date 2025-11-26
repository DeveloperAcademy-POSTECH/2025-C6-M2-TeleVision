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

        // Configure the display layer
        preview.videoGravity = .resizeAspect
        preview.backgroundColor = NSColor.black.cgColor

        view.displayLayer = preview
        return view
    }

    func updateNSView(_ nsView: PreviewLayerView, context: Context) {
        // Re-attach layer when view is updated (e.g., after tab switch)
        // This is needed because the layer may have been removed from its superlayer
        if preview.superlayer == nil {
            nsView.displayLayer = preview
        }
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
        // Disable implicit animations to prevent layout jumps
        layer?.actions = ["sublayers": NSNull(), "bounds": NSNull(), "position": NSNull()]
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.actions = ["sublayers": NSNull(), "bounds": NSNull(), "position": NSNull()]
    }

    private func setupLayer() {
        guard let layer = layer, let displayLayer = displayLayer else { return }

        // Disable animations during setup
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Remove old sublayer if exists
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        // Add display layer as sublayer
        layer.addSublayer(displayLayer)
        displayLayer.frame = layer.bounds

        CATransaction.commit()
    }

    override func layout() {
        super.layout()

        // Update display layer frame when view bounds change
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer?.frame = bounds
        CATransaction.commit()
    }
}
