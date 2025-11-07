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

    /// Maximum time difference for frame matching (8ms for 60fps)
    private let matchTolerance: CMTime = CMTime(value: 8, timescale: 1000)  // 8ms

    /// Maximum age for buffered frames before dropping (50ms ~= 3 frames at 60fps)
    private let maxFrameAge: CMTime = CMTime(value: 50, timescale: 1000)  // 50ms

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

    // MARK: - Private Methods

    private func handleFrame(_ pb: CVPixelBuffer, pts: CMTime, source: CaptureSource) {
        // Update statistics
        switch source {
        case .left:
            _stats.leftFrameCount += 1
        case .right:
            _stats.rightFrameCount += 1
        }

        // Get frame size
        let width = CVPixelBufferGetWidth(pb)
        let height = CVPixelBufferGetHeight(pb)
        let size = CGSize(width: width, height: height)

        // Add to appropriate buffer
        switch source {
        case .left:
            leftBuffer.append((pb, pts, size))
        case .right:
            rightBuffer.append((pb, pts, size))
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
    /// Optimized O(n) algorithm: match newest frames from each buffer
    private func findMatchingPair() -> SyncedPair? {
        guard !leftBuffer.isEmpty, !rightBuffer.isEmpty else {
            return nil
        }

        // Get the most recent frames from each buffer
        guard let (leftPB, leftPTS, leftSize) = leftBuffer.last,
              let (rightPB, rightPTS, rightSize) = rightBuffer.last else {
            return nil
        }

        // Calculate time delta
        let delta = CMTimeSubtract(leftPTS, rightPTS)
        let deltaSeconds = CMTimeGetSeconds(delta)
        let deltaMs = abs(deltaSeconds * 1000.0)

        // Check if within tolerance
        let toleranceSeconds = CMTimeGetSeconds(matchTolerance)
        let toleranceMs = toleranceSeconds * 1000.0

        if deltaMs <= toleranceMs {
            // Match found!
            // Calculate synchronized PTS (average)
            let syncPTS = CMTimeAdd(leftPTS, rightPTS)
            let avgPTS = CMTimeMultiplyByFloat64(syncPTS, multiplier: 0.5)

            // Remove matched frames from buffers
            leftBuffer.removeLast()
            rightBuffer.removeLast()

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
        }

        return nil
    }

    private func emitPair(_ pair: SyncedPair) {
        onPair?(pair)
    }

    private func dropOldFrames(relativeTo referencePTS: CMTime) {
        let now = referencePTS

        // Drop old left frames
        let oldLeftCount = leftBuffer.count
        leftBuffer.removeAll { item in
            let (_, pts, _) = item
            let age = CMTimeSubtract(now, pts)
            return CMTimeCompare(age, maxFrameAge) > 0
        }
        let leftDropped = oldLeftCount - leftBuffer.count
        if leftDropped > 0 {
            _stats.leftDropCount += leftDropped
            logger.warning("⚠️ Dropped \(leftDropped) old left frames")
        }

        // Drop old right frames
        let oldRightCount = rightBuffer.count
        rightBuffer.removeAll { item in
            let (_, pts, _) = item
            let age = CMTimeSubtract(now, pts)
            return CMTimeCompare(age, maxFrameAge) > 0
        }
        let rightDropped = oldRightCount - rightBuffer.count
        if rightDropped > 0 {
            _stats.rightDropCount += rightDropped
            logger.warning("⚠️ Dropped \(rightDropped) old right frames")
        }
    }

    private func enforceBufferLimit() {
        // Drop oldest frames if buffer exceeds limit
        if leftBuffer.count > maxBufferSize {
            let dropCount = leftBuffer.count - maxBufferSize
            leftBuffer.removeFirst(dropCount)
            _stats.leftDropCount += dropCount
            logger.warning("⚠️ Buffer limit: dropped \(dropCount) left frames")
        }

        if rightBuffer.count > maxBufferSize {
            let dropCount = rightBuffer.count - maxBufferSize
            rightBuffer.removeFirst(dropCount)
            _stats.rightDropCount += dropCount
            logger.warning("⚠️ Buffer limit: dropped \(dropCount) right frames")
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
