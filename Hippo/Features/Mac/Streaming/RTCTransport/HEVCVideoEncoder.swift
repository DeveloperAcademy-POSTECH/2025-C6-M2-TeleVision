//
//  HEVCVideoEncoder.swift
//  Hippo
//
//  VideoToolbox-based HEVC encoder for LiveKit WebRTC
//  Implements LKRTCVideoEncoder protocol
//

import Foundation
import LiveKitWebRTC
import VideoToolbox
import CoreMedia
import CoreVideo
import os.log

// MARK: - HEVC Video Encoder

/// VideoToolbox-based HEVC encoder with proper NAL unit handling
public class HEVCVideoEncoder: NSObject, LKRTCVideoEncoder {
    // Protocol required properties
    public var resolutionAlignment: Int = 1
    public var applyAlignmentToAllSimulcastLayers: Bool = false
    public var supportsNativeHandle: Bool = false

    private let logger = Logger(subsystem: "com.television.hippo", category: "HEVCEncoder")

    // Compression session
    private var session: VTCompressionSession?

    // Encoder callback
    private var encoderCallback: ((LKRTCEncodedImage, LKRTCCodecSpecificInfo) -> Bool)?

    // Frame counter
    private var frameCount: Int = 0

    // Settings
    private var width: Int32 = 0
    private var height: Int32 = 0
    private var targetBitrate: Int = 0

    // Parameter sets (VPS/SPS/PPS) for HEVC
    private var vpsData: Data?
    private var spsData: Data?
    private var ppsData: Data?

    public override init() {
        super.init()
        logger.info("🎬 HEVC Video Encoder initialized")
    }

    deinit {
        if let session = session {
            VTCompressionSessionInvalidate(session)
        }
        logger.info("🗑️ HEVC Video Encoder deinitialized")
    }

    // MARK: - LKRTCVideoEncoder Protocol

    public func setCallback(_ callback: ((LKRTCEncodedImage, LKRTCCodecSpecificInfo) -> Bool)?) {
        self.encoderCallback = callback
        logger.info("✅ Encoder callback set")
    }

    public func startEncode(with settings: LKRTCVideoEncoderSettings, numberOfCores cores: Int32) -> Int {
        logger.info("🚀 Starting HEVC encoder: \(settings.width)×\(settings.height) @ \(settings.startBitrate) bps")

        self.width = Int32(settings.width)
        self.height = Int32(settings.height)
        self.targetBitrate = Int(settings.startBitrate)

        // Create compression session
        let status = createCompressionSession(
            width: self.width,
            height: self.height,
            bitrate: self.targetBitrate
        )

        if status != noErr {
            logger.error("❌ Failed to create compression session: \(status)")
            return Int(status)
        }

        logger.info("✅ HEVC encoder started successfully")
        return 0
    }

    public func release() -> Int {
        logger.info("🛑 Releasing HEVC encoder")

        if let session = session {
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }

        vpsData = nil
        spsData = nil
        ppsData = nil

        return 0
    }

    public func encode(_ frame: LKRTCVideoFrame,
                       codecSpecificInfo: LKRTCCodecSpecificInfo?,
                       frameTypes: [NSNumber]) -> Int {

        guard let session = session else {
            logger.error("❌ Compression session is nil")
            return -1
        }

        // Extract pixel buffer from frame
        guard let cvPixelBuffer = frame.buffer as? LKRTCCVPixelBuffer else {
            logger.error("❌ Frame buffer is not CVPixelBuffer")
            return -1
        }

        let pixelBuffer = cvPixelBuffer.pixelBuffer

        // Create presentation timestamp
        let timeStampNs = frame.timeStampNs
        let timeStampSeconds = Double(timeStampNs) / 1_000_000_000.0
        let pts = CMTime(seconds: timeStampSeconds, preferredTimescale: 1_000_000_000)

        // Determine if keyframe is requested
        let isKeyframeRequested = frameTypes.contains { $0.intValue == LKRTCFrameType.videoFrameKey.rawValue }

        var frameProperties: [CFString: Any] = [:]
        if isKeyframeRequested {
            frameProperties[kVTEncodeFrameOptionKey_ForceKeyFrame] = true
        }

        // Encode frame
        let encodeStatus = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: .invalid,
            frameProperties: frameProperties as CFDictionary,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )

        if encodeStatus != noErr {
            logger.error("❌ Encode frame failed: \(encodeStatus)")
            return Int(encodeStatus)
        }

        frameCount += 1
        if frameCount % 300 == 0 {
            logger.info("📊 Encoded \(self.frameCount) HEVC frames")
        }

        return 0
    }

    public func setBitrate(_ bitrateKbps: UInt32, framerate: UInt32) -> Int32 {
        logger.info("🎛️ Setting bitrate: \(bitrateKbps) kbps, framerate: \(framerate) fps")

        guard let session = session else {
            return -1
        }

        let bitrateBps = Int(bitrateKbps) * 1000

        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_AverageBitRate,
            value: bitrateBps as CFNumber
        )

        let bytesPerSecond = bitrateBps / 8
        let dataRateLimits = [bytesPerSecond, 1] as CFArray
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_DataRateLimits,
            value: dataRateLimits
        )

        return 0
    }

    public func implementationName() -> String {
        return "VideoToolbox-HEVC"
    }

    public func scalingSettings() -> LKRTCVideoEncoderQpThresholds? {
        return nil
    }

    // MARK: - Private Methods

    private func createCompressionSession(width: Int32, height: Int32, bitrate: Int) -> OSStatus {
        let outputCallback: VTCompressionOutputCallback = { outputCallbackRefCon, sourceFrameRefCon, status, infoFlags, sampleBuffer in
            guard status == noErr, let sampleBuffer = sampleBuffer else {
                return
            }

            let encoder = Unmanaged<HEVCVideoEncoder>.fromOpaque(outputCallbackRefCon!).takeUnretainedValue()
            encoder.handleEncodedFrame(sampleBuffer)
        }

        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_HEVC,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: outputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            return status
        }

        // Configure HEVC properties
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_HEVC_Main_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFNumber)

        let bytesPerSecond = bitrate / 8
        let dataRateLimits = [bytesPerSecond, 1] as CFArray
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_DataRateLimits, value: dataRateLimits)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: 60 as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse) // Disable for lower latency

        VTCompressionSessionPrepareToEncodeFrames(session)

        logger.info("✅ HEVC compression session created: \(width)×\(height) @ \(bitrate) bps")

        return noErr
    }

    private func handleEncodedFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let encoderCallback = self.encoderCallback else {
            logger.error("❌ Encoder callback not set")
            return
        }

        // Check if this is a keyframe
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]]
        let isKeyframe = !(attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool ?? false)

        // Extract parameter sets from format description (VPS/SPS/PPS)
        if isKeyframe, vpsData == nil || spsData == nil || ppsData == nil {
            extractParameterSets(from: sampleBuffer)
        }

        // Extract encoded data
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            logger.error("❌ Failed to get data buffer")
            return
        }

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard status == noErr, let data = dataPointer else {
            logger.error("❌ Failed to get data pointer: \(status)")
            return
        }

        // Convert AVCC format to Annex-B format
        let annexBData = convertToAnnexB(avccData: Data(bytes: data, count: length), isKeyframe: isKeyframe)

        // Create encoded image
        let encodedImage = LKRTCEncodedImage()
        encodedImage.buffer = annexBData
        encodedImage.encodedWidth = Int32(self.width)
        encodedImage.encodedHeight = Int32(self.height)
        encodedImage.frameType = isKeyframe ? .videoFrameKey : .videoFrameDelta

        // Get presentation timestamp
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timeStampNs = UInt64(CMTimeGetSeconds(pts) * 1_000_000_000)
        encodedImage.timeStamp = UInt32(timeStampNs & 0xFFFFFFFF)
        encodedImage.captureTimeMs = Int64(timeStampNs / 1_000_000)

        // Create codec info
        let codecInfo = HEVCCodecInfo()

        // Call encoder callback
        let success = encoderCallback(encodedImage, codecInfo)

        if !success {
            logger.error("❌ Encoder callback failed - frame type: \(isKeyframe ? "KEY" : "DELTA"), size: \(annexBData.count) bytes")
        } else if frameCount % 60 == 0 {
            logger.info("✅ Sent frame #\(self.frameCount): \(isKeyframe ? "KEY" : "DELTA"), \(annexBData.count) bytes")
        }
    }

    // Extract VPS/SPS/PPS from format description
    private func extractParameterSets(from sampleBuffer: CMSampleBuffer) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            logger.error("❌ Failed to get format description")
            return
        }

        // For HEVC, we need VPS (index 0), SPS (index 1), PPS (index 2)
        var parameterSetCount: Int = 0
        let status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
            formatDesc,
            parameterSetIndex: 0,
            parameterSetPointerOut: nil,
            parameterSetSizeOut: nil,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: nil
        )

        guard status == noErr, parameterSetCount >= 3 else {
            logger.error("❌ Failed to get parameter set count: \(status), count: \(parameterSetCount)")
            return
        }

        // Extract VPS (index 0)
        var vpsPointer: UnsafePointer<UInt8>?
        var vpsSize: Int = 0
        CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(formatDesc, parameterSetIndex: 0, parameterSetPointerOut: &vpsPointer, parameterSetSizeOut: &vpsSize, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
        if let vps = vpsPointer {
            vpsData = Data(bytes: vps, count: vpsSize)
            logger.info("📦 Extracted VPS: \(vpsSize) bytes")
        }

        // Extract SPS (index 1)
        var spsPointer: UnsafePointer<UInt8>?
        var spsSize: Int = 0
        CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(formatDesc, parameterSetIndex: 1, parameterSetPointerOut: &spsPointer, parameterSetSizeOut: &spsSize, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
        if let sps = spsPointer {
            spsData = Data(bytes: sps, count: spsSize)
            logger.info("📦 Extracted SPS: \(spsSize) bytes")
        }

        // Extract PPS (index 2)
        var ppsPointer: UnsafePointer<UInt8>?
        var ppsSize: Int = 0
        CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(formatDesc, parameterSetIndex: 2, parameterSetPointerOut: &ppsPointer, parameterSetSizeOut: &ppsSize, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
        if let pps = ppsPointer {
            ppsData = Data(bytes: pps, count: ppsSize)
            logger.info("📦 Extracted PPS: \(ppsSize) bytes")
        }
    }

    // Convert AVCC format to Annex-B format
    // AVCC: [4-byte length][NAL unit][4-byte length][NAL unit]...
    // Annex-B: [0x00 0x00 0x00 0x01][NAL unit][0x00 0x00 0x00 0x01][NAL unit]...
    private func convertToAnnexB(avccData: Data, isKeyframe: Bool) -> Data {
        var annexBData = Data()
        let startCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]

        // For keyframes, prepend VPS/SPS/PPS
        if isKeyframe {
            if let vps = vpsData {
                annexBData.append(contentsOf: startCode)
                annexBData.append(vps)
            }
            if let sps = spsData {
                annexBData.append(contentsOf: startCode)
                annexBData.append(sps)
            }
            if let pps = ppsData {
                annexBData.append(contentsOf: startCode)
                annexBData.append(pps)
            }
        }

        // Convert AVCC NAL units to Annex-B
        var offset = 0
        while offset < avccData.count {
            // Read 4-byte NAL unit length
            guard offset + 4 <= avccData.count else { break }

            let lengthBytes = avccData.subdata(in: offset..<offset+4)
            let nalLength = Int(lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

            offset += 4

            // Read NAL unit data
            guard offset + nalLength <= avccData.count else { break }

            let nalData = avccData.subdata(in: offset..<offset+nalLength)

            // Append start code + NAL unit
            annexBData.append(contentsOf: startCode)
            annexBData.append(nalData)

            offset += nalLength
        }

        return annexBData
    }
}

// MARK: - HEVC Codec Info

private class HEVCCodecInfo: NSObject, LKRTCCodecSpecificInfo {
    // Empty implementation - protocol conformance only
}
