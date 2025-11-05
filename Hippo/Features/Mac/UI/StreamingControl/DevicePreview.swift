//
//  DevicePreview.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

//MARK: DevicePreview.swift
import SwiftUI
import AppKit
import AVFoundation

/// A SwiftUI wrapper that hosts a provided CALayer (e.g., AVSampleBufferDisplayLayer)
/// and keeps it sized to the view's bounds. Use this to display video frames
/// by passing in your `AVSampleBufferDisplayLayer` from ContentView.
struct DevicePreview: NSViewRepresentable {

    /// The layer to be displayed. Typically an `AVSampleBufferDisplayLayer`.
    private let preview: CALayer

    /// Designated initializer accepting any CALayer.
    init(preview: CALayer) {
        self.preview = preview
    }

    /// Convenience initializer specifically for AVSampleBufferDisplayLayer.
    init(videoLayer: AVSampleBufferDisplayLayer) {
        self.preview = videoLayer
    }

    func makeNSView(context: Context) -> SampleBufferPreview {
        SampleBufferPreview(preview: preview)
    }

    func updateNSView(_ nsView: SampleBufferPreview, context: Context) {
        // No-op: sizing is handled in SampleBufferPreview.layout().
    }

    // MARK: - Backing NSView
    class SampleBufferPreview: NSView {
        let preview: CALayer

        init(preview: CALayer) {
            self.preview = preview
            super.init(frame: .zero)
            wantsLayer = true

            // Ensure the host view has a root layer to attach to.
            if layer == nil {
                layer = CALayer()
            }

            // Avoid implicit animations when adding/sizing.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer?.addSublayer(preview)
            preview.frame = bounds
            preview.contentsGravity = .resizeAspect
            CATransaction.commit()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layout() {
            super.layout()
            // Keep the preview layer sized to fill this view.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            preview.frame = bounds
            CATransaction.commit()
        }

        override var isFlipped: Bool { true }
    }
}

// MARK: - SwiftUI Preview (optional)
#if DEBUG
#Preview("DevicePreview Placeholder") {
    // Show an empty CALayer placeholder in previews.
    let layer = CALayer()
    layer.backgroundColor = NSColor.black.withAlphaComponent(0.1).cgColor
    return DevicePreview(preview: layer)
        .frame(width: 320, height: 180)
        .border(Color.gray)
        .padding()
}
#endif
