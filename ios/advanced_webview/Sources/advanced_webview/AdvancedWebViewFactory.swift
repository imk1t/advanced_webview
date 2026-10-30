import Flutter
import UIKit

/// The native WebView is created ahead of time by `AdvancedWebViewHostApi.create`;
/// the factory only looks it up by `webViewId` and attaches it.
final class AdvancedWebViewFactory: NSObject, FlutterPlatformViewFactory {
  private let registry: WebViewRegistry

  init(registry: WebViewRegistry) {
    self.registry = registry
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    guard let params = args as? [String: Any],
      let webViewId = (params["webViewId"] as? NSNumber)?.int64Value,
      let instance = try? registry.get(webViewId)
    else {
      fatalError("AdvancedWebView: create() was not called before the platform view was built")
    }
    return instance
  }
}
