import Flutter
import UIKit
import WebKit

/// One native WKWebView plus the delegates that forward its callbacks to Dart.
final class AdvancedWebView: NSObject, FlutterPlatformView {
  let id: Int64
  let webView: WKWebView

  private let flutterApi: AdvancedWebViewFlutterApi
  private let hasNavigationDelegate: Bool
  private let hasNewWindowDelegate: Bool
  private let hasPermissionDelegate: Bool
  private let hasDownloadDelegate: Bool
  private var javaScriptChannelNames: [String] = []
  private let hasJavaScriptHandlers: Bool
  private let handlerObjectName: String
  private var observations: [NSKeyValueObservation] = []
  private var isDestroyed = false
  /// URL of the load started by `load(_:)` / `loadHTMLString(_:baseURL:)`
  /// whose policy decision has not arrived yet.
  private var pendingAppInitiatedURL: String?

  init(params: CreationParamsMessage, flutterApi: AdvancedWebViewFlutterApi) {
    self.id = params.webViewId
    self.flutterApi = flutterApi
    self.hasNavigationDelegate = params.hasNavigationDelegate
    self.hasNewWindowDelegate = params.hasNewWindowDelegate
    self.hasPermissionDelegate = params.hasPermissionDelegate
    self.hasDownloadDelegate = params.hasDownloadDelegate
    self.hasJavaScriptHandlers = !params.javaScriptHandlerNames.isEmpty
    self.handlerObjectName = params.javaScriptHandlerObjectName

    // Some WKWebView options can only be set at creation time.
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = params.settings.allowsInlineMediaPlayback
    configuration.mediaTypesRequiringUserActionForPlayback =
      params.settings.mediaPlaybackRequiresUserGesture ? .all : []
    // Same as Android: let scripts call window.open without a user gesture.
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
    self.webView = WKWebView(frame: .zero, configuration: configuration)
    super.init()

    webView.navigationDelegate = self
    webView.uiDelegate = self
    apply(settings: params.settings)
    params.javaScriptChannelNames.forEach(addJavaScriptChannel)
    params.userScripts.forEach(addUserScript)
    if hasJavaScriptHandlers { installHandlerBridge() }
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

  /// WKWebView must be used on the main thread. Without `@MainActor` this
  /// `async` function runs on the global executor, calls WKWebView off the
  /// main thread and can hang.
  @MainActor
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

  @MainActor
  func setCookie(_ cookie: CookieMessage) async throws {
    var properties: [HTTPCookiePropertyKey: Any] = [
      .name: cookie.name,
      .value: cookie.value,
      .domain: cookie.domain,
      .path: cookie.path,
    ]
    if let millis = cookie.expiresMillis {
      properties[.expires] = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
    }
    if cookie.isSecure { properties[.secure] = "TRUE" }
    if cookie.isHttpOnly { properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
    guard let httpCookie = HTTPCookie(properties: properties) else {
      throw PigeonError(
        code: "invalid-cookie", message: "Invalid cookie: \(cookie.name)", details: nil)
    }
    await webView.configuration.websiteDataStore.httpCookieStore.setCookie(httpCookie)
  }

  /// Returns the cookies WebKit would send to `url`.
  @MainActor
  func cookies(for url: URL) async -> [CookieMessage] {
    let all = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
    let host = url.host?.lowercased() ?? ""
    // URL.path can strip a trailing slash; cookie matching needs the request path verbatim.
    let requestPath =
      URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? ""
    let path = requestPath.isEmpty ? "/" : requestPath
    let isSecureScheme = url.scheme?.lowercased() == "https"
    return all.filter { cookie in
      let domain = cookie.domain.lowercased()
      let bare = domain.hasPrefix(".") ? String(domain.dropFirst()) : domain
      let hostMatches = host == bare || (domain.hasPrefix(".") && host.hasSuffix("." + bare))
      let cookiePath = cookie.path
      let pathMatches =
        path == cookiePath
        || (path.hasPrefix(cookiePath)
          && (cookiePath.hasSuffix("/") || path.hasPrefix(cookiePath + "/")))
      return hostMatches && pathMatches && (!cookie.isSecure || isSecureScheme)
    }.map { cookie in
      CookieMessage(
        name: cookie.name,
        value: cookie.value,
        domain: cookie.domain,
        path: cookie.path,
        isSecure: cookie.isSecure,
        isHttpOnly: cookie.isHTTPOnly,
        expiresMillis: cookie.expiresDate.map { Int64($0.timeIntervalSince1970 * 1000) })
    }
  }

  @MainActor
  func clearCookies() async {
    let store = webView.configuration.websiteDataStore.httpCookieStore
    for cookie in await store.allCookies() {
      await store.deleteCookie(cookie)
    }
  }

  func destroy() {
    guard !isDestroyed else { return }
    isDestroyed = true
    observations.removeAll()
    webView.stopLoading()
    webView.navigationDelegate = nil
    webView.uiDelegate = nil
    webView.configuration.userContentController.removeAllScriptMessageHandlers()
  }

  func addUserScript(_ script: UserScriptMessage) {
    let time: WKUserScriptInjectionTime =
      script.injectionTime == .atDocumentStart ? .atDocumentStart : .atDocumentEnd
    webView.configuration.userContentController.addUserScript(
      WKUserScript(
        source: script.source, injectionTime: time, forMainFrameOnly: script.mainFrameOnly))
  }

  /// Removes the scripts added by the app. WebKit has no way to remove a single
  /// script, so the JavaScript channel shims are registered again.
  func removeAllUserScripts() {
    webView.configuration.userContentController.removeAllUserScripts()
    javaScriptChannelNames.forEach(addChannelShim)
    if hasJavaScriptHandlers { addHandlerShim() }
  }

  private static let handlerBridgeName = "advancedWebView"

  /// `window.<objectName>.callHandler(name, ...args)` returns a promise. The reply
  /// handler of `WKScriptMessageHandlerWithReply` settles it, so no call ids are needed.
  private func installHandlerBridge() {
    webView.configuration.userContentController.addScriptMessageHandler(
      WeakReplyScriptMessageHandler(self), contentWorld: .page, name: Self.handlerBridgeName)
    addHandlerShim()
  }

  private func addHandlerShim() {
    let source = """
      (function () {
        if (window.\(handlerObjectName)) return;
        var bridge = window.webkit.messageHandlers['\(Self.handlerBridgeName)'];
        window.\(handlerObjectName) = Object.freeze({
          callHandler: function (name) {
            var args = Array.prototype.slice.call(arguments, 1);
            return Promise.resolve().then(function () {
              return bridge.postMessage({ name: String(name), args: JSON.stringify(args) });
            }).then(function (value) {
              return JSON.parse(value);
            }, function (error) {
              throw new Error(error && error.message ? error.message : String(error));
            });
          }
        });
      })();
      """
    webView.configuration.userContentController.addUserScript(
      WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false))
  }

  private func addJavaScriptChannel(_ name: String) {
    javaScriptChannelNames.append(name)
    webView.configuration.userContentController.add(WeakScriptMessageHandler(self), name: name)
    addChannelShim(name)
  }

  private func addChannelShim(_ name: String) {
    let controller = webView.configuration.userContentController
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
  private func send(_ block: @escaping (AdvancedWebViewFlutterApi, Int64) async throws -> Void) {
    let api = flutterApi
    let id = self.id
    Task { @MainActor [weak self] in
      guard let self = self, !self.isDestroyed else { return }
      do {
        try await block(api, id)
      } catch {
        NSLog("AdvancedWebView: failed to deliver event to Dart: \(error)")
      }
    }
  }

  private func reportError(_ error: Error, url: URL?) {
    let nsError = error as NSError
    // Navigations cancelled by us (e.g. a delegate decision) are not errors.
    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
    // "Frame load interrupted": the response was turned into a download event.
    if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }
    let message = WebResourceErrorMessage(
      errorCode: Int64(nsError.code),
      message: nsError.localizedDescription,
      isMainFrame: true,
      url: url?.absoluteString
    )
    send { api, id in try await api.onReceivedError(webViewId: id, error: message) }
  }
}

extension AdvancedWebView: WKNavigationDelegate {
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

