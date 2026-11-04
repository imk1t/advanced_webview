import Flutter
import UIKit
import WebKit
import XCTest

@testable import advanced_webview

// Unit tests for the Swift implementation. They run in the example app's test
// host: `xcodebuild test -workspace Runner.xcworkspace -scheme Runner`.
@MainActor
final class RunnerTests: XCTestCase {

  func testCreateRegistersTheWebViewById() throws {
    let (hostApi, registry, _) = makeHostApi()

    try hostApi.create(params: params(webViewId: 7))

    XCTAssertEqual(try registry.get(7).id, 7)
  }

  func testCreateRejectsADuplicateId() throws {
    let (hostApi, _, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))

    XCTAssertThrowsError(try hostApi.create(params: params(webViewId: 1))) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "already-exists")
    }
  }

  func testUnknownIdThrowsNotFound() {
    let (hostApi, _, _) = makeHostApi()

    XCTAssertThrowsError(try hostApi.reload(webViewId: 42)) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "not-found")
    }
  }

  func testDisposeUnregisters() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))

    try hostApi.dispose(webViewId: 1)

    XCTAssertThrowsError(try registry.get(1))
    // Disposing twice is harmless.
    XCTAssertNoThrow(try hostApi.dispose(webViewId: 1))
  }

  func testLoadUrlRejectsAnInvalidUrl() throws {
    let (hostApi, _, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))

    XCTAssertThrowsError(try hostApi.loadUrl(webViewId: 1, url: "", headers: [:])) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "invalid-url")
    }
  }

  func testSettingsAreAppliedAtCreationAndOnUpdate() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(
      params: params(webViewId: 1, settings: settings(javaScriptEnabled: false, userAgent: "ua-1")))
    let webView = try registry.get(1).webView
    XCTAssertFalse(webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)
    XCTAssertEqual(webView.customUserAgent, "ua-1")
    XCTAssertTrue(webView.isOpaque)

    try hostApi.updateSettings(
      webViewId: 1,
      settings: settings(javaScriptEnabled: true, transparentBackground: true, userAgent: "ua-2"))

    XCTAssertTrue(webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)
    XCTAssertEqual(webView.customUserAgent, "ua-2")
    XCTAssertFalse(webView.isOpaque)
  }

  func testNavigationGesturesAndInspectableAreApplied() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, settings: settings()))
    let webView = try registry.get(1).webView
    XCTAssertFalse(webView.allowsBackForwardNavigationGestures)
    XCTAssertFalse(webView.isInspectable)

    try hostApi.updateSettings(
      webViewId: 1,
      settings: settings(allowsBackForwardNavigationGestures: true, inspectable: true))

    XCTAssertTrue(webView.allowsBackForwardNavigationGestures)
    XCTAssertTrue(webView.isInspectable)
  }

  func testWindowAndScrollSettingsAreApplied() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, settings: settings()))
    let webView = try registry.get(1).webView
    XCTAssertTrue(webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically)
    XCTAssertTrue(webView.scrollView.showsVerticalScrollIndicator)
    XCTAssertTrue(webView.scrollView.bounces)

    try hostApi.updateSettings(
      webViewId: 1,
      settings: settings(
        javaScriptCanOpenWindowsAutomatically: false, scrollbarsVisible: false,
        overScrollEnabled: false))

    XCTAssertFalse(webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically)
    XCTAssertFalse(webView.scrollView.showsVerticalScrollIndicator)
    XCTAssertFalse(webView.scrollView.showsHorizontalScrollIndicator)
    XCTAssertFalse(webView.scrollView.bounces)
  }

  func testIncognitoUsesANonPersistentDataStore() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, settings: settings()))
    try hostApi.create(params: params(webViewId: 2, settings: settings(incognito: true)))

    XCTAssertTrue(try registry.get(1).webView.configuration.websiteDataStore.isPersistent)
    XCTAssertFalse(try registry.get(2).webView.configuration.websiteDataStore.isPersistent)
  }

  func testPullToRefreshAddsAndRemovesTheRefreshControl() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, settings: settings()))
    let webView = try registry.get(1).webView
    XCTAssertNil(webView.scrollView.refreshControl)

    try hostApi.updateSettings(webViewId: 1, settings: settings(pullToRefreshEnabled: true))
    XCTAssertNotNil(webView.scrollView.refreshControl)

    try hostApi.updateSettings(webViewId: 1, settings: settings())
    XCTAssertNil(webView.scrollView.refreshControl)
  }

  func testTextZoomAndMinimumFontSizeAreApplied() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(
      params: params(webViewId: 1, settings: settings(textZoom: 150, minimumFontSize: 14)))
    let webView = try registry.get(1).webView
    XCTAssertEqual(webView.pageZoom, 1.5, accuracy: 0.001)
    XCTAssertEqual(webView.configuration.preferences.minimumFontSize, 14)

    try hostApi.updateSettings(webViewId: 1, settings: settings())

    XCTAssertEqual(webView.pageZoom, 1.0, accuracy: 0.001)
    XCTAssertEqual(webView.configuration.preferences.minimumFontSize, 0)
  }

  func testCreationOnlySettingsConfigureTheWebView() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(
      params: params(
        webViewId: 1,
        settings: settings(mediaPlaybackRequiresUserGesture: false, allowsInlineMediaPlayback: true)
      ))

    let configuration = try registry.get(1).webView.configuration
    XCTAssertTrue(configuration.allowsInlineMediaPlayback)
    XCTAssertEqual(configuration.mediaTypesRequiringUserActionForPlayback, [])
  }

  func testJavaScriptChannelsInjectPostMessageShim() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, channels: ["Echo"]))

    let scripts = try registry.get(1).webView.configuration.userContentController.userScripts
    XCTAssertEqual(scripts.count, 1)
    XCTAssertTrue(scripts[0].source.contains("window['Echo']"))
    XCTAssertEqual(scripts[0].injectionTime, .atDocumentStart)
  }

  func testJavaScriptHandlersInstallTheBridgeShim() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, handlers: ["sum"]))

    let scripts = try registry.get(1).webView.configuration.userContentController.userScripts
    XCTAssertEqual(scripts.count, 1)
    XCTAssertTrue(scripts[0].source.contains("window.advanced_webview"))
    XCTAssertEqual(scripts[0].injectionTime, .atDocumentStart)
  }

  func testJavaScriptHandlerObjectNameIsConfigurable() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, handlers: ["sum"], handlerObjectName: "bridge"))

    let scripts = try registry.get(1).webView.configuration.userContentController.userScripts
    XCTAssertTrue(scripts[0].source.contains("window.bridge = "))
  }

  func testConsoleMessagesInstallTheWrapperInAllFrames() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, hasConsoleMessageDelegate: true))

    let scripts = try registry.get(1).webView.configuration.userContentController.userScripts
    XCTAssertEqual(scripts.count, 1)
    XCTAssertTrue(scripts[0].source.contains("advancedWebViewConsole"))
    XCTAssertEqual(scripts[0].injectionTime, .atDocumentStart)
    XCTAssertFalse(scripts[0].isForMainFrameOnly)
  }

  func testNoConsoleWrapperWithoutADelegate() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))

    XCTAssertTrue(
      try registry.get(1).webView.configuration.userContentController.userScripts.isEmpty)
  }

  func testRemovingUserScriptsKeepsTheConsoleWrapper() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, hasConsoleMessageDelegate: true))

    try hostApi.removeAllUserScripts(webViewId: 1)

    let scripts = try registry.get(1).webView.configuration.userContentController.userScripts
    XCTAssertEqual(scripts.count, 1)
    XCTAssertTrue(scripts[0].source.contains("advancedWebViewConsole"))
  }

  func testNoBridgeShimWithoutHandlers() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))

    XCTAssertTrue(
      try registry.get(1).webView.configuration.userContentController.userScripts.isEmpty)
  }

  @MainActor
  func testFindTextReportsWhetherTheQueryWasFound() async throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    defer { hostApi.disposeAll() }
    let webView = try registry.get(1).webView
    webView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
    try hostApi.loadHtmlString(
      webViewId: 1, html: "<p>alpha beta alpha</p>", baseUrl: nil)
    for _ in 0..<100 where webView.isLoading || webView.url == nil {
      try await Task.sleep(nanoseconds: 50_000_000)
    }

    let hit = try await hostApi.findText(webViewId: 1, query: "alpha", forward: true)
    let miss = try await hostApi.findText(webViewId: 1, query: "zzz", forward: true)
    let empty = try await hostApi.findText(webViewId: 1, query: "", forward: true)

    XCTAssertTrue(hit.found)
    XCTAssertNil(hit.matchCount)
    XCTAssertFalse(miss.found)
    XCTAssertFalse(empty.found)
  }

  @MainActor
  func testPrintPageFailsWhenTheWebViewIsNotInAWindow() throws {
    let (hostApi, _, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    defer { hostApi.disposeAll() }

    XCTAssertThrowsError(try hostApi.printPage(webViewId: 1, jobName: nil)) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "not-attached")
    }
  }

  @MainActor
  func testRestoreStateRejectsGarbage() throws {
    let (hostApi, _, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    defer { hostApi.disposeAll() }

    let restored = try hostApi.restoreState(
      webViewId: 1, state: FlutterStandardTypedData(bytes: Data([1, 2, 3])))

    XCTAssertFalse(restored)
  }

  @MainActor
  func testScrollToByAndPosition() throws {
    let (hostApi, _, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    defer { hostApi.disposeAll() }

    try hostApi.scrollTo(webViewId: 1, x: 10, y: 20)
    try hostApi.scrollBy(webViewId: 1, dx: 5, dy: -5)

    let position = try hostApi.getScrollPosition(webViewId: 1)
    XCTAssertEqual(position.x, 15)
    XCTAssertEqual(position.y, 15)
  }

  @MainActor
  func testTakeScreenshotReturnsPngOnceTheViewHasASize() async throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    defer { hostApi.disposeAll() }
    let empty = try await hostApi.takeScreenshot(webViewId: 1)
    XCTAssertNil(empty)

    try registry.get(1).webView.frame = CGRect(x: 0, y: 0, width: 40, height: 30)
    let data = try await hostApi.takeScreenshot(webViewId: 1)

    XCTAssertEqual(data?.data.prefix(4), Data([0x89, 0x50, 0x4e, 0x47]))
  }

  func testEvaluateJavaScriptReturnsJson() async throws {
    let (hostApi, _, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    defer { hostApi.disposeAll() }

    let number = try await hostApi.evaluateJavaScript(webViewId: 1, source: "1 + 2")
    let object = try await hostApi.evaluateJavaScript(webViewId: 1, source: "({a: [1, 'b']})")
    let string = try await hostApi.evaluateJavaScript(webViewId: 1, source: "'text'")
    let undefined = try await hostApi.evaluateJavaScript(webViewId: 1, source: "undefined")
    let null = try await hostApi.evaluateJavaScript(webViewId: 1, source: "null")

    XCTAssertEqual(number, "3")
    XCTAssertEqual(object, #"{"a":[1,"b"]}"#)
    XCTAssertEqual(string, #""text""#)
    XCTAssertNil(undefined)
    XCTAssertNil(null)
  }

  func testCookiePathsMatchOnlyAtPathBoundaries() async throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    let instance = try registry.get(1)
    let store = instance.webView.configuration.websiteDataStore.httpCookieStore
    let cookies = [("root", "/"), ("exact", "/account"), ("slash", "/account/")].map { name, path in
      HTTPCookie(properties: [.name: name, .value: "1", .domain: "path-match.test", .path: path])!
    }
    for cookie in cookies { await store.setCookie(cookie) }
    let cases: [(String, Set<String>)] = [
      ("", ["root"]), ("/", ["root"]), ("/account", ["root", "exact"]),
      ("/account/", ["root", "exact", "slash"]),
      ("/account/child", ["root", "exact", "slash"]),
      ("/account%2Fchild", ["root"]),
      ("/accounting", ["root"]), ("/accounting/child", ["root"]),
    ]
    for (path, expected) in cases {
      let result = try await hostApi.getCookies(webViewId: 1, url: "https://path-match.test" + path)
      XCTAssertEqual(Set(result.map(\.name)), expected, "Path: \(path)")
    }
    for cookie in cookies { await store.deleteCookie(cookie) }
  }

  func testFactoryReturnsTheExistingInstance() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 5))
    let instance = try registry.get(5)

    let view = AdvancedWebViewFactory(registry: registry).create(
      withFrame: .zero, viewIdentifier: 0, arguments: ["webViewId": 5])

    XCTAssertTrue(view === instance)
  }

  // MARK: - Helpers

  private func makeHostApi() -> (WebViewHostApiImpl, WebViewRegistry, FakeBinaryMessenger) {
    let messenger = FakeBinaryMessenger()
    let registry = WebViewRegistry()
    let hostApi = WebViewHostApiImpl(
      registry: registry, flutterApi: AdvancedWebViewFlutterApi(binaryMessenger: messenger))
    addTeardownBlock { @MainActor in hostApi.disposeAll() }
    return (hostApi, registry, messenger)
  }

  private func params(
    webViewId: Int64,
    settings: WebViewSettingsMessage? = nil,
    channels: [String] = [],
    handlers: [String] = [],
    handlerObjectName: String = "advanced_webview",
    hasNavigationDelegate: Bool = false,
    hasNewWindowDelegate: Bool = false,
    hasPermissionDelegate: Bool = false,
    hasDownloadDelegate: Bool = false,
    hasSslErrorDelegate: Bool = false,
    hasHttpAuthDelegate: Bool = false,
    hasScrollDelegate: Bool = false,
    hasLongPressDelegate: Bool = false,
    hasConsoleMessageDelegate: Bool = false,
    userScripts: [UserScriptMessage] = []
  ) -> CreationParamsMessage {
    return CreationParamsMessage(
      webViewId: webViewId,
      settings: settings ?? self.settings(),
      javaScriptChannelNames: channels,
      javaScriptHandlerNames: handlers,
      javaScriptHandlerObjectName: handlerObjectName,
      hasNavigationDelegate: hasNavigationDelegate,
      hasNewWindowDelegate: hasNewWindowDelegate,
      hasPermissionDelegate: hasPermissionDelegate,
      hasDownloadDelegate: hasDownloadDelegate,
      hasSslErrorDelegate: hasSslErrorDelegate,
      hasHttpAuthDelegate: hasHttpAuthDelegate,
      hasScrollDelegate: hasScrollDelegate,
      hasLongPressDelegate: hasLongPressDelegate,
      hasConsoleMessageDelegate: hasConsoleMessageDelegate,
      userScripts: userScripts)
  }

  private func settings(
    javaScriptEnabled: Bool = true,
    mediaPlaybackRequiresUserGesture: Bool = true,
    allowsInlineMediaPlayback: Bool = false,
    transparentBackground: Bool = false,
    allowsBackForwardNavigationGestures: Bool = false,
    inspectable: Bool = false,
    textZoom: Int = 100,
    cacheMode: CacheModeMessage = .normal,
    incognito: Bool = false,
    javaScriptCanOpenWindowsAutomatically: Bool = true,
    scrollbarsVisible: Bool = true,
    overScrollEnabled: Bool = true,
    pullToRefreshEnabled: Bool = false,
    domStorageEnabled: Bool = true,
    allowFileAccess: Bool = false,
    allowContentAccess: Bool = false,
    mixedContentMode: MixedContentModeMessage = .neverAllow,
    minimumFontSize: Int? = nil,
    userAgent: String? = nil
  ) -> WebViewSettingsMessage {
    return WebViewSettingsMessage(
      javaScriptEnabled: javaScriptEnabled,
      mediaPlaybackRequiresUserGesture: mediaPlaybackRequiresUserGesture,
      allowsInlineMediaPlayback: allowsInlineMediaPlayback,
      supportZoom: true,
      transparentBackground: transparentBackground,
      passkeysEnabled: false,
      allowsBackForwardNavigationGestures: allowsBackForwardNavigationGestures,
      inspectable: inspectable,
      textZoom: Int64(textZoom),
      cacheMode: cacheMode,
      incognito: incognito,
      javaScriptCanOpenWindowsAutomatically: javaScriptCanOpenWindowsAutomatically,
      scrollbarsVisible: scrollbarsVisible,
      overScrollEnabled: overScrollEnabled,
      pullToRefreshEnabled: pullToRefreshEnabled,
      domStorageEnabled: domStorageEnabled,
      allowFileAccess: allowFileAccess,
      allowContentAccess: allowContentAccess,
      mixedContentMode: mixedContentMode,
      minimumFontSize: minimumFontSize.map { Int64($0) },
      userAgent: userAgent)
  }
}

/// Records outgoing FlutterApi messages; never replies.
private final class FakeBinaryMessenger: NSObject, FlutterBinaryMessenger {
  private(set) var sentChannels: [String] = []

  func send(onChannel channel: String, message: Data?) {
    sentChannels.append(channel)
  }

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    sentChannels.append(channel)
  }

  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    return 0
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
