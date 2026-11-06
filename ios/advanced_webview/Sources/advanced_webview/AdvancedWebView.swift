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
  private let hasSslErrorDelegate: Bool
  private let hasHttpAuthDelegate: Bool
  private let hasConsoleMessageDelegate: Bool
  private let hasJsDialogDelegate: Bool
  private let hasHttpErrorDelegate: Bool
  private let hasFindDelegate: Bool
  private let hasFaviconDelegate: Bool
  private let hasFullscreenDelegate: Bool
  private var javaScriptChannelNames: [String] = []
  private let hasJavaScriptHandlers: Bool
  private let handlerObjectName: String
  private var observations: [NSKeyValueObservation] = []
  private var isDestroyed = false
  /// URL of the load started by `load(_:)` / `loadHTMLString(_:baseURL:)`
  /// whose policy decision has not arrived yet.
  private var pendingAppInitiatedURL: String?
  private var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
  /// The query of the running search and the index WebKit is probably at. WebKit reports neither.
  private var findQuery: String?
  private var findIndex = 0

  init(params: CreationParamsMessage, flutterApi: AdvancedWebViewFlutterApi) {
    self.id = params.webViewId
    self.flutterApi = flutterApi
    self.hasNavigationDelegate = params.hasNavigationDelegate
    self.hasNewWindowDelegate = params.hasNewWindowDelegate
    self.hasPermissionDelegate = params.hasPermissionDelegate
    self.hasDownloadDelegate = params.hasDownloadDelegate
    self.hasSslErrorDelegate = params.hasSslErrorDelegate
    self.hasHttpAuthDelegate = params.hasHttpAuthDelegate
    self.hasConsoleMessageDelegate = params.hasConsoleMessageDelegate
    self.hasJsDialogDelegate = params.hasJsDialogDelegate
    self.hasHttpErrorDelegate = params.hasHttpErrorDelegate
    self.hasFindDelegate = params.hasFindDelegate
    self.hasFaviconDelegate = params.hasFaviconDelegate
    self.hasFullscreenDelegate = params.hasFullscreenDelegate
    self.hasJavaScriptHandlers = !params.javaScriptHandlerNames.isEmpty
    self.handlerObjectName = params.javaScriptHandlerObjectName

    // Some WKWebView options can only be set at creation time.
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = params.settings.allowsInlineMediaPlayback
    configuration.mediaTypesRequiringUserActionForPlayback =
      params.settings.mediaPlaybackRequiresUserGesture ? .all : []
    configuration.applicationNameForUserAgent = params.settings.applicationNameForUserAgent
    // Lets any element (not only a video) go fullscreen, like Android's WebView.
    configuration.preferences.isElementFullscreenEnabled = true
    if params.settings.incognito {
      configuration.websiteDataStore = .nonPersistent()
    }
    // WebKit refuses to hand its built-in schemes (http, https, file, ...) to an app.
    for scheme in Set(params.interceptSchemes) where !WKWebView.handlesURLScheme(scheme) {
      configuration.setURLSchemeHandler(
        InterceptSchemeHandler(webViewId: params.webViewId, flutterApi: flutterApi),
        forURLScheme: scheme)
    }
    self.webView = WKWebView(frame: .zero, configuration: configuration)
    super.init()

    webView.navigationDelegate = self
    webView.uiDelegate = self
    apply(settings: params.settings)
    params.javaScriptChannelNames.forEach(addJavaScriptChannel)
    params.userScripts.forEach(addUserScript)
    if hasJavaScriptHandlers { installHandlerBridge() }
    if hasConsoleMessageDelegate { installConsoleBridge() }
    observeProperties()
    if params.hasLongPressDelegate {
      let recognizer = UILongPressGestureRecognizer(
        target: self, action: #selector(handleLongPress(_:)))
      recognizer.delegate = self
      recognizer.cancelsTouchesInView = false
      webView.addGestureRecognizer(recognizer)
    }
    if params.hasScrollDelegate {
      observations.append(
        webView.scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
          let offset = scrollView.contentOffset
          self?.send { api, id in
            try await api.onScrollChanged(webViewId: id, x: Double(offset.x), y: Double(offset.y))
          }
        })
    }
  }

  func view() -> UIView {
    return webView
  }

  func apply(settings: WebViewSettingsMessage) {
    webView.configuration.defaultWebpagePreferences.allowsContentJavaScript =
      settings.javaScriptEnabled
    webView.allowsBackForwardNavigationGestures = settings.allowsBackForwardNavigationGestures
    webView.isInspectable = settings.inspectable
    webView.allowsLinkPreview = settings.allowsLinkPreview
    webView.configuration.defaultWebpagePreferences.preferredContentMode =
      switch settings.contentMode {
      case .recommended: .recommended
      case .mobile: .mobile
      case .desktop: .desktop
      }
    cachePolicy =
      switch settings.cacheMode {
      case .normal: .useProtocolCachePolicy
      case .preferCache: .returnCacheDataElseLoad
      case .cacheOnly: .returnCacheDataDontLoad
      case .noCache: .reloadIgnoringLocalCacheData
      }
    webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically =
      settings.javaScriptCanOpenWindowsAutomatically
    webView.scrollView.showsVerticalScrollIndicator = settings.scrollbarsVisible
    webView.scrollView.showsHorizontalScrollIndicator = settings.scrollbarsVisible
    webView.scrollView.bounces = settings.overScrollEnabled
    if settings.pullToRefreshEnabled {
      if webView.scrollView.refreshControl == nil {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = control
      }
    } else {
      webView.scrollView.refreshControl = nil
    }
    webView.pageZoom = CGFloat(settings.textZoom) / 100
    webView.configuration.preferences.minimumFontSize =
      settings.minimumFontSize.map { CGFloat($0) } ?? 0
    webView.customUserAgent = settings.userAgent
    webView.isOpaque = !settings.transparentBackground
    webView.backgroundColor = settings.transparentBackground ? .clear : .white
    webView.scrollView.backgroundColor = webView.backgroundColor
  }

  @objc private func handleRefresh() {
    webView.reload()
  }

  /// `WKWebView.interactionState` (back/forward list and scroll position) archived as bytes,
  /// or nil when there is nothing to save.
  func saveState() -> FlutterStandardTypedData? {
    guard let state = webView.interactionState,
      let data = try? NSKeyedArchiver.archivedData(
        withRootObject: state, requiringSecureCoding: false)
    else { return nil }
    return FlutterStandardTypedData(bytes: data)
  }

  func restoreState(_ data: FlutterStandardTypedData) -> Bool {
    guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data.data) else { return false }
    unarchiver.requiresSecureCoding = false
    guard let state = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) else {
      return false
    }
    webView.interactionState = state
    return true
  }

  /// Opens the system print dialog; needs the WebView to be in a window.
  func printPage(jobName: String?) throws {
    guard webView.window != nil else {
      throw PigeonError(code: "not-attached", message: "The WebView is not shown", details: nil)
    }
    let info = UIPrintInfo.printInfo()
    info.outputType = .general
    info.jobName = jobName ?? webView.title ?? "Document"
    let controller = UIPrintInteractionController.shared
    controller.printInfo = info
    controller.printFormatter = webView.viewPrintFormatter()
    controller.present(animated: true, completionHandler: nil)
  }

  /// Scroll offsets are logical pixels (points), like Flutter and Android.
  func scrollTo(x: Double, y: Double) {
    webView.scrollView.setContentOffset(CGPoint(x: x, y: y), animated: false)
  }

  func scrollBy(dx: Double, dy: Double) {
    let offset = webView.scrollView.contentOffset
    scrollTo(x: Double(offset.x) + dx, y: Double(offset.y) + dy)
  }

  /// The zoom scale in points per CSS pixel, like Android.
  func zoomScale() -> Double {
    return Double(webView.scrollView.zoomScale)
  }

  func zoomBy(_ factor: Double) {
    setZoomScale(zoomScale() * factor)
  }

  /// The scroll view keeps the scale within the page's minimum and maximum.
  func setZoomScale(_ scale: Double) {
    webView.scrollView.setZoomScale(CGFloat(scale), animated: false)
  }

  func scrollPosition() -> ScrollPositionMessage {
    let offset = webView.scrollView.contentOffset
    return ScrollPositionMessage(x: Double(offset.x), y: Double(offset.y))
  }

  /// PNG of the visible area, or nil while the view has no size.
  @MainActor
  func takeScreenshot() async throws -> FlutterStandardTypedData? {
    guard webView.bounds.width > 0, webView.bounds.height > 0 else { return nil }
    let image = try await webView.takeSnapshot(configuration: nil)
    return image.pngData().map { FlutterStandardTypedData(bytes: $0) }
  }

  /// One page as tall as the content. `WKPDFConfiguration` captures only the visible frame by
  /// default, so the rectangle is the whole scrollable content.
  @MainActor
  func createPdf() async throws -> FlutterStandardTypedData {
    let configuration = WKPDFConfiguration()
    let size = webView.scrollView.contentSize
    if size.width > 0, size.height > 0 {
      configuration.rect = CGRect(origin: .zero, size: size)
    }
    do {
      return FlutterStandardTypedData(bytes: try await webView.pdf(configuration: configuration))
    } catch {
      throw PigeonError(code: "pdf-failed", message: error.localizedDescription, details: nil)
    }
  }

  /// Like Android, repeating the same query moves to the next match. WebKit
  /// searches from the current selection, so no query state is needed here.
  @MainActor
  func find(_ query: String, forward: Bool) async throws -> FindResultMessage {
    guard !query.isEmpty else {
      clearMatches()
      return FindResultMessage(found: false)
    }
    let configuration = WKFindConfiguration()
    configuration.backwards = !forward
    configuration.wraps = true
    let result = try await webView.find(query, configuration: configuration)
    // WebKit only says whether something matched, so count in the page text and follow the
    // search direction to keep an index. Best-effort, as documented in Dart.
    let count = result.matchFound ? await countMatches(query) : 0
    guard result.matchFound, count > 0 else {
      findQuery = query
      findIndex = 0
      report(index: 0, count: 0)
      return FindResultMessage(found: result.matchFound, matchCount: 0)
    }
    if query == findQuery {
      findIndex = ((forward ? findIndex + 1 : findIndex - 1) % count + count) % count
    } else {
      findQuery = query
      findIndex = forward ? 0 : count - 1
    }
    report(index: findIndex, count: count)
    return FindResultMessage(
      found: true, matchCount: Int64(count), activeMatchIndex: Int64(findIndex))
  }

  /// Case-insensitive occurrences of `query` in the visible page text, like `WKFindConfiguration`.
  private func countMatches(_ query: String) async -> Int {
    let script = """
      const text = (document.body ? document.body.innerText : '').toLowerCase();
      const needle = q.toLowerCase();
      let count = 0;
      for (let i = text.indexOf(needle); i !== -1; i = text.indexOf(needle, i + needle.length)) count++;
      return count;
      """
    let value = try? await webView.callAsyncJavaScript(
      script, arguments: ["q": query], in: nil, contentWorld: .page)
    return (value as? NSNumber)?.intValue ?? 0
  }

  private func report(index: Int, count: Int) {
    guard hasFindDelegate else { return }
    send { api, id in
      try await api.onFindResult(
        webViewId: id, activeMatchIndex: Int64(index), numberOfMatches: Int64(count), isDone: true)
    }
  }

  func clearMatches() {
    findQuery = nil
    findIndex = 0
    webView.evaluateJavaScript("window.getSelection().removeAllRanges()", completionHandler: nil)
  }

  /// Loads a request started by the app. Like Android, it does not consult
  /// the navigation delegate.
  func load(_ request: URLRequest) {
    var request = request
    request.cachePolicy = cachePolicy
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

  /// Removes the selected kinds of data from the data store this WebView uses.
  @MainActor
  func clearWebsiteData(_ types: [WebsiteDataTypeMessage]) async {
    var wanted = Set<String>()
    for type in types {
      switch type {
      case .cache:
        wanted.formUnion([WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
      case .localStorage:
        wanted.formUnion([WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeSessionStorage])
      case .indexedDb:
        wanted.insert(WKWebsiteDataTypeIndexedDBDatabases)
      }
    }
    guard !wanted.isEmpty else { return }
    await webView.configuration.websiteDataStore.removeData(
      ofTypes: wanted, modifiedSince: .distantPast)
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
    if hasConsoleMessageDelegate { addConsoleShim() }
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

  private static let consoleBridgeName = "advancedWebViewConsole"

  /// WebKit has no console callback, so wrap the `console` methods in every frame. The wrapper
  /// still calls the original method, which keeps the Web Inspector output. Source URL and line
  /// number are not available.
  private func installConsoleBridge() {
    webView.configuration.userContentController.add(
      WeakScriptMessageHandler(self), name: Self.consoleBridgeName)
    addConsoleShim()
  }

  private func addConsoleShim() {
    let source = """
      (function () {
        if (window.__advancedWebViewConsole) return;
        window.__advancedWebViewConsole = true;
        var bridge = window.webkit.messageHandlers['\(Self.consoleBridgeName)'];
        function format(value) {
          if (typeof value === 'string') return value;
          if (value instanceof Error) return value.stack || String(value);
          if (value !== null && typeof value === 'object') {
            try { return JSON.stringify(value); } catch (e) { return String(value); }
          }
          return String(value);
        }
        [['debug', 'debug'], ['log', 'log'], ['info', 'info'], ['warn', 'warning'],
         ['error', 'error']].forEach(function (pair) {
          var original = console[pair[0]];
          console[pair[0]] = function () {
            try {
              bridge.postMessage({
                level: pair[1],
                message: Array.prototype.map.call(arguments, format).join(' ')
              });
            } catch (e) {}
            if (original) return original.apply(console, arguments);
          };
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
    if hasFullscreenDelegate {
      observations.append(
        webView.observe(\.fullscreenState, options: [.new]) { [weak self] webView, _ in
          // The transitional states are reported once they settle.
          switch webView.fullscreenState {
          case .inFullscreen:
            self?.send { api, id in try await api.onEnterFullscreen(webViewId: id) }
          case .notInFullscreen:
            self?.send { api, id in try await api.onExitFullscreen(webViewId: id) }
          default:
            break
          }
        })
    }
  }

  @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
    guard recognizer.state == .began else { return }
    let point = recognizer.location(in: webView)
    send { api, id in
      try await api.onLongPress(webViewId: id, x: Double(point.x), y: Double(point.y))
    }
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
    webView.scrollView.refreshControl?.endRefreshing()
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
    webView.scrollView.refreshControl?.endRefreshing()
    let url = webView.url?.absoluteString ?? ""
    send { api, id in try await api.onPageFinished(webViewId: id, url: url) }
    if hasFaviconDelegate { reportFavicon() }
  }

  /// Reads the favicon URL from the page's markup, the same way on both platforms.
  private func reportFavicon() {
    let script = """
      (function() {
        if (!/^https?:$/.test(location.protocol)) return null;
        var link = document.querySelector('link[rel~="icon" i][href]') ||
          document.querySelector('link[rel~="apple-touch-icon" i][href]');
        return link ? link.href : location.origin + '/favicon.ico';
      })()
      """
    webView.evaluateJavaScript(script) { [weak self] result, _ in
      let url = result as? String
      self?.send { api, id in try await api.onFaviconChanged(webViewId: id, url: url) }
    }
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

  /// Certificate problems and HTTP authentication. Without a Dart delegate a bad certificate
  /// is refused (the default) and authentication gets the system default handling.
  func webView(
    _ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    let space = challenge.protectionSpace
    switch space.authenticationMethod {
    case NSURLAuthenticationMethodServerTrust:
      guard hasSslErrorDelegate, let trust = space.serverTrust else {
        completionHandler(.performDefaultHandling, nil)
        return
      }
      var trustError: CFError?
      if SecTrustEvaluateWithError(trust, &trustError) {
        completionHandler(.performDefaultHandling, nil)
        return
      }
      let reason =
        (trustError as Error?)?.localizedDescription ?? "The certificate is not trusted"
      let host = space.host
      let url = webView.url?.absoluteString ?? "https://\(host)/"
      let error = SslErrorMessage(url: url, host: host, message: reason)
      let api = flutterApi
      let id = self.id
      Task { @MainActor in
        let decision: SslErrorDecisionMessage
        do {
          decision = try await api.onSslError(webViewId: id, error: error)
        } catch {
          NSLog("AdvancedWebView: SSL error delegate failed, refusing the load: \(error)")
          decision = .cancel
        }
        if decision == .proceed {
          completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
          completionHandler(.cancelAuthenticationChallenge, nil)
        }
      }
    case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest,
      NSURLAuthenticationMethodNTLM:
      guard hasHttpAuthDelegate, !space.isProxy() else {
        completionHandler(.performDefaultHandling, nil)
        return
      }
      let request = HttpAuthRequestMessage(host: space.host, realm: space.realm)
      let api = flutterApi
      let id = self.id
      Task { @MainActor in
        let credentials: HttpAuthCredentialsMessage?
        do {
          credentials = try await api.onHttpAuthRequest(webViewId: id, request: request)
        } catch {
          NSLog("AdvancedWebView: HTTP auth delegate failed, cancelling: \(error)")
          credentials = nil
        }
        if let credentials = credentials {
          completionHandler(
            .useCredential,
            URLCredential(
              user: credentials.username, password: credentials.password, persistence: .forSession))
        } else {
          completionHandler(.cancelAuthenticationChallenge, nil)
        }
      }
    default:
      completionHandler(.performDefaultHandling, nil)
    }
  }

  /// Attachments and types WebKit cannot show are reported to Dart instead of being loaded.
  func webView(
    _ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
    decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
  ) {
    // Error statuses of the main page and of iframes (not of sub-resources: WebKit does not say).
    if hasHttpErrorDelegate, let http = navigationResponse.response as? HTTPURLResponse,
      http.statusCode >= 400, let url = http.url
    {
      let error = HttpErrorMessage(
        url: url.absoluteString, statusCode: Int64(http.statusCode),
        isMainFrame: navigationResponse.isForMainFrame)
      send { api, id in try await api.onReceivedHttpError(webViewId: id, error: error) }
    }
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

  /// `alert`, `confirm` and `prompt`. WebKit answers them itself (dismissing silently) when this
  /// delegate is missing, so without a Dart delegate a native alert is presented, like the platform
  /// default dialog on Android.
  func webView(
    _ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void
  ) {
    runJsDialog(.alert, message: message, defaultText: nil, frame: frame) { _ in completionHandler()
    }
  }

  func webView(
    _ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void
  ) {
    runJsDialog(.confirm, message: message, defaultText: nil, frame: frame) {
      completionHandler($0.accepted)
    }
  }

  func webView(
    _ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
    defaultText: String?, initiatedByFrame frame: WKFrameInfo,
    completionHandler: @escaping (String?) -> Void
  ) {
    runJsDialog(.prompt, message: prompt, defaultText: defaultText, frame: frame) {
      completionHandler($0.accepted ? ($0.text ?? defaultText ?? "") : nil)
    }
  }

  private func runJsDialog(
    _ type: JsDialogTypeMessage, message: String, defaultText: String?, frame: WKFrameInfo,
    completion: @escaping (JsDialogResultMessage) -> Void
  ) {
    let url = frame.request.url
    guard hasJsDialogDelegate else {
      presentNativeDialog(
        type, title: url?.host, message: message, defaultText: defaultText, completion: completion)
      return
    }
    let request = JsDialogRequestMessage(
      type: type, message: message, url: url?.absoluteString ?? "", defaultText: defaultText)
    let api = flutterApi
    let id = self.id
    Task { @MainActor in
      let result: JsDialogResultMessage
      do {
        result = try await api.onJsDialog(webViewId: id, request: request)
      } catch {
        NSLog("AdvancedWebView: JavaScript dialog delegate failed, dismissing: \(error)")
        result = JsDialogResultMessage(accepted: false)
      }
      completion(result)
    }
  }

  private func presentNativeDialog(
    _ type: JsDialogTypeMessage, title: String?, message: String, defaultText: String?,
    completion: @escaping (JsDialogResultMessage) -> Void
  ) {
    guard let presenter = WebViewHostApiImpl.topViewController() else {
      completion(JsDialogResultMessage(accepted: false))
      return
    }
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    var field: UITextField?
    if type == .prompt {
      alert.addTextField {
        $0.text = defaultText
        field = $0
      }
    }
    // UIKit's own localized strings, so the buttons match the device language.
    let uiKit = Bundle(for: UIButton.self)
    alert.addAction(
      UIAlertAction(
        title: uiKit.localizedString(forKey: "OK", value: "OK", table: nil), style: .default
      ) { _ in
        completion(JsDialogResultMessage(accepted: true, text: field?.text))
      })
    if type != .alert {
      alert.addAction(
        UIAlertAction(
          title: uiKit.localizedString(forKey: "Cancel", value: "Cancel", table: nil),
          style: .cancel
        ) { _ in completion(JsDialogResultMessage(accepted: false)) })
    }
    presenter.present(alert, animated: true)
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
    if message.name == Self.consoleBridgeName {
      handleConsoleMessage(message.body)
      return
    }
    let channelName = message.name
    let body = (message.body as? String) ?? String(describing: message.body)
    send { api, id in
      try await api.onJavaScriptMessage(webViewId: id, channelName: channelName, message: body)
    }
  }
}

extension AdvancedWebView {
  fileprivate func handleConsoleMessage(_ body: Any) {
    guard let body = body as? [String: Any],
      let text = body["message"] as? String
    else { return }
    let level: ConsoleMessageLevelMessage =
      switch body["level"] as? String {
      case "debug": .debug
      case "info": .info
      case "warning": .warning
      case "error": .error
      default: .log
      }
    let message = ConsoleMessageMessage(
      level: level, message: text, sourceUrl: nil, lineNumber: nil)
    send { api, id in try await api.onConsoleMessage(webViewId: id, message: message) }
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

extension AdvancedWebView: UIGestureRecognizerDelegate {
  /// Let WKWebView's own long-press handling (link preview, text selection) keep working.
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
  ) -> Bool {
    return true
  }
}

/// Answers requests to custom URL schemes by asking Dart. WebKit offers no way to intercept `http` or
/// `https`, and no network fallback exists for a custom scheme, so a `nil` answer fails the request.
final class InterceptSchemeHandler: NSObject, WKURLSchemeHandler {
  private let webViewId: Int64
  private let flutterApi: AdvancedWebViewFlutterApi
  /// Tasks Dart has not answered yet. WebKit raises if a stopped task is used, so a task is dropped
  /// here as soon as `stop` arrives.
  private var pending: [ObjectIdentifier: WKURLSchemeTask] = [:]

  init(webViewId: Int64, flutterApi: AdvancedWebViewFlutterApi) {
    self.webViewId = webViewId
    self.flutterApi = flutterApi
  }

  func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    let request = urlSchemeTask.request
    guard let url = request.url else {
      urlSchemeTask.didFailWithError(URLError(.badURL))
      return
    }
    let message = InterceptRequestMessage(
      url: url.absoluteString,
      method: request.httpMethod ?? "GET",
      headers: request.allHTTPHeaderFields ?? [:],
      isMainFrame: request.mainDocumentURL == url)
    let key = ObjectIdentifier(urlSchemeTask)
    pending[key] = urlSchemeTask
    let api = flutterApi
    let id = webViewId
    Task { @MainActor [weak self] in
      let answer: InterceptResponseMessage?
      do {
        answer = try await api.onInterceptRequest(webViewId: id, request: message)
      } catch {
        NSLog("AdvancedWebView: intercept delegate failed, failing the request: \(error)")
        answer = nil
      }
      // `stop` removed the task while Dart was thinking.
      guard let self = self, let task = self.pending.removeValue(forKey: key) else { return }
      guard let answer = answer else {
        task.didFailWithError(URLError(.unsupportedURL))
        return
      }
      var headers = answer.headers
      headers["Content-Type"] = answer.mimeType
      headers["Content-Length"] = String(answer.body.data.count)
      guard
        let response = HTTPURLResponse(
          url: url, statusCode: Int(answer.statusCode), httpVersion: "HTTP/1.1",
          headerFields: headers)
      else {
        task.didFailWithError(URLError(.cannotParseResponse))
        return
      }
      task.didReceive(response)
      task.didReceive(answer.body.data)
      task.didFinish()
    }
  }

  func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    pending.removeValue(forKey: ObjectIdentifier(urlSchemeTask))
  }
}
