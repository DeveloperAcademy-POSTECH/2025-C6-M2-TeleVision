//
//  FrameSync.swift
//  Hippo
//
//  Synchronizes left/right video frames for stereo pair composition
//  Implements nearest-neighbor matching with ±8ms tolerance
//

import Foundation
import CoreVideo
import CoreMedia
import QuartzCore
import os.log

// MARK: - Frame Syncing Protocol

/// Protocol for frame synchronization
public protocol FrameSyncing: AnyObject {
    /// Push a new frame into the sync buffer
    func push(_ pb: CVPixelBuffer, pts: CMTime, source: CaptureSource)

    /// Callback when a synchronized pair is produced
    var onPair: ((SyncedPair) -> Void)? { get set }

    /// Statistics
    var stats: FrameSyncStats { get }
}

// MARK: - Frame Sync Statistics

public struct FrameSyncStats {
    public var leftFrameCount: Int = 0
    public var rightFrameCount: Int = 0
    public var syncedPairCount: Int = 0
    public var leftDropCount: Int = 0
    public var rightDropCount: Int = 0
    public var averageTimeDelta: Double = 0.0  // ms

    public init() {}
}

// MARK: - Frame Sync Implementation

/// Frame synchronizer using nearest-neighbor matching
/// Tolerance: ±8ms for 60fps stereo sync
///
/// Algorithm:
/// 1. Buffer incoming frames from left/right sources
/// 2. For each new frame, search opposite buffer for closest timestamp match
/// 3. If match found within tolerance, emit SyncedPair
/// 4. Drop old frames that exceed drift tolerance
public final class FrameSync: FrameSyncing {

    // MARK: Configuration

    /// Maximum time difference for frame matching
    /// Set to 500ms to handle large offset between camera start times
    /// (observed: left and right cameras can have ~400ms start time difference)
    private let matchTolerance: CMTime = CMTime(value: 500, timescale: 1000)  // 500ms

    /// Maximum age for buffered frames before dropping
    /// Set to 2 seconds to handle camera start time differences
    private let maxFrameAge: CMTime = CMTime(value: 2000, timescale: 1000)  // 2000ms (2 seconds)

    /// Maximum buffer size per source
    private let maxBufferSize: Int = 10

    // MARK: Properties

    public var onPair: ((SyncedPair) -> Void)?

    private let syncQueue: DispatchQueue
    private let logger = Logger(subsystem: "com.television.hippo", category: "FrameSync")

    // MARK: Frame Buffers

    /// Buffered frames: [(pixelBuffer, pts, size)]
    private var leftBuffer: [(CVPixelBuffer, CMTime, CGSize)] = []
    private var rightBuffer: [(CVPixelBuffer, CMTime, CGSize)] = []

    // MARK: Timestamp Normalization

    /// Reference times for normalizing timestamps from different sources
    /// Each source has its own offset to handle different start times
    private var leftOffset: CFTimeInterval?
    private var rightOffset: CFTimeInterval?

    // MARK: Statistics

    private var _stats = FrameSyncStats()
    public var stats: FrameSyncStats {
        syncQueue.sync { _stats }
    }

    private var lastStatsLog: Date = Date()
    private var timeDeltaAccumulator: Double = 0.0
    private var timeDeltaCount: Int = 0

    // MARK: Initialization

    public init() {
        self.syncQueue = DispatchQueue(
            label: "com.television.hippo.framesync",
            qos: .userInteractive
        )
    }

    // MARK: - Public Methods

    public func push(_ pb: CVPixelBuffer, pts: CMTime, source: CaptureSource) {
        // Check if queue is getting backed up (backpressure)
        let queuedItemsEstimate = syncQueue.sync(flags: .barrier) {
            leftBuffer.count + rightBuffer.count
        }

        // If buffers are near capacity, drop the frame to prevent queue buildup
        if queuedItemsEstimate >= maxBufferSize * 2 - 2 {
            logger.warning("⚠️ Backpressure: Dropping \(source.rawValue) frame (buffers: L=\(self.leftBuffer.count), R=\(self.rightBuffer.count))")
            switch source {
            case .left:
                _stats.leftDropCount += 1
            case .right:
                _stats.rightDropCount += 1
            }
            return
        }

        syncQueue.async { [weak self] in
            self?.handleFrame(pb, pts: pts, source: source)
        }
    }

