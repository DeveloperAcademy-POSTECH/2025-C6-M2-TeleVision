import Foundation

public protocol ImmersiveControlling {
    func enterImmersive() async
    func exitImmersive() async
}

final class ImmersiveCoordinator: ImmersiveControlling {
    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
    }

    func enterImmersive() async {
        await router.open()
    }

    func exitImmersive() async {
        await router.close()
    }
}
