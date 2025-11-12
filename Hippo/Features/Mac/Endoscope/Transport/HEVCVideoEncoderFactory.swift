//
//  HEVCVideoEncoderFactory.swift
//  Hippo
//
//  Custom HEVC video encoder factory for LiveKit WebRTC
//  Provides H.265/HEVC encoding via VideoToolbox
//

import Foundation
import LiveKitWebRTC
import VideoToolbox
import CoreMedia
import os.log

// MARK: - HEVC Video Encoder Factory

/// Factory for creating HEVC video encoders
/// Supports both H.265 (HEVC) and H.264 (fallback)
public class HEVCVideoEncoderFactory: NSObject, LKRTCVideoEncoderFactory {

    private let logger = Logger(subsystem: "com.television.hippo", category: "HEVCEncoder")

    public override init() {
        super.init()
        logger.info("🏭 HEVC Video Encoder Factory initialized")
    }

    public func supportedCodecs() -> [LKRTCVideoCodecInfo] {
        let codecs = [
            LKRTCVideoCodecInfo(name: "H265"),   // HEVC - preferred
            LKRTCVideoCodecInfo(name: "H264"),   // H.264 - fallback
            LKRTCVideoCodecInfo(name: "VP8")     // VP8 - fallback
        ]

        logger.info("📋 Supported codecs: \(codecs.map { $0.name })")
        return codecs
    }

    public func createEncoder(_ info: LKRTCVideoCodecInfo) -> LKRTCVideoEncoder? {
        logger.info("🔨 Creating encoder for codec: \(info.name)")

        // Use HEVC encoder for H265
        if info.name == "H265" {
            logger.info("✅ Creating HEVC encoder")
            return HEVCVideoEncoder()
        }

        // For other codecs (H.264, VP8), use default encoder
        logger.info("ℹ️ Using default encoder for \(info.name)")
        return nil
    }
}
