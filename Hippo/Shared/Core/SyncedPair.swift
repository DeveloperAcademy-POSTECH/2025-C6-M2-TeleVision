//
//  SyncedPair.swift
//  Hippo
//
//  Synchronized frame pair from left/right cameras
//

import Foundation
import CoreVideo
import CoreMedia

/// Synchronized stereo frame pair
/// Produced by FrameSync when left/right frames match within tolerance
public struct SyncedPair {
    /// Left eye pixel buffer (1920×1080 NV12/I420)
    public let left: CVPixelBuffer

    /// Right eye pixel buffer (1920×1080 NV12/I420)
    public let right: CVPixelBuffer

    /// Synchronized presentation timestamp (averaged)
    public let pts: CMTime

    /// Left frame original size
    public let leftSize: CGSize

    /// Right frame original size
    public let rightSize: CGSize

    /// Time delta between left and right frames (ms)
    public let timeDelta: Double

    public init(
        left: CVPixelBuffer,
        right: CVPixelBuffer,
        pts: CMTime,
        leftSize: CGSize,
        rightSize: CGSize,
        timeDelta: Double
    ) {
        self.left = left
        self.right = right
        self.pts = pts
        self.leftSize = leftSize
        self.rightSize = rightSize
        self.timeDelta = timeDelta
    }
}
