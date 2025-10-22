//
//  AppRouter.swift
//  Hippo
//
//  Created by eunsong on 10/22/25.
//

import Foundation

public struct AppRouter {
    public let open: @Sendable () async -> Void
    public let close: @Sendable () async -> Void
}

extension AppRouter {
    static let live: AppRouter = .init(
        open: {},
        close: {}
    )
}
