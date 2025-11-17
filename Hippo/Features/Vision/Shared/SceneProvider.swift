//
//  SceneProvider.swift
//  Hippo
//
//  Created by 김현기 on 11/17/25.
//

import UIKit

@Observable
class SceneProvider: NSObject, UIWindowSceneDelegate {
    var scene: UIScene? = nil

    func sceneWillEnterForeground(_ scene: UIScene) {
        self.scene = scene
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        self.scene = scene
    }

    func sceneDidDisconnect(_: UIScene) {
        scene = nil
    }
}

@Observable
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options _: UIScene.ConnectionOptions) -> UISceneConfiguration
    {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = SceneProvider.self
        }
        return configuration
    }
}