    /// Reset all buffers and state (call when stopping/restarting streaming)
    public func reset() {
        syncQueue.sync(flags: .barrier) {
            leftBuffer.removeAll()
            rightBuffer.removeAll()
            leftOffset = nil
            rightOffset = nil
            _stats = FrameSyncStats()
            timeDeltaAccumulator = 0.0
            timeDeltaCount = 0
            lastStatsLog = Date()
            logger.info("🔄 FrameSync reset complete")
        }
    }

    // MARK: - Private Methods

    /// Normalizes timestamps relative to each source's first frame
    /// Each source has independent offset to handle different start times
    private func normalizeTimestamp(_ pts: CMTime, source: CaptureSource) -> CMTime {
        let ptsSeconds = CMTimeGetSeconds(pts)

        // Initialize offset for each source independently
        switch source {
        case .left:
            if leftOffset == nil {
                leftOffset = ptsSeconds
                logger.info("🕐 Left offset initialized: \(String(format: "%.3f", ptsSeconds))s")
            }
            let elapsed = ptsSeconds - (leftOffset ?? ptsSeconds)
            let normalized = CMTime(seconds: elapsed, preferredTimescale: 1000000)

            if _stats.leftFrameCount == 1 {
                logger.info("🔄 left first frame: normalized=\(String(format: "%.3f", elapsed))s")
            }

            return normalized

        case .right:
            if rightOffset == nil {
                rightOffset = ptsSeconds
                logger.info("🕐 Right offset initialized: \(String(format: "%.3f", ptsSeconds))s")
            }
            let elapsed = ptsSeconds - (rightOffset ?? ptsSeconds)
            let normalized = CMTime(seconds: elapsed, preferredTimescale: 1000000)

            if _stats.rightFrameCount == 1 {
                logger.info("🔄 right first frame: normalized=\(String(format: "%.3f", elapsed))s")
            }

            return normalized
        }
    }

    private func handleFrame(_ pb: CVPixelBuffer, pts: CMTime, source: CaptureSource) {
        // Update statistics
        switch source {
        case .left:
            _stats.leftFrameCount += 1
        case .right:
            _stats.rightFrameCount += 1
        }

        // Normalize timestamp using arrival time
        let normalizedPTS = normalizeTimestamp(pts, source: source)

        // Get frame size
        let width = CVPixelBufferGetWidth(pb)
        let height = CVPixelBufferGetHeight(pb)
        let size = CGSize(width: width, height: height)

        // Add to appropriate buffer with normalized timestamp
        switch source {
        case .left:
            leftBuffer.append((pb, normalizedPTS, size))
        case .right:
            rightBuffer.append((pb, normalizedPTS, size))
        }

        // Limit buffer size
        enforceBufferLimit()

        // Try to find matching pair
        if let pair = findMatchingPair() {
            emitPair(pair)
        }

        // Drop old frames
        dropOldFrames(relativeTo: pts)

        // Log statistics periodically
        logStatsIfNeeded()
    }

