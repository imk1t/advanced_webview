import Flutter
import UIKit

/// Entry point. Wires the Pigeon host API and the platform view factory to the
/// engine. All per-WebView state lives in `WebViewRegistry`.
public class MobileWebViewPlugin: NSObject, FlutterPlugin {
  /// Must match `MobileWebView.viewType` on the Dart side.
  static let viewType = "dev.k1t.advanced_webview/webview"

  private let hostApi: WebViewHostApiImpl

  init(hostApi: WebViewHostApiImpl) {
    self.hostApi = hostApi
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let registry = WebViewRegistry()
    let hostApi = WebViewHostApiImpl(
      registry: registry,
      flutterApi: MobileWebViewFlutterApi(binaryMessenger: messenger)
    )
    MobileWebViewHostApiSetup.setUp(binaryMessenger: messenger, api: hostApi)
    registrar.register(MobileWebViewFactory(registry: registry), withId: viewType)
    registrar.publish(MobileWebViewPlugin(hostApi: hostApi))
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    MobileWebViewHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    hostApi.disposeAll()
  }
}
