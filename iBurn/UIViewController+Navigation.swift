import UIKit

extension UIViewController {
    /// Walk the view controller hierarchy to find a navigation controller suitable for pushing.
    func findNavigationController() -> UINavigationController? {
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.findNavigationController() ?? nav
        }
        if let tab = self as? UITabBarController,
           let selected = tab.selectedViewController {
            return selected.findNavigationController()
        }
        if let nav = navigationController {
            return nav
        }
        for child in children {
            if let nav = child.findNavigationController() {
                return nav
            }
        }
        return nil
    }

    /// Push a detail view controller by walking the responder chain to find a navigation controller.
    func pushDetailFromAnyContext(_ viewController: UIViewController, animated: Bool = true) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let navController = window.rootViewController?.findNavigationController() else {
            return
        }
        navController.pushViewController(viewController, animated: animated)
    }
}