  /// Attachments and types WebKit cannot show are reported to Dart instead of being loaded.
  func webView(
    _ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
    decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
  ) {
    guard hasDownloadDelegate, let url = navigationResponse.response.url else {
      decisionHandler(.allow)
      return
    }
    let response = navigationResponse.response
    let disposition = (response as? HTTPURLResponse)?
      .value(forHTTPHeaderField: "Content-Disposition")?.lowercased()
    let isAttachment = disposition?.hasPrefix("attachment") ?? false
    guard isAttachment || !navigationResponse.canShowMIMEType else {
      decisionHandler(.allow)
      return
    }
    let length = response.expectedContentLength
    let request = DownloadRequestMessage(
      url: url.absoluteString,
      suggestedFilename: response.suggestedFilename,
      mimeType: response.mimeType,
      contentLength: length > 0 ? length : nil)
    send { api, id in try await api.onDownloadStart(webViewId: id, request: request) }
    decisionHandler(.cancel)
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    // `<a download>` links: WebKit marks the action instead of loading a response.
    if hasDownloadDelegate, navigationAction.shouldPerformDownload,
      let url = navigationAction.request.url
    {
      let request = DownloadRequestMessage(
        url: url.absoluteString, suggestedFilename: nil, mimeType: nil, contentLength: nil)
      send { api, id in try await api.onDownloadStart(webViewId: id, request: request) }
      decisionHandler(.cancel)
      return
    }
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
        NSLog("AdvancedWebView: navigation delegate failed, allowing navigation: \(error)")
        decision = .navigate
      }
      decisionHandler(decision == .navigate ? .allow : .cancel)
    }
  }
}

