//
//  HEVCVideoDecoderFactory.swift
//  Hippo
//
//  Custom HEVC video decoder factory for LiveKit WebRTC (Vision Pro)
//  Provides H.265/HEVC decoding via VideoToolbox
//

import Foundation
import LiveKitWebRTC
import VideoToolbox
import CoreMedia
import os.log

// MARK: - HEVC Video Decoder Factory

/// Factory for creating HEVC video decoders
/// Supports both H.265 (HEVC) and H.264 (fallback)
public class HEVCVideoDecoderFactory: NSObject, LKRTCVideoDecoderFactory {

    private let logger = Logger(subsystem: "com.television.hippo", category: "HEVCDecoder")

    public override init() {
        super.init()
        logger.info("🏭 HEVC Video Decoder Factory initialized")
    }

    public func supportedCodecs() -> [LKRTCVideoCodecInfo] {
        let codecs = [
            LKRTCVideoCodecInfo(name: "H265"),  // HEVC - preferred
            LKRTCVideoCodecInfo(name: "H264")   // H.264 - fallback
        ]

        logger.info("📋 Supported codecs: \(codecs.map { $0.name })")
        return codecs
    }

    public func createDecoder(_ info: LKRTCVideoCodecInfo) -> LKRTCVideoDecoder? {
        logger.info("🔨 Creating decoder for codec: \(info.name)")

        // Use HEVC decoder for H265
        if info.name == "H265" {
            logger.info("✅ Creating HEVC decoder")
            return HEVCVideoDecoder()
        }

        // For other codecs (H.264), use default decoder
        logger.info("ℹ️ Using default decoder for \(info.name)")
        return nil
    }
}
