//
//  HEVCVideoDecoder.swift
//  Hippo
//
//  VideoToolbox-based HEVC decoder for LiveKit WebRTC (Vision Pro)
//  Implements LKRTCVideoDecoder protocol
//

import Foundation
import LiveKitWebRTC
import VideoToolbox
import CoreMedia
import CoreVideo
import os.log

// Notification for decoded frames (workaround for LiveKit routing issue)
extension Notification.Name {
    static let hevcFrameDecoded = Notification.Name("HEVCFrameDecoded")
}

// MARK: - HEVC Video Decoder

/// VideoToolbox-based HEVC decoder with proper NAL unit parsing
public class HEVCVideoDecoder: NSObject, LKRTCVideoDecoder {

    private let logger = Logger(subsystem: "com.television.hippo", category: "HEVCDecoder")

    // Decompression session
    private var session: VTDecompressionSession?

    // Decoder callback
    private var decoderCallback: RTCVideoDecoderCallback?

    // Frame counters
    private var frameCount: Int = 0  // Frames submitted to VideoToolbox
    private var framesDelivered: Int = 0  // Frames actually decoded and delivered
    private var decompressionErrors: Int = 0  // Count of decompression errors

    // Format description
    private var formatDescription: CMVideoFormatDescription?

    public override init() {
        super.init()
        logger.info("🎬 HEVC Video Decoder initialized")
    }

    deinit {
        if let session = session {
            VTDecompressionSessionInvalidate(session)
        }
        logger.info("🗑️ HEVC Video Decoder deinitialized")
    }

    // MARK: - LKRTCVideoDecoder Protocol

    public func setCallback(_ callback: @escaping RTCVideoDecoderCallback) {
        self.decoderCallback = callback
        logger.info("✅ Decoder callback set")
    }

    public func startDecode(withNumberOfCores numberOfCores: Int32) -> Int {
        logger.info("🚀 Starting HEVC decoder with \(numberOfCores) cores")
        return 0
    }

    public func startDecode(with settings: Any?, numberOfCores cores: Int32) -> Int {
        logger.info("🚀 Starting HEVC decoder")
        return 0
    }

    public func release() -> Int {
        logger.info("🛑 Releasing HEVC decoder")

        if let session = session {
            VTDecompressionSessionInvalidate(session)
            self.session = nil
        }

        formatDescription = nil
        return 0
    }

    public func decode(_ encodedImage: LKRTCEncodedImage,
                       missingFrames: Bool,
                       codecSpecificInfo: (any LKRTCCodecSpecificInfo)?,
                       renderTimeMs: Int64) -> Int {

        guard let encodedData = encodedImage.buffer as Data? else {
            logger.error("❌ Encoded data is nil")
            return -1
        }

        // Check if this is a keyframe
        let isKeyframe = (encodedImage.frameType == .videoFrameKey)

        // Extract parameter sets from keyframe if needed
        if isKeyframe, formatDescription == nil {
            guard extractParameterSets(from: encodedData) == noErr else {
                logger.error("❌ Failed to extract parameter sets")
                return -1
            }
        }

        // Create decompression session if needed
        if session == nil {
            guard let formatDesc = formatDescription else {
                logger.error("❌ Format description not available yet")
                return -1
            }

            let createStatus = createDecompressionSession(formatDesc: formatDesc)
            if createStatus != noErr {
                logger.error("❌ Failed to create decompression session: \(createStatus)")
                return Int(createStatus)
            }
        }

        guard let session = session else {
            logger.error("❌ Session is nil")
            return -1
        }

        // Convert Annex-B to AVCC format for VideoToolbox
        let avccData = convertToAVCC(annexBData: encodedData)

        // Log conversion for first few frames
        if frameCount < 10 {
            logger.info("🔄 Frame #\(self.frameCount): AnnexB=\(encodedData.count) bytes → AVCC=\(avccData.count) bytes, keyframe=\(isKeyframe)")
        }

        // Check if conversion produced valid data
        if avccData.isEmpty {
            logger.error("❌ AVCC conversion produced empty data (AnnexB size: \(encodedData.count))")
            return -1
        }

        // Create CMBlockBuffer
        var blockBuffer: CMBlockBuffer?
        let blockStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: avccData.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: avccData.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard blockStatus == noErr, let blockBuffer = blockBuffer else {
            logger.error("❌ Failed to create block buffer: \(blockStatus)")
            return Int(blockStatus)
        }

        // Copy data to block buffer
        let appendStatus = CMBlockBufferReplaceDataBytes(
            with: (avccData as NSData).bytes,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: avccData.count
        )

        guard appendStatus == noErr else {
            logger.error("❌ Failed to append data: \(appendStatus)")
            return Int(appendStatus)
        }

        // Create sample buffer
        var sampleBuffer: CMSampleBuffer?
        let pts = CMTime(value: Int64(encodedImage.timeStamp), timescale: 1_000_000_000)
        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )

