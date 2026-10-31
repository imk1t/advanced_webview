import Foundation

/// Implements the Dart -> native calls by dispatching to `WebViewRegistry`.
final class WebViewHostApiImpl: AdvancedWebViewHostApi {
  private let registry: WebViewRegistry
  private let flutterApi: AdvancedWebViewFlutterApi

  init(registry: WebViewRegistry, flutterApi: AdvancedWebViewFlutterApi) {
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

  func reload(webViewId: Int64) throws {
    try registry.get(webViewId).webView.reload()
  }

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
    await registry.get(webViewId).clearCookies()
  }
}
