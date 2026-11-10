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

  func testLoadFileAndAssetReportMissingFiles() throws {
    let (hostApi, _, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))

    XCTAssertThrowsError(try hostApi.loadFile(webViewId: 1, path: "/does/not/exist.html")) {
      XCTAssertEqual(($0 as? PigeonError)?.code, "not-found")
    }
    // The default host API has no asset resolver.
    XCTAssertThrowsError(try hostApi.loadFlutterAsset(webViewId: 1, key: "assets/a.html")) {
      XCTAssertEqual(($0 as? PigeonError)?.code, "not-found")
    }
  }

  func testLoadRequestRejectsAnInvalidUrl() throws {
    let (hostApi, _, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))

    XCTAssertThrowsError(
      try hostApi.loadRequest(webViewId: 1, url: "", method: .post, headers: [:], body: nil)
    ) {
      XCTAssertEqual(($0 as? PigeonError)?.code, "invalid-url")
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

  func testApplicationNameForUserAgentIsAppliedAtCreation() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, settings: settings()))
    try hostApi.create(
      params: params(
        webViewId: 2, settings: settings(applicationNameForUserAgent: "MyApp/1.0")))

    XCTAssertNotEqual(
      try registry.get(1).webView.configuration.applicationNameForUserAgent, "MyApp/1.0")
    XCTAssertEqual(
      try registry.get(2).webView.configuration.applicationNameForUserAgent, "MyApp/1.0")
  }

  func testContentModeIsAppliedAtCreationAndOnUpdate() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, settings: settings(contentMode: .desktop)))
    let preferences: WKWebpagePreferences =
      try registry.get(1).webView.configuration.defaultWebpagePreferences
    XCTAssertEqual(preferences.preferredContentMode, .desktop)

    try hostApi.updateSettings(webViewId: 1, settings: settings(contentMode: .mobile))
    XCTAssertEqual(preferences.preferredContentMode, .mobile)

    try hostApi.updateSettings(webViewId: 1, settings: settings())
    XCTAssertEqual(preferences.preferredContentMode, .recommended)
  }

  func testAllowsLinkPreviewIsAppliedAtCreationAndOnUpdate() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, settings: settings()))
    let webView = try registry.get(1).webView
    XCTAssertTrue(webView.allowsLinkPreview)

    try hostApi.updateSettings(webViewId: 1, settings: settings(allowsLinkPreview: false))
    XCTAssertFalse(webView.allowsLinkPreview)
  }

  func testUserInterfaceStyleIsAppliedAtCreationAndOnUpdate() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1, settings: settings(userInterfaceStyle: .dark)))
    let webView = try registry.get(1).webView
    XCTAssertEqual(webView.overrideUserInterfaceStyle, .dark)

    try hostApi.updateSettings(webViewId: 1, settings: settings(userInterfaceStyle: .light))
    XCTAssertEqual(webView.overrideUserInterfaceStyle, .light)

    try hostApi.updateSettings(webViewId: 1, settings: settings())
    XCTAssertEqual(webView.overrideUserInterfaceStyle, .unspecified)
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
    XCTAssertEqual(hit.matchCount, 2)
    XCTAssertEqual(hit.activeMatchIndex, 0)
    XCTAssertFalse(miss.found)
    XCTAssertEqual(miss.matchCount, 0)
    XCTAssertFalse(empty.found)

    // The same query moves on and wraps; the best-effort index follows.
    let first = try await hostApi.findText(webViewId: 1, query: "alpha", forward: true)
    let second = try await hostApi.findText(webViewId: 1, query: "alpha", forward: true)
    let back = try await hostApi.findText(webViewId: 1, query: "alpha", forward: false)
    XCTAssertEqual(
      [first.activeMatchIndex, second.activeMatchIndex, back.activeMatchIndex], [0, 1, 0])
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

  /// A throw-away client certificate (password "secret"), the same one the integration test uses.
  private static let clientPkcs12Base64 =
    "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"

  func testClientCertificateIdentityLoadsFromPKCS12() throws {
    let data = try XCTUnwrap(Data(base64Encoded: Self.clientPkcs12Base64))

    let credential = AdvancedWebView.credential(fromPKCS12: data, password: "secret")

    XCTAssertNotNil(credential?.identity)
    XCTAssertNil(AdvancedWebView.credential(fromPKCS12: data, password: "wrong"))
    XCTAssertNil(AdvancedWebView.credential(fromPKCS12: Data([1, 2, 3]), password: "secret"))
  }

  @MainActor
  func testPauseResumeAndTimerCallsAreAccepted() async throws {
    let (hostApi, _, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    defer { hostApi.disposeAll() }

    try await hostApi.pause(webViewId: 1)
    try await hostApi.resume(webViewId: 1)
    try hostApi.pauseTimers(webViewId: 1)
    try hostApi.resumeTimers(webViewId: 1)
  }

  @MainActor
  func testZoomCallsReachTheScrollView() throws {
    let (hostApi, _, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    defer { hostApi.disposeAll() }

    XCTAssertEqual(try hostApi.getZoomScale(webViewId: 1), 1)
    // Without a loaded page the scroll view's zoom limits stay at 1, so the
    // calls must be accepted and leave the scale in range.
    try hostApi.setZoomScale(webViewId: 1, scale: 2)
    try hostApi.zoomBy(webViewId: 1, factor: 1.5)
    XCTAssertGreaterThan(try hostApi.getZoomScale(webViewId: 1), 0)
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

  func testDeleteCookiesRemovesOnlyTheMatchingCookies() async throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    let store = try registry.get(1).webView.configuration.websiteDataStore.httpCookieStore
    for (name, domain) in [("a", "delete-me.test"), ("b", "delete-me.test"), ("a", "keep-me.test")]
    {
      await store.setCookie(
        HTTPCookie(properties: [.name: name, .value: "1", .domain: domain, .path: "/"])!)
    }

    try await hostApi.deleteCookie(webViewId: 1, url: "https://delete-me.test/", name: "a")
    var remaining = try await hostApi.getCookies(webViewId: 1, url: "https://delete-me.test/")
    XCTAssertEqual(remaining.map(\.name), ["b"])

    try await hostApi.deleteCookies(webViewId: 1, url: "https://delete-me.test/")
    remaining = try await hostApi.getCookies(webViewId: 1, url: "https://delete-me.test/")
    XCTAssertTrue(remaining.isEmpty)
    let other = try await hostApi.getCookies(webViewId: 1, url: "https://keep-me.test/")
    XCTAssertEqual(other.map(\.name), ["a"])

    try await hostApi.clearCookies(webViewId: 1)
  }

  func testFactoryReturnsTheExistingInstance() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 5))
    let instance = try registry.get(5)

    let view = AdvancedWebViewFactory(registry: registry).create(
      withFrame: .zero, viewIdentifier: 0, arguments: ["webViewId": 5])

    XCTAssertTrue(view === instance)
  }

  // MARK: - In-app browser

  func testOpenInAppBrowserRejectsAnUnknownWebView() {
    let (hostApi, _, _) = makeHostApi()

    XCTAssertThrowsError(try hostApi.openInAppBrowser(params: browserParams(webViewId: 42))) {
      error in
      XCTAssertEqual((error as? PigeonError)?.code, "not-found")
    }
  }

  func testCloseInAppBrowserIsANoOpWhenNotOpen() {
    let (hostApi, _, _) = makeHostApi()

    XCTAssertNoThrow(try hostApi.closeInAppBrowser(webViewId: 1))
  }

  func testInAppBrowserShowsTheWebViewAndReportsClosedOnce() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    let browser = try registry.get(1)
    var closed = 0
    let controller = InAppBrowserViewController(
      browser: browser, params: browserParams(toolbarTitle: "Docs", showUrl: true)
    ) { closed += 1 }

    controller.loadViewIfNeeded()

    XCTAssertTrue(browser.webView.isDescendant(of: controller.view))
    let titleView = controller.navigationItem.titleView as? UIStackView
    XCTAssertEqual((titleView?.arrangedSubviews.first as? UILabel)?.text, "Docs")
    XCTAssertEqual(titleView?.arrangedSubviews.count, 2)
    controller.finish()
    controller.finish()
    XCTAssertEqual(closed, 1)
    XCTAssertNil(browser.webView.superview)
    // The WebView belongs to Dart and is still registered.
    XCTAssertNoThrow(try registry.get(1))
  }

  func testInAppBrowserNavigationButtonsAreOptional() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    let browser = try registry.get(1)

    let shown = InAppBrowserViewController(browser: browser, params: browserParams()) {}
    shown.loadViewIfNeeded()
    XCTAssertEqual(shown.toolbarItems?.count, 4)

    let hidden = InAppBrowserViewController(
      browser: browser, params: browserParams(showNavigationButtons: false)
    ) {}
    hidden.loadViewIfNeeded()
    XCTAssertNil(hidden.toolbarItems)
  }

  func testInAppBrowserCloseButtonLabel() throws {
    let (hostApi, registry, _) = makeHostApi()
    try hostApi.create(params: params(webViewId: 1))
    let controller = InAppBrowserViewController(
      browser: try registry.get(1), params: browserParams(closeButtonLabel: "Done")
    ) {}

    controller.loadViewIfNeeded()

    XCTAssertEqual(controller.navigationItem.leftBarButtonItem?.title, "Done")
  }

  private func browserParams(
    webViewId: Int64 = 1,
    toolbarTitle: String? = nil,
    showUrl: Bool = false,
    showNavigationButtons: Bool = true,
    closeButtonLabel: String? = nil
  ) -> InAppBrowserParamsMessage {
    return InAppBrowserParamsMessage(
      webViewId: webViewId, showUrl: showUrl, showNavigationButtons: showNavigationButtons,
      toolbarColor: nil, toolbarTitle: toolbarTitle, closeButtonLabel: closeButtonLabel)
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
    hasClientCertDelegate: Bool = false,
    hasScrollDelegate: Bool = false,
    hasLongPressDelegate: Bool = false,
    hasConsoleMessageDelegate: Bool = false,
    hasJsDialogDelegate: Bool = false,
    hasHttpErrorDelegate: Bool = false,
    hasFindDelegate: Bool = false,
    hasFaviconDelegate: Bool = false,
    hasFullscreenDelegate: Bool = false,
    interceptSchemes: [String] = [],
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
      hasClientCertDelegate: hasClientCertDelegate,
      hasScrollDelegate: hasScrollDelegate,
      hasLongPressDelegate: hasLongPressDelegate,
      hasConsoleMessageDelegate: hasConsoleMessageDelegate,
      hasJsDialogDelegate: hasJsDialogDelegate,
      hasHttpErrorDelegate: hasHttpErrorDelegate,
      hasFindDelegate: hasFindDelegate,
      hasFaviconDelegate: hasFaviconDelegate,
      hasFullscreenDelegate: hasFullscreenDelegate,
      interceptSchemes: interceptSchemes,
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
    contentMode: ContentModeMessage = .recommended,
    allowsLinkPreview: Bool = true,
    geolocationEnabled: Bool = true,
    algorithmicDarkeningAllowed: Bool = false,
    thirdPartyCookiesEnabled: Bool = false,
    safeBrowsingEnabled: Bool = true,
    userInterfaceStyle: UserInterfaceStyleMessage = .unspecified,
    minimumFontSize: Int? = nil,
    userAgent: String? = nil,
    applicationNameForUserAgent: String? = nil
  ) -> WebViewSettingsMessage {
    return WebViewSettingsMessage(
      javaScriptEnabled: javaScriptEnabled,
      mediaPlaybackRequiresUserGesture: mediaPlaybackRequiresUserGesture,
      allowsInlineMediaPlayback: allowsInlineMediaPlayback,
      supportZoom: true,
      builtInZoomControls: true,
      displayZoomControls: false,
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
      contentMode: contentMode,
      allowsLinkPreview: allowsLinkPreview,
      geolocationEnabled: geolocationEnabled,
      algorithmicDarkeningAllowed: algorithmicDarkeningAllowed,
      thirdPartyCookiesEnabled: thirdPartyCookiesEnabled,
      safeBrowsingEnabled: safeBrowsingEnabled,
      userInterfaceStyle: userInterfaceStyle,
      minimumFontSize: minimumFontSize.map { Int64($0) },
      userAgent: userAgent,
      applicationNameForUserAgent: applicationNameForUserAgent)
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
