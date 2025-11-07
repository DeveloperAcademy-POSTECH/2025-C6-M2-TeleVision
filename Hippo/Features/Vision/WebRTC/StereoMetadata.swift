/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A model that describes typical stereo metadata.
*/

import CoreVideo
import Foundation
import os.log

/// A model that describes typical stereo metadata.
struct StereoMetadata {
    /// Describes potential frame-packing approaches.
    enum FramePacking {
        /// Indicates that frames are packed side-by-side.
        case sideBySide

        /// Indicates that frames are packed, one over another.
        case overUnder
    }

    /// Describes the stereo input mode for proper offset calculation.
    enum StereoInputMode {
        /// Single SBS (side-by-side) source where left/right eyes are packed in one buffer.
        /// Example: 3840×1080 containing two 1920×1080 eyes side-by-side.
        case singleSourceSBS

        /// Already split into separate per-eye buffers.
        /// Example: Two separate 1920×1080 buffers, one for each eye.
        case splitEyes
    }

    /// The current frame packing.
    let framePacking: FramePacking

    // MARK: Internal behavior

    /// Initializes with the specified frame packing applied.
    /// - Parameter framePacking: The prevailing frame packing.
    init(framePacking: FramePacking) {
        self.framePacking = framePacking
    }

    /// Describes horizontal & vertical components of aperture offset.
    typealias ApertureOffset = (horizontal: CGFloat, vertical: CGFloat)

    /// Returns the aperture offset for a given source size, layer ID, and input mode (resolution-independent).
    /// - Parameters:
    ///   - layerID: The layer ID corresponding to a given frame (0 = left, 1 = right).
    ///   - sourceSize: The ORIGINAL source frame size (e.g., 3840×1080 for full SBS, or 1920×1080 for split).
    ///   - mode: The stereo input mode (singleSourceSBS or splitEyes).
    /// - Returns: The calculated aperture offset relative to the source center.
    func cleanApertureOffset(for layerID: Int, sourceSize: CGSize, mode: StereoInputMode) -> ApertureOffset {
        let logger = Logger(subsystem: "com.television.hippo", category: "StereoMetadata")
        let eyeName = layerID == 0 ? "Left" : "Right"

        // 🔍 DIAGNOSTIC: Log input parameters
        logger.info("🔍 [DIAGNOSTIC] cleanApertureOffset called:")
        logger.info("   LayerID: \(layerID) (\(eyeName))")
        logger.info("   SourceSize: \(sourceSize.width)×\(sourceSize.height)")
        logger.info("   Mode: \(mode == .singleSourceSBS ? "singleSourceSBS" : "splitEyes")")
        logger.info("   FramePacking: \(self.isSideBySide ? "sideBySide" : "overUnder")")

        switch mode {
        case .singleSourceSBS:
            // For SBS: each eye should see exactly half of the source width.
            // Clean aperture offset should be ±(sourceWidth / 4).
            //
            // Example: 3840×1080 SBS source
            // - Source center: (1920, 540)
            // - Left eye center: (960, 540) → offset = 960 - 1920 = -960 = -(3840/4)
            // - Right eye center: (2880, 540) → offset = 2880 - 1920 = +960 = +(3840/4)
            //
            // Example: 1920×1080 SBS source
            // - Source center: (960, 540)
            // - Left eye center: (480, 540) → offset = 480 - 960 = -480 = -(1920/4)
            // - Right eye center: (1440, 540) → offset = 1440 - 960 = +480 = +(1920/4)
            //
            // Example: 852×240 SBS source
            // - Source center: (426, 120)
            // - Left eye center: (213, 120) → offset = 213 - 426 = -213 = -(852/4)
            // - Right eye center: (639, 120) → offset = 639 - 426 = +213 = +(852/4)
            if isSideBySide {
                let offset = sourceSize.width / 4.0
                let multiplier = CGFloat(layerID) * 2.0 - 1.0
                let result: ApertureOffset = (
                    horizontal: offset * multiplier,
                    vertical: 0.0
                )

                // 🔍 DIAGNOSTIC: Log calculation details
                logger.info("🔍 [DIAGNOSTIC] SBS calculation:")
                logger.info("   Base offset (sourceWidth/4): \(String(format: "%.2f", offset))")
                logger.info("   Multiplier for \(eyeName): \(String(format: "%.2f", multiplier))")
                logger.info("   Result: H=\(String(format: "%.2f", result.horizontal)), V=\(String(format: "%.2f", result.vertical))")

                // Calculate expected eye center for verification
                let sourceCenter = sourceSize.width / 2.0
                let eyeWidth = sourceSize.width / 2.0
                let expectedEyeCenter = layerID == 0 ? eyeWidth / 2.0 : eyeWidth / 2.0 + eyeWidth
                let calculatedEyeCenter = sourceCenter + result.horizontal

                logger.info("🔍 [DIAGNOSTIC] Verification:")
                logger.info("   Source center X: \(String(format: "%.1f", sourceCenter))")
                logger.info("   Expected \(eyeName) eye center X: \(String(format: "%.1f", expectedEyeCenter))")
                logger.info("   Calculated \(eyeName) eye center X: \(String(format: "%.1f", calculatedEyeCenter))")
                logger.info("   Match: \(abs(expectedEyeCenter - calculatedEyeCenter) < 1.0 ? "✅" : "❌")")

                return result
            } else {
                // Over-under packing
                let offset = sourceSize.height / 4.0
                let multiplier = CGFloat(layerID) * 2.0 - 1.0
                let result: ApertureOffset = (
                    horizontal: 0.0,
                    vertical: offset * multiplier
                )

                logger.info("🔍 [DIAGNOSTIC] OverUnder calculation:")
                logger.info("   Base offset (sourceHeight/4): \(String(format: "%.2f", offset))")
                logger.info("   Result: H=\(String(format: "%.2f", result.horizontal)), V=\(String(format: "%.2f", result.vertical))")

                return result
            }

        case .splitEyes:
            // For already-split buffers: each buffer represents the full eye region.
            // No offset needed because there's no cropping to do.
            logger.info("🔍 [DIAGNOSTIC] SplitEyes mode: No offset needed")
            return (horizontal: 0.0, vertical: 0.0)
        }
    }