    /// Find matching pair from buffers
    /// FIFO algorithm: match oldest frames from each buffer to handle timing skew
    private func findMatchingPair() -> SyncedPair? {
        guard !leftBuffer.isEmpty, !rightBuffer.isEmpty else {
            return nil
        }

        // RELAXED: Allow matching even with single frames in one buffer
        // This helps when cameras have large start time offsets (e.g., 400ms+)
        // Original guard prevented matching when one camera started late

        // Get the oldest frames from each buffer (FIFO)
        let (leftPB, leftPTS, leftSize) = leftBuffer[0]
        let (rightPB, rightPTS, rightSize) = rightBuffer[0]

        // Calculate time delta
        let delta = CMTimeSubtract(leftPTS, rightPTS)
        let deltaSeconds = CMTimeGetSeconds(delta)
        let deltaMs = abs(deltaSeconds * 1000.0)

        // Check if within tolerance
        let toleranceSeconds = CMTimeGetSeconds(matchTolerance)
        let toleranceMs = toleranceSeconds * 1000.0

        // Debug: Log first few match attempts
        if _stats.syncedPairCount < 3 {
            logger.info("🔍 Match attempt: L_PTS=\(String(format: "%.3f", CMTimeGetSeconds(leftPTS)))s, R_PTS=\(String(format: "%.3f", CMTimeGetSeconds(rightPTS)))s, delta=\(String(format: "%.1f", deltaMs))ms, tolerance=\(String(format: "%.1f", toleranceMs))ms")
        }

        if deltaMs <= toleranceMs {
            // Match found!
            if _stats.syncedPairCount < 3 {
                logger.info("✅ MATCH! Creating synced pair #\(self._stats.syncedPairCount + 1)")
            }

            // Calculate synchronized PTS (average)
            let syncPTS = CMTimeAdd(leftPTS, rightPTS)
            let avgPTS = CMTimeMultiplyByFloat64(syncPTS, multiplier: 0.5)

            // Remove matched frames from buffers
            leftBuffer.removeFirst()
            rightBuffer.removeFirst()

            // Update statistics
            _stats.syncedPairCount += 1
            timeDeltaAccumulator += deltaMs
            timeDeltaCount += 1
            _stats.averageTimeDelta = timeDeltaAccumulator / Double(timeDeltaCount)

            // Create synced pair
            return SyncedPair(
                left: leftPB,
                right: rightPB,
                pts: avgPTS,
                leftSize: leftSize,
                rightSize: rightSize,
                timeDelta: deltaMs
            )
        } else {
            // No match - remove the older frame to prevent buffer buildup
            // Drop the older frame (the one that's further behind)
            if CMTimeCompare(leftPTS, rightPTS) < 0 {
                // Left is older, drop it
                leftBuffer.removeFirst()
                _stats.leftDropCount += 1
            } else {
                // Right is older, drop it
                rightBuffer.removeFirst()
                _stats.rightDropCount += 1
            }
        }

        return nil
    }

    private func emitPair(_ pair: SyncedPair) {
        onPair?(pair)
    }

    private func dropOldFrames(relativeTo referencePTS: CMTime) {
        // Only drop frames if both buffers have content
        // This prevents dropping all frames when one camera starts later
        guard !leftBuffer.isEmpty && !rightBuffer.isEmpty else {
            return
        }

        // Get the newest timestamp from each buffer
        let newestLeft = leftBuffer.last?.1 ?? referencePTS
        let newestRight = rightBuffer.last?.1 ?? referencePTS

        // Use the older of the two newest timestamps as reference
        // This ensures we keep frames that could still potentially match
        let dropThreshold = CMTimeCompare(newestLeft, newestRight) < 0 ? newestLeft : newestRight

        // Drop left frames that are too old relative to the drop threshold
        let oldLeftCount = leftBuffer.count
        leftBuffer.removeAll { item in
            let (_, pts, _) = item
            let age = CMTimeSubtract(dropThreshold, pts)
            return CMTimeCompare(age, maxFrameAge) > 0
        }
        let leftDropped = oldLeftCount - leftBuffer.count
        if leftDropped > 0 {
            _stats.leftDropCount += leftDropped
        }

        // Drop right frames that are too old relative to the drop threshold
        let oldRightCount = rightBuffer.count
        rightBuffer.removeAll { item in
            let (_, pts, _) = item
            let age = CMTimeSubtract(dropThreshold, pts)
            return CMTimeCompare(age, maxFrameAge) > 0
        }
        let rightDropped = oldRightCount - rightBuffer.count
        if rightDropped > 0 {
            _stats.rightDropCount += rightDropped
        }
    }

    private func enforceBufferLimit() {
        // Drop oldest frames if buffer exceeds limit
        if leftBuffer.count > maxBufferSize {
            let dropCount = leftBuffer.count - maxBufferSize
            leftBuffer.removeFirst(dropCount)
            _stats.leftDropCount += dropCount
        }

        if rightBuffer.count > maxBufferSize {
            let dropCount = rightBuffer.count - maxBufferSize
            rightBuffer.removeFirst(dropCount)
            _stats.rightDropCount += dropCount
        }
    }

    private func logStatsIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastStatsLog) >= 5.0 {  // Every 5 seconds
            logger.info("""
            📊 FrameSync Stats:
               Left: \(self._stats.leftFrameCount) frames, \(self._stats.leftDropCount) dropped
               Right: \(self._stats.rightFrameCount) frames, \(self._stats.rightDropCount) dropped
               Synced: \(self._stats.syncedPairCount) pairs
               Avg delta: \(String(format: "%.2f", self._stats.averageTimeDelta))ms
               Buffer: L=\(self.leftBuffer.count), R=\(self.rightBuffer.count)
            """)
            lastStatsLog = now
        }
    }
}
