// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Lokalise
import Branch
import Moya

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?
    var coordinator: KNAppCoordinator!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        do {
            let keystore = try EtherKeystore()
            coordinator = KNAppCoordinator(window: window!, keystore: keystore)
            coordinator.start()
            coordinator.appDidFinishLaunch()
        } catch {
            print("EtherKeystore init issue.")
        }
        Branch.getInstance().setDebug()
        Branch.getInstance().initSession(launchOptions: launchOptions) { (params, error) in
          if let params = params, error == nil {
            KNNotificationUtil.postNotification(
              for: kIEODidReceiveCallbackNotificationKey,
              object: params,
              userInfo: nil
            )
          }
        }
        KNReachability.shared.startNetworkReachabilityObserver()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        coordinator.appDidBecomeActive()
        KNReachability.shared.startNetworkReachabilityObserver()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        coordinator.appDidEnterBackground()
      KNReachability.shared.stopNetworkReachabilityObserver()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
      self.coordinator.appWillEnterForeground()
    }

    func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplicationExtensionPointIdentifier) -> Bool {
        if extensionPointIdentifier == UIApplicationExtensionPointIdentifier.keyboard {
            return false
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
      Branch.getInstance().handlePushNotification(userInfo)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
      Branch.getInstance().application(app, open: url, options: options)
      return true
    }

    // Respond to URI scheme links
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return true
    }

    // Respond to Universal Links
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
      Branch.getInstance().continue(userActivity)
        return true
    }
}
