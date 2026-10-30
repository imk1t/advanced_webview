import Flutter
import UIKit

/// Entry point. Wires the Pigeon host API and the platform view factory to the
/// engine. All per-WebView state lives in `WebViewRegistry`.
public class AdvancedWebViewPlugin: NSObject, FlutterPlugin {
  /// Must match `AdvancedWebView.viewType` on the Dart side.
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
      flutterApi: AdvancedWebViewFlutterApi(binaryMessenger: messenger)
    )
    AdvancedWebViewHostApiSetup.setUp(binaryMessenger: messenger, api: hostApi)
    registrar.register(AdvancedWebViewFactory(registry: registry), withId: viewType)
    registrar.publish(AdvancedWebViewPlugin(hostApi: hostApi))
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    AdvancedWebViewHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    hostApi.disposeAll()
  }
}
