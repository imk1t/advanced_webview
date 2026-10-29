import Flutter
import UIKit
import WebKit

/// One native WKWebView plus the delegates that forward its callbacks to Dart.
final class MobileWebView: NSObject, FlutterPlatformView {
  let id: Int64
  let webView: WKWebView

  private let flutterApi: MobileWebViewFlutterApi
  private let hasNavigationDelegate: Bool
  private var observations: [NSKeyValueObservation] = []
  private var isDestroyed = false
  /// URL of the load started by `load(_:)` / `loadHTMLString(_:baseURL:)`
  /// whose policy decision has not arrived yet.
  private var pendingAppInitiatedURL: String?

  init(params: CreationParamsMessage, flutterApi: MobileWebViewFlutterApi) {
    self.id = params.webViewId
    self.flutterApi = flutterApi
    self.hasNavigationDelegate = params.hasNavigationDelegate

    // Some WKWebView options can only be set at creation time.
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = params.settings.allowsInlineMediaPlayback
    configuration.mediaTypesRequiringUserActionForPlayback =
      params.settings.mediaPlaybackRequiresUserGesture ? .all : []
    self.webView = WKWebView(frame: .zero, configuration: configuration)
    super.init()

    webView.navigationDelegate = self
    apply(settings: params.settings)
    params.javaScriptChannelNames.forEach(addJavaScriptChannel)
    observeProperties()
  }

  func view() -> UIView {
    return webView
  }

  func apply(settings: WebViewSettingsMessage) {
    webView.configuration.defaultWebpagePreferences.allowsContentJavaScript =
      settings.javaScriptEnabled
    webView.customUserAgent = settings.userAgent
    webView.isOpaque = !settings.transparentBackground
    webView.backgroundColor = settings.transparentBackground ? .clear : .white
    webView.scrollView.backgroundColor = webView.backgroundColor
  }

  /// Loads a request started by the app. Like Android, it does not consult
  /// the navigation delegate.
  func load(_ request: URLRequest) {
    pendingAppInitiatedURL = request.url?.absoluteString
    webView.load(request)
  }

  /// Loads an HTML string started by the app without consulting the
  /// navigation delegate.
  func loadHTMLString(_ html: String, baseURL: URL?) {
    pendingAppInitiatedURL = (baseURL ?? URL(string: "about:blank"))?.absoluteString
    webView.loadHTMLString(html, baseURL: baseURL)
  }

  func evaluateJavaScript(_ source: String) async throws -> String? {
    // The completion-handler API is used on purpose: the async overload
    // cannot represent `undefined`/`null` results.
    let result: Any? = try await withCheckedThrowingContinuation { continuation in
      webView.evaluateJavaScript(source) { value, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: value)
        }
      }
    }
    guard let value = result, !(value is NSNull) else { return nil }
    let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
    return String(data: data, encoding: .utf8)
  }

  func destroy() {
    guard !isDestroyed else { return }
    isDestroyed = true
    observations.removeAll()
    webView.stopLoading()
    webView.navigationDelegate = nil
    webView.configuration.userContentController.removeAllScriptMessageHandlers()
  }

  private func addJavaScriptChannel(_ name: String) {
    let controller = webView.configuration.userContentController
    controller.add(WeakScriptMessageHandler(self), name: name)
    // Expose the same `window.<name>.postMessage(String)` shape as Android.
    let source = """
      window['\(name)'] = { postMessage: function(m) { \
      window.webkit.messageHandlers['\(name)'].postMessage(String(m)); } };
      """
    controller.addUserScript(
      WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false))
  }

  private func observeProperties() {
    observations = [
      webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
        let progress = Int64((webView.estimatedProgress * 100).rounded())
        self?.send { api, id in try await api.onProgressChanged(webViewId: id, progress: progress) }
      },
      webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
        let title = webView.title
        self?.send { api, id in try await api.onTitleChanged(webViewId: id, title: title) }
      },
    ]
  }

  /// Fire-and-forget call into Dart. Failures are logged, never thrown.
  private func send(_ block: @escaping (MobileWebViewFlutterApi, Int64) async throws -> Void) {
    let api = flutterApi
    let id = self.id
    Task { @MainActor [weak self] in
      guard let self = self, !self.isDestroyed else { return }
      do {
        try await block(api, id)
      } catch {
        NSLog("MobileWebView: failed to deliver event to Dart: \(error)")
      }
    }
  }

  private func reportError(_ error: Error, url: URL?) {
    let nsError = error as NSError
    // Navigations cancelled by us (e.g. a delegate decision) are not errors.
    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
    let message = WebResourceErrorMessage(
      errorCode: Int64(nsError.code),
      message: nsError.localizedDescription,
      isMainFrame: true,
      url: url?.absoluteString
    )
    send { api, id in try await api.onReceivedError(webViewId: id, error: message) }
  }
}

extension MobileWebView: WKNavigationDelegate {
  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    let url = webView.url?.absoluteString ?? ""
    send { api, id in try await api.onPageStarted(webViewId: id, url: url) }
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let url = webView.url?.absoluteString ?? ""
    send { api, id in try await api.onPageFinished(webViewId: id, url: url) }
  }

  func webView(
    _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
  ) {
    reportError(error, url: webView.url)
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    reportError(error, url: webView.url)
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    // Same rules as Android: only main-frame navigations started by the page
    // reach Dart. App-initiated loads, reloads and back/forward never do.
    let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
    guard hasNavigationDelegate, isMainFrame, let url = navigationAction.request.url else {
      decisionHandler(.allow)
      return
    }
    if let pending = pendingAppInitiatedURL, pending == url.absoluteString {
      pendingAppInitiatedURL = nil
      decisionHandler(.allow)
      return
    }
    if navigationAction.navigationType == .reload
      || navigationAction.navigationType == .backForward
    {
      decisionHandler(.allow)
      return
    }
    let request = NavigationRequestMessage(url: url.absoluteString, isMainFrame: true)
    let api = flutterApi
    let id = self.id
    Task { @MainActor in
      let decision: NavigationDecisionMessage
      do {
        decision = try await api.shouldOverrideUrlLoading(webViewId: id, request: request)
      } catch {
        NSLog("MobileWebView: navigation delegate failed, allowing navigation: \(error)")
        decision = .navigate
      }
      decisionHandler(decision == .navigate ? .allow : .cancel)
    }
  }
}

extension MobileWebView: WKScriptMessageHandler {
  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    let channelName = message.name
    let body = (message.body as? String) ?? String(describing: message.body)
    send { api, id in
      try await api.onJavaScriptMessage(webViewId: id, channelName: channelName, message: body)
    }
  }
}

/// WKUserContentController retains its handlers strongly; this breaks the cycle.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
  private weak var target: WKScriptMessageHandler?

  init(_ target: WKScriptMessageHandler) {
    self.target = target
  }

  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    target?.userContentController(userContentController, didReceive: message)
  }
}
