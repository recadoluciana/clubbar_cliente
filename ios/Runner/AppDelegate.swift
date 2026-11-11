import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let resultado = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Garante o registro nativo no APNs para que o Firebase Messaging receba
    // o token antes de solicitar o token FCM.
    application.registerForRemoteNotifications()
    return resultado
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
