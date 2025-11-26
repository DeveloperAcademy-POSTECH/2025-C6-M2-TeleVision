//
//  SignalingConnection.swift
//  Hippo
//
//  Represents a connected WebSocket client to the signaling server
//

import Foundation
import Network

// MARK: - Signaling Connection

/// Represents a connected WebSocket client
final class SignalingConnection: @unchecked Sendable {

    // MARK: - Properties

    let id: UUID
    let connection: NWConnection
    var role: String?
    var isAlive: Bool = true

    // ICE candidate statistics
    var iceCandidatesSent: Int = 0
    var iceCandidatesReceived: Int = 0

    // MARK: - Initialization

    init(connection: NWConnection) {
        self.id = UUID()
        self.connection = connection
    }

    // MARK: - Helpers

    var displayName: String {
        switch role {
        case "sender": return "Mac (Sender)"
        case "receiver": return "Vision Pro (Receiver)"
        default: return "Unknown"
        }
    }
}
