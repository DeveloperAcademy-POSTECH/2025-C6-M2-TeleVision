//
//  ReconnectionPolicy.swift
//  Hippo
//
//  P0.3: Automatic reconnection policy with exponential backoff
//

import Foundation

/// Reconnection policy for network failures
/// Implements exponential backoff strategy
public struct ReconnectionPolicy {
    /// Maximum number of reconnection attempts
    public let maxAttempts: Int

    /// Initial delay before first retry (seconds)
    public let initialDelay: TimeInterval

    /// Maximum delay between retries (seconds)
    public let maxDelay: TimeInterval

    /// Backoff multiplier (delay doubles each attempt)
    public let backoffMultiplier: Double

    /// Standard reconnection policy
    /// - 5 attempts max
    /// - 1s → 2s → 4s → 8s → 16s (capped at 30s)
    public static let standard = ReconnectionPolicy(
        maxAttempts: 5,
        initialDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0
    )

    /// Aggressive reconnection (for testing)
    public static let aggressive = ReconnectionPolicy(
        maxAttempts: 10,
        initialDelay: 0.5,
        maxDelay: 10.0,
        backoffMultiplier: 1.5
    )

    /// Conservative reconnection (production)
    public static let conservative = ReconnectionPolicy(
        maxAttempts: 3,
        initialDelay: 2.0,
        maxDelay: 60.0,
        backoffMultiplier: 3.0
    )

    public init(
        maxAttempts: Int,
        initialDelay: TimeInterval,
        maxDelay: TimeInterval,
        backoffMultiplier: Double
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
    }

    /// Calculate delay for a specific attempt
    /// - Parameter attempt: Attempt number (0-based)
    /// - Returns: Delay in seconds, capped at maxDelay
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponentialDelay = initialDelay * pow(backoffMultiplier, Double(attempt))
        return min(exponentialDelay, maxDelay)
    }

    /// Check if more attempts are available
    public func canRetry(currentAttempt: Int) -> Bool {
        return currentAttempt < maxAttempts
    }
}

/// Reconnection state tracking
public enum ReconnectionState: Equatable {
    case idle
    case reconnecting(attempt: Int, nextRetryIn: TimeInterval)
    case exhausted  // Max attempts reached

    public var isReconnecting: Bool {
        if case .reconnecting = self {
            return true
        }
        return false
    }
}
