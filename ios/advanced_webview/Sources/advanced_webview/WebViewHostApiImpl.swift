import Flutter
import Foundation
import UIKit

/// Implements the Dart -> native calls by dispatching to `WebViewRegistry`.
final class WebViewHostApiImpl: AdvancedWebViewHostApi {
  private let registry: WebViewRegistry
  private let flutterApi: AdvancedWebViewFlutterApi
  private var browsers: [Int64: InAppBrowserViewController] = [:]

  /// Maps a Flutter asset key to its path inside the app bundle.
  private let assetPath: (String) -> String?

  init(
    registry: WebViewRegistry, flutterApi: AdvancedWebViewFlutterApi,
    assetPath: @escaping (String) -> String? = { _ in nil }
  ) {
    self.assetPath = assetPath
    self.registry = registry
    self.flutterApi = flutterApi
  }

  func create(params: CreationParamsMessage) throws {
    try registry.add(AdvancedWebView(params: params, flutterApi: flutterApi))
  }

  func dispose(webViewId: Int64) throws {
    registry.remove(webViewId)?.destroy()
  }

  func disposeAll() {
    for instance in registry.removeAll() {
      instance.destroy()
    }
  }

  func loadUrl(webViewId: Int64, url: String, headers: [String: String]) throws {
    guard let target = URL(string: url) else {
      throw PigeonError(code: "invalid-url", message: "Invalid URL: \(url)", details: nil)
    }
    var request = URLRequest(url: target)
    for (field, value) in headers {
      request.setValue(value, forHTTPHeaderField: field)
    }
    try registry.get(webViewId).load(request)
  }

  func loadHtmlString(webViewId: Int64, html: String, baseUrl: String?) throws {
    try registry.get(webViewId).loadHTMLString(html, baseURL: baseUrl.flatMap(URL.init))
  }

  func loadRequest(
    webViewId: Int64, url: String, method: HttpMethodMessage, headers: [String: String],
    body: FlutterStandardTypedData?
  ) throws {
    guard let target = URL(string: url) else {
      throw PigeonError(code: "invalid-url", message: "Invalid URL: \(url)", details: nil)
    }
    var request = URLRequest(url: target)
    request.httpMethod = method == .post ? "POST" : "GET"
    if method == .post { request.httpBody = body?.data }
    for (field, value) in headers {
      request.setValue(value, forHTTPHeaderField: field)
    }
    try registry.get(webViewId).load(request)
  }

  func loadFlutterAsset(webViewId: Int64, key: String) throws {
    guard let relative = assetPath(key) else {
      throw PigeonError(code: "not-found", message: "No Flutter asset \(key)", details: nil)
    }
    try loadFileURL(webViewId, Bundle.main.bundleURL.appendingPathComponent(relative))
  }

  func loadFile(webViewId: Int64, path: String) throws {
    try loadFileURL(webViewId, URL(fileURLWithPath: path))
  }

