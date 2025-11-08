//
//  WindowController.swift
//  HippoVision
//
//  Created by yunsly on 11/6/25.
//

import SwiftUI

@Observable
final class WindowController {
    private let dismissImmersiveSpaceAction: DismissImmersiveSpaceAction
    private let openWindowAction: OpenWindowAction
    private let dismissWindowAction: DismissWindowAction
    private var pushWindowAction: PushWindowAction?
    
    init(dismissSpace: DismissImmersiveSpaceAction,
         openWindow: OpenWindowAction,
         dismissWindow: DismissWindowAction, pushWindowAction: PushWindowAction? = nil) {
        self.dismissImmersiveSpaceAction = dismissSpace
        self.openWindowAction = openWindow
        self.dismissWindowAction = dismissWindow
        self.pushWindowAction = pushWindowAction
    }
    
    func openWindow(id: String) {
        openWindowAction(id: id)
    }
    
    func dismissWindow(id: String) {
        dismissWindowAction(id: id)
    }
    
    func pushWindow(id: String) {
        guard let pushWindowAction = pushWindowAction else { return }
        pushWindowAction(id: id)
    }
    
    func finishSurgeryAndDismissSpace() async {
        dismissWindowAction(id: WindowIDs.surgeryBottomMenu)
        openWindowAction(id: WindowIDs.home)
        await dismissImmersiveSpaceAction()
    }
}
