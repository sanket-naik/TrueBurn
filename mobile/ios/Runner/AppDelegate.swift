import Flutter
import UIKit
// Required to reach FlutterLocalNotificationsPlugin.setPluginRegistrantCallback.
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Without this, iOS never routes notification responses to the plugin, so tapping
    // Done on the lock screen does nothing at all. It fails quietly — the notification
    // still appears and still dismisses, which makes it look like the feature works.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // This project uses the UIScene lifecycle, so the registrant callback belongs here
  // rather than in didFinishLaunchingWithOptions.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // The Done action runs in a **separate background isolate**, which starts with no
    // plugins registered. Without this callback `shared_preferences` does not exist
    // there, the completion queue is never written, and every lock-screen tick is lost
    // — the exact iOS counterpart of the missing Android broadcast receivers, and just
    // as silent. See lib/notifications.dart.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
