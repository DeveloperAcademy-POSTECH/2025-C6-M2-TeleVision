//
//  BonjourServiceDiscovery.swift
//  Hippo
//
//  Bonjour (mDNS) service discovery for WebRTC signaling server
//

import Foundation
import Network
import os.log
import Combine

@MainActor
public final class BonjourServiceDiscovery: ObservableObject {

    @Published public var discoveredServers: [DiscoveredServer] = []
    @Published public var isSearching: Bool = false

    private let logger = Logger(subsystem: "com.television.hippo", category: "BonjourDiscovery")
    private var browser: NWBrowser?

    public struct DiscoveredServer: Identifiable {
        public let id = UUID()
        public let name: String
        public let endpoint: NWEndpoint
        public var url: URL? {
            switch endpoint {
            case .hostPort(let host, let port):
                let hostString: String
                switch host {
                case .ipv4(let address):
                    hostString = address.debugDescription
                case .ipv6(let address):
                    hostString = address.debugDescription
                case .name(let hostname, _):
                    hostString = hostname
                @unknown default:
                    return nil
                }
                return URL(string: "ws://\(hostString):\(port)")
            default:
                return nil
            }
        }
    }

    public init() {}

    /// Start discovering Bonjour services on the local network
    public func startDiscovery() {
        guard !isSearching else {
            logger.warning("⚠️ Already searching for services")
            return
        }

        logger.info("🔍 Starting Bonjour service discovery...")
        isSearching = true
        discoveredServers.removeAll()

        // Create browser for _ws._tcp service type
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: "_ws._tcp", domain: nil), using: parameters)

        browser?.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch newState {
                case .ready:
                    self.logger.info("✅ Bonjour browser ready")
                case .failed(let error):
                    self.logger.error("❌ Bonjour browser failed: \(error.localizedDescription)")
                    self.isSearching = false
                case .cancelled:
                    self.logger.info("🛑 Bonjour browser cancelled")
                    self.isSearching = false
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                for change in changes {
                    switch change {
                    case .added(let result):
                        self.handleServiceAdded(result)
                    case .removed(let result):
                        self.handleServiceRemoved(result)
                    default:
                        break
                    }
                }
            }
        }

        browser?.start(queue: .main)
    }

    /// Stop discovering services
    public func stopDiscovery() {
        logger.info("🛑 Stopping Bonjour service discovery")
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func handleServiceAdded(_ result: NWBrowser.Result) {
        logger.info("🎉 Service discovered: \(result.endpoint.debugDescription)")

        let server = DiscoveredServer(
            name: result.endpoint.debugDescription,
            endpoint: result.endpoint
        )

        if let url = server.url {
            logger.info("   URL: \(url.absoluteString)")
        }

        discoveredServers.append(server)
    }

    private func handleServiceRemoved(_ result: NWBrowser.Result) {
        logger.info("👋 Service removed: \(result.endpoint.debugDescription)")

        discoveredServers.removeAll { server in
            server.endpoint.debugDescription == result.endpoint.debugDescription
        }
    }

    nonisolated deinit {
        Task { @MainActor [weak self] in
            self?.stopDiscovery()
        }
    }
}
