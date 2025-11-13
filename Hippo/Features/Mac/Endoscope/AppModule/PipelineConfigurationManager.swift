//
//  PipelineConfigurationManager.swift
//  Hippo
//
//  P0.2: Actor-based thread-safe configuration management
//  Prevents race conditions during SBS mode changes
//

import Foundation
import CoreGraphics

/// Actor for managing pipeline configuration atomically
/// Ensures thread-safe configuration access across MainActor UI and background processing queues
public actor PipelineConfigurationManager {

    // MARK: Properties

    private var _sbsMode: SBSMode = .full1080
    private var _normalizePolicy: NormalizePolicy = .cropToMatchAspect
    private var _targetBitrate: Int = 30_000_000

    // MARK: - Initialization

    /// Nonisolated initializer allows synchronous creation from any context
    public init() {}

    // MARK: - Getters

    public func getSBSMode() -> SBSMode {
        return _sbsMode
    }

    public func getNormalizePolicy() -> NormalizePolicy {
        return _normalizePolicy
    }

    public func getTargetBitrate() -> Int {
        return _targetBitrate
    }

    // MARK: - Setters

    public func setSBSMode(_ mode: SBSMode) {
        _sbsMode = mode
    }

    public func setNormalizePolicy(_ policy: NormalizePolicy) {
        _normalizePolicy = policy
    }

    public func setTargetBitrate(_ bitrate: Int) {
        _targetBitrate = bitrate
    }

    // MARK: - Atomic Config Creation

    /// Create compositor config atomically
    /// All properties are read in a single atomic operation
    public func makeComposerConfig() -> SBSComposerConfig {
        return SBSComposerConfig(
            mode: _sbsMode,
            policy: _normalizePolicy,
            colorSpace: CGColorSpace(name: CGColorSpace.itur_709)
        )
    }

    /// Get all configuration as snapshot
    public func makeConfigSnapshot() -> ConfigSnapshot {
        return ConfigSnapshot(
            sbsMode: _sbsMode,
            normalizePolicy: _normalizePolicy,
            targetBitrate: _targetBitrate
        )
    }
}

// MARK: - Config Snapshot

/// Immutable configuration snapshot
/// Safe to pass between threads
public struct ConfigSnapshot {
    public let sbsMode: SBSMode
    public let normalizePolicy: NormalizePolicy
    public let targetBitrate: Int

    public nonisolated init(sbsMode: SBSMode, normalizePolicy: NormalizePolicy, targetBitrate: Int) {
        self.sbsMode = sbsMode
        self.normalizePolicy = normalizePolicy
        self.targetBitrate = targetBitrate
    }
}
