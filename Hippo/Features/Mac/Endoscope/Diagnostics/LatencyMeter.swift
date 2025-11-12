//
//  LatencyMeter.swift
//  Hippo
//
//  Latency measurement tool for video pipeline diagnostics
//

import Foundation
import CoreMedia
import os.log

/// Latency measurement points
public enum LatencyPoint {
    case capture
    case sync
    case compose
    case encode
}

/// Latency measurement for a single frame
public struct FrameLatency {
    public let pts: CMTime
    public let captureToSync: TimeInterval?
    public let syncToCompose: TimeInterval?
    public let composeToEncode: TimeInterval?
    public let totalLatency: TimeInterval?

    public init(
        pts: CMTime,
        captureToSync: TimeInterval? = nil,
        syncToCompose: TimeInterval? = nil,
        composeToEncode: TimeInterval? = nil
    ) {
        self.pts = pts
        self.captureToSync = captureToSync
        self.syncToCompose = syncToCompose
        self.composeToEncode = composeToEncode

        // Calculate total
        var total: TimeInterval = 0
        if let captureToSync = captureToSync { total += captureToSync }
        if let syncToCompose = syncToCompose { total += syncToCompose }
        if let composeToEncode = composeToEncode { total += composeToEncode }
        self.totalLatency = total > 0 ? total : nil
    }
}

/// Latency meter for tracking pipeline performance
public final class LatencyMeter {

    private var timestamps: [CMTime: [LatencyPoint: Date]] = [:]
    private let logger = Logger(subsystem: "com.television.hippo", category: "Latency")

    private let maxTrackedFrames = 100

    public init() {}

    /// Record timestamp for a specific point in the pipeline
    public func record(pts: CMTime, point: LatencyPoint) {
        let now = Date()

        if timestamps[pts] == nil {
            timestamps[pts] = [:]
        }

        timestamps[pts]?[point] = now

        // Cleanup old frames
        if timestamps.count > maxTrackedFrames {
            let sorted = timestamps.keys.sorted { CMTimeCompare($0, $1) < 0 }
            if let oldest = sorted.first {
                timestamps.removeValue(forKey: oldest)
            }
        }
    }

    /// Get latency measurement for a frame
    public func getLatency(for pts: CMTime) -> FrameLatency? {
        guard let points = timestamps[pts] else {
            return nil
        }

        var captureToSync: TimeInterval?
        var syncToCompose: TimeInterval?
        var composeToEncode: TimeInterval?

        if let capture = points[.capture], let sync = points[.sync] {
            captureToSync = sync.timeIntervalSince(capture) * 1000  // ms
        }

        if let sync = points[.sync], let compose = points[.compose] {
            syncToCompose = compose.timeIntervalSince(sync) * 1000
        }

        if let compose = points[.compose], let encode = points[.encode] {
            composeToEncode = encode.timeIntervalSince(compose) * 1000
        }

        return FrameLatency(
            pts: pts,
            captureToSync: captureToSync,
            syncToCompose: syncToCompose,
            composeToEncode: composeToEncode
        )
    }

    /// Log latency statistics
    public func logStats() {
        let latencies = timestamps.keys.compactMap { getLatency(for: $0) }

        guard !latencies.isEmpty else {
            return
        }

        let avgTotal = latencies.compactMap { $0.totalLatency }.reduce(0, +) / Double(latencies.count)

        logger.info("""
        📊 Latency Stats (last \(latencies.count) frames):
           Total: \(String(format: "%.1f", avgTotal))ms
        """)
    }
}