extension AdvancedWebView: WKUIDelegate {
  /// `window.open` and `target="_blank"`. WebKit never opens a window on its
  /// own here: the URL is either reported to Dart or loaded in this WebView,
  /// like Android without a delegate.
  func webView(
    _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    guard navigationAction.targetFrame == nil, let url = navigationAction.request.url else {
      return nil
    }
    if hasNewWindowDelegate {
      let target = url.absoluteString
      send { api, id in try await api.onNewWindowRequest(webViewId: id, url: target) }
    } else {
      webView.load(navigationAction.request)
    }
    return nil
  }

  /// Camera and microphone. Without a Dart delegate the request is denied, like Android.
  /// WebKit has no delegate for geolocation; it asks the user itself.
  func webView(
    _ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
    initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
    decisionHandler: @escaping (WKPermissionDecision) -> Void
  ) {
    guard hasPermissionDelegate else {
      decisionHandler(.deny)
      return
    }
    let resources: [PermissionResourceMessage]
    switch type {
    case .camera: resources = [.camera]
    case .microphone: resources = [.microphone]
    case .cameraAndMicrophone: resources = [.camera, .microphone]
    @unknown default:
      decisionHandler(.deny)
      return
    }
    let port = origin.port == 0 ? "" : ":\(origin.port)"
    let request = PermissionRequestMessage(
      origin: "\(origin.protocol)://\(origin.host)\(port)", resources: resources)
    let api = flutterApi
    let id = self.id
    Task { @MainActor in
      let decision: PermissionDecisionMessage
      do {
        decision = try await api.onPermissionRequest(webViewId: id, request: request)
      } catch {
        NSLog("AdvancedWebView: permission delegate failed, denying: \(error)")
        decision = .deny
      }
      decisionHandler(decision == .grant ? .grant : .deny)
    }
  }
}

extension AdvancedWebView: WKScriptMessageHandler {
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

extension AdvancedWebView: WKScriptMessageHandlerWithReply {
  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
    replyHandler: @escaping @MainActor (Any?, String?) -> Void
  ) {
    guard let body = message.body as? [String: Any],
      let name = body["name"] as? String,
      let argsJson = body["args"] as? String
    else {
      replyHandler(nil, "Invalid JavaScript handler call")
      return
    }
    let api = flutterApi
    let id = self.id
    Task { @MainActor in
      do {
        let result = try await api.onJavaScriptHandlerCall(
          webViewId: id, handlerName: name, argsJson: argsJson)
        replyHandler(result, nil)
      } catch {
        replyHandler(nil, (error as? PigeonError)?.message ?? String(describing: error))
      }
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

private final class WeakReplyScriptMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
  private weak var target: WKScriptMessageHandlerWithReply?

  init(_ target: WKScriptMessageHandlerWithReply) {
    self.target = target
  }

  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
    replyHandler: @escaping @MainActor (Any?, String?) -> Void
  ) {
    guard let target = target else {
      replyHandler(nil, "The WebView was destroyed")
      return
    }
    target.userContentController(
      userContentController, didReceive: message, replyHandler: replyHandler)
  }
}
