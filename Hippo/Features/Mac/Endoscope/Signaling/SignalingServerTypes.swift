//
//  SignalingServerTypes.swift
//  Hippo
//
//  Types and configuration for embedded signaling server
//

import Foundation

// MARK: - Signaling Server State

public enum SignalingServerState: Equatable {
    case idle
    case starting
    case running(port: UInt16)
    case failed(error: String)
    case stopped
}

// MARK: - Server Configuration

public struct SignalingServerConfiguration {
    public var port: UInt16
    public var serviceName: String
    public var heartbeatInterval: TimeInterval

    public static let `default` = SignalingServerConfiguration(
        port: 8080,
        serviceName: "Hippo-WebRTC-Signaling",
        heartbeatInterval: 30.0
    )

    public init(port: UInt16, serviceName: String, heartbeatInterval: TimeInterval) {
        self.port = port
        self.serviceName = serviceName
        self.heartbeatInterval = heartbeatInterval
    }
}