  /// Gives the page read access to the file's folder so relative links keep working.
  private func loadFileURL(_ webViewId: Int64, _ url: URL) throws {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw PigeonError(code: "not-found", message: "No file at \(url.path)", details: nil)
    }
    try registry.get(webViewId).webView.loadFileURL(
      url, allowingReadAccessTo: url.deletingLastPathComponent())
  }

  func reload(webViewId: Int64) throws {
    try registry.get(webViewId).webView.reload()
  }

  @MainActor
  func pause(webViewId: Int64) async throws {
    try await registry.get(webViewId).webView.setAllMediaPlaybackSuspended(true)
  }

  @MainActor
  func resume(webViewId: Int64) async throws {
    try await registry.get(webViewId).webView.setAllMediaPlaybackSuspended(false)
  }

  /// WKWebView has no timer switch; Android only.
  func pauseTimers(webViewId: Int64) throws {}

  /// WKWebView has no timer switch; Android only.
  func resumeTimers(webViewId: Int64) throws {}

  func stopLoading(webViewId: Int64) throws {
    try registry.get(webViewId).webView.stopLoading()
  }

  func goBack(webViewId: Int64) throws {
    try registry.get(webViewId).webView.goBack()
  }

  func goForward(webViewId: Int64) throws {
    try registry.get(webViewId).webView.goForward()
  }

  func canGoBack(webViewId: Int64) throws -> Bool {
    return try registry.get(webViewId).webView.canGoBack
  }

  func canGoForward(webViewId: Int64) throws -> Bool {
    return try registry.get(webViewId).webView.canGoForward
  }

  func getUrl(webViewId: Int64) throws -> String? {
    return try registry.get(webViewId).webView.url?.absoluteString
  }

  @MainActor
  func takeScreenshot(webViewId: Int64) async throws -> FlutterStandardTypedData? {
    return try await registry.get(webViewId).takeScreenshot()
  }

  @MainActor
  func createPdf(webViewId: Int64) async throws -> FlutterStandardTypedData {
    return try await registry.get(webViewId).createPdf()
  }

  @MainActor
  func findText(webViewId: Int64, query: String, forward: Bool) async throws -> FindResultMessage {
    return try await registry.get(webViewId).find(query, forward: forward)
  }

  func clearMatches(webViewId: Int64) throws {
    try registry.get(webViewId).clearMatches()
  }

  func scrollTo(webViewId: Int64, x: Double, y: Double) throws {
    try registry.get(webViewId).scrollTo(x: x, y: y)
  }

  func scrollBy(webViewId: Int64, dx: Double, dy: Double) throws {
    try registry.get(webViewId).scrollBy(dx: dx, dy: dy)
  }

  func zoomBy(webViewId: Int64, factor: Double) throws {
    try registry.get(webViewId).zoomBy(factor)
  }

  func setZoomScale(webViewId: Int64, scale: Double) throws {
    try registry.get(webViewId).setZoomScale(scale)
  }

  func getZoomScale(webViewId: Int64) throws -> Double {
    return try registry.get(webViewId).zoomScale()
  }

  func getScrollPosition(webViewId: Int64) throws -> ScrollPositionMessage {
    return try registry.get(webViewId).scrollPosition()
  }

  func saveState(webViewId: Int64) throws -> FlutterStandardTypedData? {
    return try registry.get(webViewId).saveState()
  }

  func restoreState(webViewId: Int64, state: FlutterStandardTypedData) throws -> Bool {
    return try registry.get(webViewId).restoreState(state)
  }

  func printPage(webViewId: Int64, jobName: String?) throws {
    try registry.get(webViewId).printPage(jobName: jobName)
  }

  func getTitle(webViewId: Int64) throws -> String? {
    return try registry.get(webViewId).webView.title
  }

  // The registry and WKWebView are main-thread only; keep this async call there.
  @MainActor
  func evaluateJavaScript(webViewId: Int64, source: String) async throws -> String? {
    return try await registry.get(webViewId).evaluateJavaScript(source)
  }

  func updateSettings(webViewId: Int64, settings: WebViewSettingsMessage) throws {
    try registry.get(webViewId).apply(settings: settings)
  }

  @MainActor
  func setCookie(webViewId: Int64, cookie: CookieMessage) async throws {
    try await registry.get(webViewId).setCookie(cookie)
  }

  @MainActor
  func getCookies(webViewId: Int64, url: String) async throws -> [CookieMessage] {
    guard let target = URL(string: url) else {
      throw PigeonError(code: "invalid-url", message: "Invalid URL: \(url)", details: nil)
    }
    return try await registry.get(webViewId).cookies(for: target)
  }

  @MainActor
  func clearCookies(webViewId: Int64) async throws {
    try await registry.get(webViewId).clearCookies()
  }

  func clearWebsiteData(webViewId: Int64, types: [WebsiteDataTypeMessage]) async throws {
    try await registry.get(webViewId).clearWebsiteData(types)
  }

  func addUserScript(webViewId: Int64, script: UserScriptMessage) throws {
    try registry.get(webViewId).addUserScript(script)
  }

  func removeAllUserScripts(webViewId: Int64) throws {
    try registry.get(webViewId).removeAllUserScripts()
  }

  func openInAppBrowser(params: InAppBrowserParamsMessage) throws {
    let browser = try registry.get(params.webViewId)
    guard browsers[params.webViewId] == nil else {
      throw PigeonError(
        code: "already-open", message: "The in-app browser of \(params.webViewId) is already open",
        details: nil)
    }
    guard let presenter = Self.topViewController() else {
      throw PigeonError(
        code: "not-attached", message: "No view controller to present from", details: nil)
    }
    let api = flutterApi
    let id = params.webViewId
    let controller = InAppBrowserViewController(browser: browser, params: params) {
      [weak self] in
      self?.browsers.removeValue(forKey: id)
      Task { @MainActor in
        do {
          try await api.onInAppBrowserClosed(webViewId: id)
        } catch {
          NSLog("advanced_webview: failed to deliver event to Dart: \(error)")
        }
      }
    }
    browsers[id] = controller
    controller.present(from: presenter)
  }

  func closeInAppBrowser(webViewId: Int64) throws {
    browsers[webViewId]?.close()
  }

  /// The view controller on top of the foreground scene, where a modal can be presented.
  static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
      top = presented
    }
    return top
  }
}