    /// Legacy method for backwards compatibility. Prefer cleanApertureOffset(for:sourceSize:mode:).
    /// - Parameters:
    ///   - bufferSize: The eye buffer size (half of source for SBS).
    ///   - layerID: The layer ID corresponding to a given frame.
    /// - Returns: The calculated aperture offset.
    @available(*, deprecated, message: "Use cleanApertureOffset(for:sourceSize:mode:) instead")
    func apertureOffset(for bufferSize: CVImageSize, layerID: Int) -> ApertureOffset {
        // Convert to source size (assuming single SBS mode)
        let sourceSize = CGSize(
            width: CGFloat(bufferSize.width) * horizontalScale,
            height: CGFloat(bufferSize.height) * verticalScale
        )
        return cleanApertureOffset(for: layerID, sourceSize: sourceSize, mode: .singleSourceSBS)
    }

    /// Returns the horizontal scale for a given frame packing.
    var horizontalScale: CGFloat {
        switch framePacking {
        case .sideBySide:
            return 2
        case .overUnder:
            return 1
        }
    }

    /// Returns the vertical scale for a given frame packing.
    var verticalScale: CGFloat {
        switch framePacking {
        case .sideBySide:
            return 1
        case .overUnder:
            return 2
        }
    }

    // MARK: Private behavior

    /// Returns `true` if the frame packing is side-by-side; `false` otherwise.
    private var isSideBySide: Bool {
        return framePacking == .sideBySide
    }
}

// MARK: - StereoMetadata (Default)

extension StereoMetadata {
    /// By default, the stereo metadata assumes side-by-side frame packing.
    static let `default` = StereoMetadata(framePacking: .sideBySide)
}