        let sampleStatus = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleStatus == noErr, let sampleBuffer = sampleBuffer else {
            logger.error("❌ Failed to create sample buffer: \(sampleStatus)")
            return Int(sampleStatus)
        }

        // Decode frame
        var infoFlags: VTDecodeInfoFlags = []
        let decodeStatus = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [],
            frameRefcon: nil,
            infoFlagsOut: &infoFlags
        )

        if decodeStatus != noErr {
            logger.error("❌ Decode frame failed: \(decodeStatus)")
            return Int(decodeStatus)
        }

        frameCount += 1
        if frameCount % 60 == 0 {
            logger.info("📊 Decoded \(self.frameCount) HEVC frames")
        }

        return 0
    }

    public func implementationName() -> String {
        return "VideoToolbox-HEVC"
    }

    // MARK: - Private Methods

    // Extract VPS/SPS/PPS from Annex-B keyframe
    private func extractParameterSets(from annexBData: Data) -> OSStatus {
        var vpsData: Data?
        var spsData: Data?
        var ppsData: Data?

        // Parse Annex-B NAL units (support both 3-byte and 4-byte start codes)
        let startCode4: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        let startCode3: [UInt8] = [0x00, 0x00, 0x01]
        var offset = 0

        while offset < annexBData.count {
            // Find start code (either 4-byte or 3-byte)
            var startCodeLength = 0

            if offset + 4 <= annexBData.count {
                let potential4 = annexBData.subdata(in: offset..<offset+4)
                if potential4 == Data(startCode4) {
                    startCodeLength = 4
                } else if offset + 3 <= annexBData.count {
                    let potential3 = annexBData.subdata(in: offset..<offset+3)
                    if potential3 == Data(startCode3) {
                        startCodeLength = 3
                    }
                }
            } else if offset + 3 <= annexBData.count {
                let potential3 = annexBData.subdata(in: offset..<offset+3)
                if potential3 == Data(startCode3) {
                    startCodeLength = 3
                }
            }

            if startCodeLength == 0 {
                offset += 1
                continue
            }

            // Skip start code
            offset += startCodeLength
            guard offset < annexBData.count else { break }

            // Find next start code (either 4-byte or 3-byte)
            var nextOffset = offset
            while nextOffset < annexBData.count {
                var foundNext = false

                if nextOffset + 4 <= annexBData.count {
                    let next4 = annexBData.subdata(in: nextOffset..<nextOffset+4)
                    if next4 == Data(startCode4) {
                        foundNext = true
                    } else if nextOffset + 3 <= annexBData.count {
                        let next3 = annexBData.subdata(in: nextOffset..<nextOffset+3)
                        if next3 == Data(startCode3) {
                            foundNext = true
                        }
                    }
                } else if nextOffset + 3 <= annexBData.count {
                    let next3 = annexBData.subdata(in: nextOffset..<nextOffset+3)
                    if next3 == Data(startCode3) {
                        foundNext = true
                    }
                }

                if foundNext {
                    break
                }
                nextOffset += 1
            }

            // Extract NAL unit
            let nalUnit = annexBData.subdata(in: offset..<nextOffset)
            guard !nalUnit.isEmpty else {
                offset = nextOffset
                continue
            }

            // Check NAL unit type (first byte)
            let nalHeader = nalUnit[0]
            let nalType = (nalHeader >> 1) & 0x3F  // HEVC NAL unit type

            switch nalType {
            case 32: // VPS
                // Keep full NAL unit (including 2-byte header) - CMVideoFormatDescription needs it
                vpsData = nalUnit
                logger.info("📦 Extracted VPS: \(nalUnit.count) bytes")
            case 33: // SPS
                spsData = nalUnit
                logger.info("📦 Extracted SPS: \(nalUnit.count) bytes")
            case 34: // PPS
                ppsData = nalUnit
                logger.info("📦 Extracted PPS: \(nalUnit.count) bytes")
            default:
                break
            }

            offset = nextOffset
        }

        // Verify we got all parameter sets
        guard let vps = vpsData, let sps = spsData, let pps = ppsData else {
            logger.error("❌ Missing parameter sets - VPS: \(vpsData != nil), SPS: \(spsData != nil), PPS: \(ppsData != nil)")
            return -1
        }

        // Create format description from parameter sets
        // IMPORTANT: Must use pointers within withUnsafeBytes scope!
        var formatDesc: CMVideoFormatDescription?
        let status = vps.withUnsafeBytes { vpsBytes in
            sps.withUnsafeBytes { spsBytes in
                pps.withUnsafeBytes { ppsBytes in
                    let parameterSetPointers: [UnsafePointer<UInt8>] = [
                        vpsBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        spsBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        ppsBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    ]
                    let parameterSetSizes: [Int] = [vps.count, sps.count, pps.count]

                    return parameterSetPointers.withUnsafeBufferPointer { pointers in
                        parameterSetSizes.withUnsafeBufferPointer { sizes in
                            CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                                allocator: kCFAllocatorDefault,
                                parameterSetCount: 3,
                                parameterSetPointers: pointers.baseAddress!,
                                parameterSetSizes: sizes.baseAddress!,
                                nalUnitHeaderLength: 4,
                                extensions: nil,
                                formatDescriptionOut: &formatDesc
                            )
                        }
                    }
                }
            }
        }

        if status == noErr, let desc = formatDesc {
            formatDescription = desc
            let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
            logger.info("✅ Format description created: \(dimensions.width)×\(dimensions.height)")
        } else {
            logger.error("❌ Failed to create format description from parameter sets: \(status)")
        }

        return status
    }

    // Convert Annex-B to AVCC format (strip parameter sets, convert start codes to lengths)
    private func convertToAVCC(annexBData: Data) -> Data {
        var avccData = Data()
        let startCode4: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        let startCode3: [UInt8] = [0x00, 0x00, 0x01]
        var offset = 0
        var nalUnitCount = 0
        var skippedParamSets = 0

        while offset < annexBData.count {
            // Find start code (either 4-byte or 3-byte)
            var startCodeLength = 0

            if offset + 4 <= annexBData.count {
                let potential4 = annexBData.subdata(in: offset..<offset+4)
                if potential4 == Data(startCode4) {
                    startCodeLength = 4
                } else if offset + 3 <= annexBData.count {
                    let potential3 = annexBData.subdata(in: offset..<offset+3)
                    if potential3 == Data(startCode3) {
                        startCodeLength = 3
                    }
                }
            } else if offset + 3 <= annexBData.count {
                let potential3 = annexBData.subdata(in: offset..<offset+3)
                if potential3 == Data(startCode3) {
                    startCodeLength = 3
                }
            }

            if startCodeLength == 0 {
                offset += 1
                continue
            }

            // Skip start code
            offset += startCodeLength
            guard offset < annexBData.count else { break }

            // Find next start code (either 4-byte or 3-byte)
            var nextOffset = offset
            while nextOffset < annexBData.count {
                var foundNext = false

                if nextOffset + 4 <= annexBData.count {
                    let next4 = annexBData.subdata(in: nextOffset..<nextOffset+4)
                    if next4 == Data(startCode4) {
                        foundNext = true
                    } else if nextOffset + 3 <= annexBData.count {
                        let next3 = annexBData.subdata(in: nextOffset..<nextOffset+3)
                        if next3 == Data(startCode3) {
                            foundNext = true
                        }
                    }
                } else if nextOffset + 3 <= annexBData.count {
                    let next3 = annexBData.subdata(in: nextOffset..<nextOffset+3)
                    if next3 == Data(startCode3) {
                        foundNext = true
                    }
                }

                if foundNext {
                    break
                }
                nextOffset += 1
            }

            // Extract NAL unit
            let nalUnit = annexBData.subdata(in: offset..<nextOffset)
            guard !nalUnit.isEmpty else {
                offset = nextOffset
                continue
            }

            // Check NAL unit type
            let nalHeader = nalUnit[0]
            let nalType = (nalHeader >> 1) & 0x3F

            // Skip parameter sets (VPS/SPS/PPS) - they're already in format description
            if nalType == 32 || nalType == 33 || nalType == 34 {
                skippedParamSets += 1
                offset = nextOffset
                continue
            }

            // Write NAL unit length (4 bytes big-endian) + NAL unit data
            var nalLength = UInt32(nalUnit.count).bigEndian
            avccData.append(Data(bytes: &nalLength, count: 4))
            avccData.append(nalUnit)
            nalUnitCount += 1

            offset = nextOffset
        }

        // Log conversion details for first few frames
        if frameCount < 10 {
            logger.debug("   → Found \(nalUnitCount) NAL units, skipped \(skippedParamSets) param sets")
        }

        return avccData
    }

    private func createDecompressionSession(formatDesc: CMVideoFormatDescription) -> OSStatus {
        var outputCallback = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: { decompressionOutputRefCon, sourceFrameRefCon, status, infoFlags, imageBuffer, presentationTimeStamp, presentationDuration in
                let decoder = Unmanaged<HEVCVideoDecoder>.fromOpaque(decompressionOutputRefCon!).takeUnretainedValue()

                // Log callback invocation
                if status != noErr {
                    decoder.decompressionErrors += 1
                    // Log first few errors with details, then periodically
                    if decoder.decompressionErrors <= 3 || decoder.decompressionErrors % 30 == 0 {
                        decoder.logger.error("❌ Decompression callback error: \(status), infoFlags: \(infoFlags.rawValue), total errors: \(decoder.decompressionErrors)")
                    }
                    return
                }

                guard let imageBuffer = imageBuffer else {
                    decoder.logger.error("❌ Decompression callback: imageBuffer is nil, infoFlags: \(infoFlags.rawValue)")
                    return
                }

                decoder.handleDecodedFrame(imageBuffer, pts: presentationTimeStamp)
            },
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        let pixelBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,  // NV12 for better performance (was BGRA)
            kCVPixelBufferMetalCompatibilityKey: true
        ]

        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDesc,
            decoderSpecification: nil,
            imageBufferAttributes: pixelBufferAttributes as CFDictionary,
            outputCallback: &outputCallback,
            decompressionSessionOut: &session
        )

        if status == noErr {
            logger.info("✅ HEVC decompression session created")
        } else {
            logger.error("❌ Failed to create decompression session: \(status)")
        }

        return status
    }

    private func handleDecodedFrame(_ pixelBuffer: CVPixelBuffer, pts: CMTime) {
        guard let decoderCallback = self.decoderCallback else {
            logger.error("❌ Decoder callback not set")
            return
        }

        // Create LiveKit pixel buffer wrapper
        let rtcPixelBuffer = LKRTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let timeStampNs = CMTimeGetSeconds(pts) * 1_000_000_000

        // Log pixel buffer details
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

        if framesDelivered == 0 {
            logger.info("📦 Creating VideoFrame: \(width)×\(height), format=\(format), pts=\(Int64(timeStampNs))")
        }

        let videoFrame = LKRTCVideoFrame(
            buffer: rtcPixelBuffer,
            rotation: ._0,
            timeStampNs: Int64(timeStampNs)
        )

        // Call LiveKit decoder callback
        decoderCallback(videoFrame)

        // WORKAROUND: Post notification to bypass LiveKit routing issue
        NotificationCenter.default.post(
            name: .hevcFrameDecoded,
            object: nil,
            userInfo: ["frame": videoFrame, "pixelBuffer": pixelBuffer]
        )

        framesDelivered += 1
        if framesDelivered == 1 {
            logger.info("✅ First frame delivered to LiveKit: \(width)×\(height)")
            logger.info("📢 Posted notification workaround")
        } else if framesDelivered % 60 == 0 {
            logger.info("✅ Delivered \(self.framesDelivered) frames to LiveKit (submitted: \(self.frameCount))")
        }
    }
}
