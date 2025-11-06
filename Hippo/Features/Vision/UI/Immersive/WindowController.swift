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
    
    init(dismissSpace: DismissImmersiveSpaceAction,
         openWindow: OpenWindowAction,
         dismissWindow: DismissWindowAction) {
        self.dismissImmersiveSpaceAction = dismissSpace
        self.openWindowAction = openWindow
        self.dismissWindowAction = dismissWindow
    }
    
    func openWindow(id: String) {
        openWindowAction(id: id)
    }
    
    func dismissWindow(id: String) {
        dismissWindowAction(id: id)
    }
    
    func finishSurgeryAndDismissSpace() async {
        dismissWindowAction(id: WindowIDs.surgeryBottomMenu)
        openWindowAction(id: WindowIDs.home)
        await dismissImmersiveSpaceAction()
    }
}
