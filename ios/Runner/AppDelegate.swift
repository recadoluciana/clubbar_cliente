import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var estadoAPNs = "Aguardando resposta da Apple."
  private var canalDiagnostico: FlutterMethodChannel?
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
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ClubbarAPNsDiagnostico") else { return }
    let canal = FlutterMethodChannel(name: "clubbar/apns_diagnostico", binaryMessenger: registrar.messenger())
    canal.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(FlutterError(code: "unavailable", message: "Diagnóstico indisponível", details: nil)); return }
      switch call.method {
      case "registrar":
        self.estadoAPNs = "Aguardando resposta da Apple."
        UIApplication.shared.registerForRemoteNotifications()
        result(nil)
      case "estado": result(self.estadoAPNs)
      default: result(FlutterMethodNotImplemented)
      }
    }
    canalDiagnostico = canal
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    estadoAPNs = "O iPhone recebeu o token APNs, mas o Firebase ainda não o disponibilizou."
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    let detalhe = error as NSError
    estadoAPNs = "Falha APNs: \(detalhe.domain) (código \(detalhe.code)): \(detalhe.localizedDescription)"
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
