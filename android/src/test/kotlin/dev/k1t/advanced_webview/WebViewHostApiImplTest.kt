package dev.k1t.advanced_webview

import android.app.Activity
import android.graphics.Color
import android.net.Uri
import android.net.http.SslError
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.webkit.ClientCertRequest
import android.webkit.ConsoleMessage
import android.webkit.GeolocationPermissions
import android.webkit.HttpAuthHandler
import android.webkit.JsPromptResult
import android.webkit.JsResult
import android.webkit.PermissionRequest
import android.webkit.SslErrorHandler
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.eq
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WebViewHostApiImplTest {
    private lateinit var messenger: BinaryMessenger
    private lateinit var scope: CoroutineScope
    private lateinit var registry: WebViewRegistry
    private lateinit var hostApi: WebViewHostApiImpl

    @Before
    fun setUp() {
        messenger = mock(BinaryMessenger::class.java)
        scope = MainScope()
        registry = WebViewRegistry()
        hostApi = WebViewHostApiImpl(
            RuntimeEnvironment.getApplication(),
            registry,
            AdvancedWebViewFlutterApi(messenger),
            scope,
        )
    }

    @After
    fun tearDown() {
        hostApi.disposeAll()
        scope.cancel()
    }

    @Test
    fun createRegistersTheWebViewById() {
        hostApi.create(params(webViewId = 7))

        assertEquals(7L, registry.get(7).id)
    }

    @Test
    fun createRejectsADuplicateId() {
        hostApi.create(params(webViewId = 1))

        assertFailsWith<IllegalStateException> { hostApi.create(params(webViewId = 1)) }
    }

    @Test
    fun unknownIdThrowsNotFound() {
        val error = assertFailsWith<FlutterError> { hostApi.reload(42) }

        assertEquals("not-found", error.code)
    }

    @Test
    fun disposeDestroysAndUnregisters() {
        hostApi.create(params(webViewId = 1))
        val webView = registry.get(1).webView

        hostApi.dispose(1)

        assertTrue(shadowOf(webView).wasDestroyCalled())
        assertFailsWith<FlutterError> { registry.get(1) }
        // Disposing twice is harmless.
        hostApi.dispose(1)
    }

    @Test
    fun loadUrlForwardsUrlAndHeaders() {
        hostApi.create(params(webViewId = 1))

        hostApi.loadUrl(1, "https://example.com/", mapOf("X-Test" to "1"))

        val shadow = shadowOf(registry.get(1).webView)
        assertEquals("https://example.com/", shadow.lastLoadedUrl)
        assertEquals(mapOf("X-Test" to "1"), shadow.lastAdditionalHttpHeaders)
    }

    @Test
    fun loadHtmlStringUsesTheBaseUrl() {
        hostApi.create(params(webViewId = 1))

        hostApi.loadHtmlString(1, "<p>hi</p>", "https://example.com/")

        val load = shadowOf(registry.get(1).webView).lastLoadDataWithBaseURL
        assertEquals("https://example.com/", load.baseUrl)
        assertEquals("<p>hi</p>", load.data)
        assertEquals("text/html", load.mimeType)
    }

    @Test
    fun settingsAreAppliedAtCreationAndOnUpdate() {
        hostApi.create(
            params(webViewId = 1, settings = settings(javaScriptEnabled = false, userAgent = "ua-1")),
        )
        val webView = registry.get(1).webView
        assertFalse(webView.settings.javaScriptEnabled)
        assertEquals("ua-1", webView.settings.userAgentString)

        hostApi.updateSettings(
            1,
            settings(javaScriptEnabled = true, supportZoom = false, transparentBackground = true, userAgent = "ua-2"),
        )

        assertTrue(webView.settings.javaScriptEnabled)
        assertFalse(webView.settings.supportZoom())
        assertEquals("ua-2", webView.settings.userAgentString)
        assertEquals(Color.TRANSPARENT, shadowOf(webView).backgroundColor)
    }

    @Test
    fun zoomControlSettingsAreAppliedAtCreationAndOnUpdate() {
        hostApi.create(params(webViewId = 1))
        val nativeSettings = registry.get(1).webView.settings
        assertTrue(nativeSettings.builtInZoomControls)
        assertFalse(nativeSettings.displayZoomControls)

        hostApi.updateSettings(1, settings(builtInZoomControls = false, displayZoomControls = true))

        assertFalse(nativeSettings.builtInZoomControls)
        assertTrue(nativeSettings.displayZoomControls)
    }

    @Test
    fun cacheModeIsAppliedAtCreationAndOnUpdate() {
        hostApi.create(params(webViewId = 1, settings = settings(cacheMode = CacheModeMessage.CACHE_ONLY)))
        val nativeSettings = registry.get(1).webView.settings
        assertEquals(WebSettings.LOAD_CACHE_ONLY, nativeSettings.cacheMode)

        hostApi.updateSettings(1, settings(cacheMode = CacheModeMessage.NO_CACHE))

        assertEquals(WebSettings.LOAD_NO_CACHE, nativeSettings.cacheMode)
    }

    @Test
    fun securitySettingsAreSafeByDefaultAndApplyOnUpdate() {
        hostApi.create(params(webViewId = 1))
        val nativeSettings = registry.get(1).webView.settings
        assertTrue(nativeSettings.domStorageEnabled)
        assertFalse(nativeSettings.allowFileAccess)
        assertFalse(nativeSettings.allowContentAccess)
        assertEquals(WebSettings.MIXED_CONTENT_NEVER_ALLOW, nativeSettings.mixedContentMode)

        hostApi.updateSettings(
            1,
            settings(
                domStorageEnabled = false,
                allowFileAccess = true,
                allowContentAccess = true,
                mixedContentMode = MixedContentModeMessage.COMPATIBILITY,
            ),
        )

        assertFalse(nativeSettings.domStorageEnabled)
        assertTrue(nativeSettings.allowFileAccess)
        assertTrue(nativeSettings.allowContentAccess)
        assertEquals(WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE, nativeSettings.mixedContentMode)
    }

    @Test
    fun geolocationSettingCanBeAppliedAtCreationAndOnUpdate() {
        // WebSettings has no public getter for this flag, so this only checks that applying it works.
        hostApi.create(params(webViewId = 1, settings = settings(geolocationEnabled = false)))

        hostApi.updateSettings(1, settings(geolocationEnabled = true))
    }

    @Test
    fun windowAndScrollSettingsAreAppliedAtCreationAndOnUpdate() {
        hostApi.create(params(webViewId = 1, settings = settings()))
        val webView = registry.get(1).webView
        assertTrue(webView.settings.javaScriptCanOpenWindowsAutomatically)
        assertTrue(webView.isVerticalScrollBarEnabled)
        assertTrue(webView.isHorizontalScrollBarEnabled)
        assertEquals(View.OVER_SCROLL_IF_CONTENT_SCROLLS, webView.overScrollMode)

        hostApi.updateSettings(
            1,
            settings(
                javaScriptCanOpenWindowsAutomatically = false,
                scrollbarsVisible = false,
                overScrollEnabled = false,
            ),
        )

        assertFalse(webView.settings.javaScriptCanOpenWindowsAutomatically)
        assertFalse(webView.isVerticalScrollBarEnabled)
        assertFalse(webView.isHorizontalScrollBarEnabled)
        assertEquals(View.OVER_SCROLL_NEVER, webView.overScrollMode)
    }

    @Test
    fun pauseResumeAndTimersReachTheWebView() = runBlocking(Dispatchers.Unconfined) {
        hostApi.create(params(webViewId = 1))

        // Robolectric does not expose the paused state; the calls must at least be accepted.
        hostApi.pause(1)
        hostApi.resume(1)
        hostApi.pauseTimers(1)
        hostApi.resumeTimers(1)
    }

    @Test
    fun findCompletesWhenTheWebViewFinishesCounting() = runBlocking(Dispatchers.Unconfined) {
        hostApi.create(params(webViewId = 1))
        val view = registry.get(1)

        val search = async(start = CoroutineStart.UNDISPATCHED) { view.find("abc", true) }
        view.onFindResult(0, 3, false)
        assertTrue(search.isActive)
        view.onFindResult(1, 3, true)

        assertEquals(FindResultMessage(found = true, matchCount = 3, activeMatchIndex = 1), search.await())

        val miss = async(start = CoroutineStart.UNDISPATCHED) { view.find("zzz", true) }
        view.onFindResult(0, 0, true)
        assertEquals(FindResultMessage(found = false, matchCount = 0, activeMatchIndex = null), miss.await())
    }

    @Test
    fun findProgressIsForwardedToDartOnlyWithADelegate() {
        hostApi.create(params(webViewId = 1))
        hostApi.create(params(webViewId = 2, hasFindDelegate = true))
        val channel = "dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onFindResult"

        registry.get(1).onFindResult(0, 3, true)
        shadowOf(Looper.getMainLooper()).idle()
        verify(messenger, never()).send(eq(channel), any(), any())

        registry.get(2).onFindResult(0, 1, false)
        registry.get(2).onFindResult(1, 3, true)
        shadowOf(Looper.getMainLooper()).idle()
        verify(messenger, org.mockito.Mockito.times(2)).send(eq(channel), any(), any())
    }

    @Test
    fun fullscreenCoversTheActivityAndIsReportedOnlyWithADelegate() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        hostApi.create(params(webViewId = 1, hasFullscreenDelegate = true))
        val view = registry.get(1)
        view.attachToContext(activity)
        val decor = activity.window.decorView as ViewGroup
        val before = decor.childCount
        val video = View(activity)
        val callback = mock(WebChromeClient.CustomViewCallback::class.java)
        val enter = "dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onEnterFullscreen"
        val exit = "dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onExitFullscreen"

        view.webView.webChromeClient!!.onShowCustomView(video, callback)
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(before + 1, decor.childCount)
        assertSame(decor, (video.parent as View).parent)
        verify(messenger).send(eq(enter), any(), any())

        view.webView.webChromeClient!!.onHideCustomView()
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(before, decor.childCount)
        verify(callback).onCustomViewHidden()
        verify(messenger).send(eq(exit), any(), any())
    }

    @Test
    fun fullscreenIsRefusedWithoutAnActivityAndNotReportedWithoutADelegate() {
        hostApi.create(params(webViewId = 1))
        val callback = mock(WebChromeClient.CustomViewCallback::class.java)

        registry.get(1).webView.webChromeClient!!.onShowCustomView(View(RuntimeEnvironment.getApplication()), callback)
        shadowOf(Looper.getMainLooper()).idle()

        verify(callback).onCustomViewHidden()
        verify(messenger, never()).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onEnterFullscreen"),
            any(),
            any(),
        )
    }

    @Test
    fun theFaviconIsOnlyLookedUpWithADelegate() {
        hostApi.create(params(webViewId = 1))
        hostApi.create(params(webViewId = 2, hasFaviconDelegate = true))

        // No JavaScript runs in Robolectric, so only the absence of a reply from a view without a delegate
        // can be checked here; the page markup lookup is covered by the integration test.
        registry.get(1).webView.webViewClient.onPageFinished(registry.get(1).webView, "https://a.test/")
        registry.get(2).webView.webViewClient.onPageFinished(registry.get(2).webView, "https://a.test/")
        shadowOf(Looper.getMainLooper()).idle()

        verify(messenger, never()).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onFaviconChanged"),
            any(),
            any(),
        )
    }

    @Test
    fun emptyFindQueryClearsAndReportsNoMatch() = runBlocking(Dispatchers.Unconfined) {
        hostApi.create(params(webViewId = 1))

        assertEquals(FindResultMessage(found = false, matchCount = 0), registry.get(1).find("", true))
    }

    @Test
    fun printPageFailsWithoutAnActivity() {
        hostApi.create(params(webViewId = 1))

        val error = assertFailsWith<FlutterError> { hostApi.printPage(1, null) }

        assertEquals("not-attached", error.code)
    }

    @Test
    fun saveStateReturnsMarshalledBytes() {
        // Robolectric cannot unmarshall parcels or restore a WebView, so restoring is covered by the
        // integration test.
        hostApi.create(params(webViewId = 1))

        assertNotNull(hostApi.saveState(1))
    }

    @Test
    fun scrollToByAndPositionUseLogicalPixels() {
        hostApi.create(params(webViewId = 1))
        val webView = registry.get(1).webView
        webView.layout(0, 0, 100, 100)
        val density = webView.resources.displayMetrics.density.toDouble()

        hostApi.scrollTo(1, 10.0, 20.0)
        hostApi.scrollBy(1, 5.0, -5.0)

        val position = hostApi.getScrollPosition(1)
        assertEquals(15.0, position.x, 1.0 / density)
        assertEquals(15.0, position.y, 1.0 / density)
    }

    @Test
    fun takeScreenshotReturnsNullWithoutSizeAndPngOnceLaidOut() {
        hostApi.create(params(webViewId = 1))
        val view = registry.get(1)
        val webView = view.webView
        assertNull(view.takeScreenshot())

        // Robolectric's WebView ignores layout(); set the frame directly.
        webView.right = 40
        webView.bottom = 30
        val png = view.takeScreenshot()

        // Robolectric's Bitmap.compress does not write real PNG bytes; check only for output.
        assertNotNull(png)
        assertTrue(png!!.isNotEmpty())
    }

    @Test
    fun textZoomAndMinimumFontSizeAreApplied() {
        hostApi.create(params(webViewId = 1, settings = settings(textZoom = 150, minimumFontSize = 14)))
        val nativeSettings = registry.get(1).webView.settings
        assertEquals(150, nativeSettings.textZoom)
        assertEquals(14, nativeSettings.minimumFontSize)

        hostApi.updateSettings(1, settings())

        assertEquals(100, nativeSettings.textZoom)
        assertEquals(8, nativeSettings.minimumFontSize)
    }

    @Test
    fun passkeysCanBeEnabledAndDisabledOnTheSameWebView() {
        mockStatic(WebViewFeature::class.java).use { features ->
            features.`when`<Boolean> { WebViewFeature.isFeatureSupported(WebViewFeature.WEB_AUTHENTICATION) }
                .thenReturn(true)
            mockStatic(WebSettingsCompat::class.java).use { compat ->
                hostApi.create(params(webViewId = 1, settings = settings(passkeysEnabled = true)))
                val nativeSettings = registry.get(1).webView.settings
                compat.verify {
                    WebSettingsCompat.setWebAuthenticationSupport(
                        nativeSettings,
                        WebSettingsCompat.WEB_AUTHENTICATION_SUPPORT_FOR_APP,
                    )
                }
                compat.clearInvocations()
                hostApi.updateSettings(1, settings(passkeysEnabled = false))
                compat.verify {
                    WebSettingsCompat.setWebAuthenticationSupport(
                        nativeSettings,
                        WebSettingsCompat.WEB_AUTHENTICATION_SUPPORT_NONE,
                    )
                }
            }
        }
    }

    @Test
    fun unsupportedWebAuthenticationRemainsANoOp() {
        mockStatic(WebViewFeature::class.java).use { features ->
            features.`when`<Boolean> { WebViewFeature.isFeatureSupported(WebViewFeature.WEB_AUTHENTICATION) }
                .thenReturn(false)
            mockStatic(WebSettingsCompat::class.java).use { compat ->
                hostApi.create(params(webViewId = 1, settings = settings(passkeysEnabled = true)))
                hostApi.updateSettings(1, settings(passkeysEnabled = false))
                compat.verifyNoInteractions()
            }
        }
    }

    @Test
    fun javaScriptChannelsForwardMessagesToDart() {
        hostApi.create(params(webViewId = 3, channels = listOf("Echo")))
        val channel = shadowOf(registry.get(3).webView).getJavascriptInterface("Echo")
        assertNotNull(channel)

        channel.javaClass.getMethod("postMessage", String::class.java).invoke(channel, "hi")
        shadowOf(Looper.getMainLooper()).idle()

        verify(messenger).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onJavaScriptMessage"),
            any(),
            any(),
        )
    }

    @Test
    fun javaScriptHandlersInstallTheBridgeAndShim() {
        mockStatic(WebViewFeature::class.java).use { features ->
            features.`when`<Boolean> { WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER) }
                .thenReturn(true)
            features.`when`<Boolean> { WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT) }
                .thenReturn(true)
            mockStatic(WebViewCompat::class.java).use { compat ->
                hostApi.create(params(webViewId = 1, handlers = listOf("sum")))
                val webView = registry.get(1).webView

                compat.verify {
                    WebViewCompat.addWebMessageListener(
                        eq(webView),
                        eq("advancedWebViewBridge"),
                        eq(setOf("*")),
                        any<WebViewCompat.WebMessageListener>(),
                    )
                }
                compat.verify {
                    WebViewCompat.addDocumentStartJavaScript(eq(webView), any<String>(), eq(setOf("*")))
                }
            }
        }
    }

    @Test
    fun handlerShimUsesTheConfiguredObjectName() {
        val shim = AdvancedWebView.handlerShim("bridge")

        assertTrue(shim.contains("window.bridge = Object.freeze"))
    }

    @Test
    fun sslErrorsAreRefusedWithoutADelegate() {
        hostApi.create(params(webViewId = 1, hasSslErrorDelegate = false))
        val handler = mock(SslErrorHandler::class.java)

        registry.get(1).webView.webViewClient.onReceivedSslError(
            registry.get(1).webView,
            handler,
            mock(SslError::class.java),
        )

        verify(handler).cancel()
        verify(handler, never()).proceed()
    }

    @Test
    fun consoleMessagesAreForwardedToDartAndKeepPlatformLogging() {
        hostApi.create(params(webViewId = 1, hasConsoleMessageDelegate = true))
        val message = ConsoleMessage("careful", "https://a.test/app.js", 7, ConsoleMessage.MessageLevel.WARNING)

        val handled = registry.get(1).webView.webChromeClient!!.onConsoleMessage(message)
        shadowOf(Looper.getMainLooper()).idle()

        assertFalse(handled)
        verify(messenger).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onConsoleMessage"),
            any(),
            any(),
        )
    }

    @Test
    fun postRequestsCannotCarryCustomHeadersOnAndroid() {
        hostApi.create(params(webViewId = 1))

        val error = assertFailsWith<FlutterError> {
            hostApi.loadRequest(1, "https://a.test/", HttpMethodMessage.POST, mapOf("X" to "1"), null)
        }

        assertEquals("unsupported", error.code)
        hostApi.loadRequest(1, "https://a.test/", HttpMethodMessage.POST, emptyMap(), byteArrayOf(1))
    }

    @Test
    fun loadFileNeedsFileAccess() {
        hostApi.create(params(webViewId = 1, settings = settings(allowFileAccess = false)))
        hostApi.create(params(webViewId = 2, settings = settings(allowFileAccess = true)))

        val error = assertFailsWith<FlutterError> { hostApi.loadFile(1, "/data/local/tmp/a.html") }

        assertEquals("file-access-disabled", error.code)
        hostApi.loadFile(2, "/data/local/tmp/a.html")
        assertEquals("file:///data/local/tmp/a.html", registry.get(2).webView.url)
    }

    @Test
    fun flutterAssetsLoadFromTheVirtualAssetHost() {
        hostApi.create(params(webViewId = 1))

        hostApi.loadFlutterAsset(1, "assets/a.html")

        assertEquals(
            "https://appassets.androidplatform.net/assets/flutter_assets/assets/a.html",
            registry.get(1).webView.url,
        )
    }

    @Test
    fun httpErrorsAreForwardedToDartOnlyWithADelegate() {
        val response = WebResourceResponse("text/html", "utf-8", 503, "Unavailable", emptyMap(), null)
        val request = mock(WebResourceRequest::class.java)
        org.mockito.Mockito.`when`(request.url).thenReturn(Uri.parse("https://a.test/"))
        org.mockito.Mockito.`when`(request.isForMainFrame).thenReturn(true)
        hostApi.create(params(webViewId = 1))
        hostApi.create(params(webViewId = 2, hasHttpErrorDelegate = true))

        registry.get(1).webView.webViewClient.onReceivedHttpError(registry.get(1).webView, request, response)
        shadowOf(Looper.getMainLooper()).idle()
        verify(messenger, never()).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onReceivedHttpError"),
            any(),
            any(),
        )

        registry.get(2).webView.webViewClient.onReceivedHttpError(registry.get(2).webView, request, response)
        shadowOf(Looper.getMainLooper()).idle()
        verify(messenger).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onReceivedHttpError"),
            any(),
            any(),
        )
    }

    @Test
    fun interceptedRequestsAreAnsweredByDartOnAnIoThread() {
        hostApi.create(params(webViewId = 1, interceptSchemes = listOf("app")))
        val view = registry.get(1)
        val answer = InterceptResponseMessage(
            statusCode = 201,
            mimeType = "text/html; charset=utf-8",
            headers = mapOf("X-A" to "b", "content-type" to "ignored"),
            body = "<p>hi</p>".toByteArray(),
        )
        `when`(messenger.send(eq(INTERCEPT_CHANNEL), any(), any())).thenAnswer {
            val reply = it.getArgument<BinaryMessenger.BinaryReply>(2)
            val encoded = AdvancedWebViewFlutterApi.codec.encodeMessage(listOf(answer))!!
            encoded.rewind()
            reply.reply(encoded)
        }

        val response =
            onIoThread { view.webView.webViewClient.shouldInterceptRequest(view.webView, request("app://a/")) }

        assertNotNull(response)
        assertEquals(201, response.statusCode)
        assertEquals("text/html", response.mimeType)
        assertEquals("utf-8", response.encoding)
        assertEquals(mapOf("X-A" to "b"), response.responseHeaders)
        assertEquals("<p>hi</p>", response.data.readBytes().decodeToString())
    }

    @Test
    fun otherSchemesAndUnansweredRequestsAreLetThrough() {
        hostApi.create(params(webViewId = 1, interceptSchemes = listOf("app")))
        val view = registry.get(1)
        view.interceptTimeoutMillis = 100

        assertNull(
            onIoThread { view.webView.webViewClient.shouldInterceptRequest(view.webView, request("https://a.test/")) },
        )
        verify(messenger, never()).send(eq(INTERCEPT_CHANNEL), any(), any())

        // Dart never replies: the request goes on to the network.
        assertNull(onIoThread { view.webView.webViewClient.shouldInterceptRequest(view.webView, request("app://a/")) })
        verify(messenger).send(eq(INTERCEPT_CHANNEL), any(), any())
    }

    @Test
    fun redirectStatusesCannotBeInterceptedOnAndroid() {
        val redirect = InterceptResponseMessage(302, "text/plain", mapOf("Location" to "/x"), ByteArray(0))

        assertNull(redirect.toWebResourceResponse())
    }

    private fun request(url: String): WebResourceRequest {
        val request = mock(WebResourceRequest::class.java)
        `when`(request.url).thenReturn(Uri.parse(url))
        `when`(request.method).thenReturn("GET")
        `when`(request.requestHeaders).thenReturn(emptyMap())
        `when`(request.isForMainFrame).thenReturn(false)
        return request
    }

    /** Runs [block] like a WebView IO thread would, while the main looper keeps serving the answer. */
    private fun <T> onIoThread(block: () -> T): T {
        var result: Result<T>? = null
        val thread = Thread { result = runCatching(block) }
        thread.start()
        while (thread.isAlive) {
            shadowOf(Looper.getMainLooper()).idle()
            Thread.sleep(5)
        }
        return result!!.getOrThrow()
    }

    @Test
    fun javaScriptDialogsAreForwardedToDartWhenThereIsADelegate() {
        hostApi.create(params(webViewId = 1, hasJsDialogDelegate = true))
        val client = registry.get(1).webView.webChromeClient!!

        val handled = client.onJsAlert(registry.get(1).webView, "https://a.test/", "hi", mock(JsResult::class.java))
        shadowOf(Looper.getMainLooper()).idle()

        assertTrue(handled)
        verify(messenger).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onJsDialog"),
            any(),
            any(),
        )
    }

    @Test
    fun javaScriptDialogsUseThePlatformDefaultWithoutADelegate() {
        hostApi.create(params(webViewId = 1))
        val webView = registry.get(1).webView
        val client = webView.webChromeClient!!

        assertFalse(client.onJsAlert(webView, "https://a.test/", "hi", mock(JsResult::class.java)))
        assertFalse(client.onJsConfirm(webView, "https://a.test/", "ok?", mock(JsResult::class.java)))
        assertFalse(client.onJsPrompt(webView, "https://a.test/", "name?", "x", mock(JsPromptResult::class.java)))
        verify(messenger, never()).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onJsDialog"),
            any(),
            any(),
        )
    }

    @Test
    fun consoleMessagesAreNotForwardedWithoutADelegate() {
        hostApi.create(params(webViewId = 1))
        val message = ConsoleMessage("quiet", "", 1, ConsoleMessage.MessageLevel.LOG)

        registry.get(1).webView.webChromeClient!!.onConsoleMessage(message)
        shadowOf(Looper.getMainLooper()).idle()

        verify(messenger, never()).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onConsoleMessage"),
            any(),
            any(),
        )
    }

    @Test
    fun sslErrorsAreForwardedToDart() {
        hostApi.create(params(webViewId = 1, hasSslErrorDelegate = true))
        val error = mock(SslError::class.java)
        `when`(error.url).thenReturn("https://expired.test/")
        `when`(error.primaryError).thenReturn(SslError.SSL_EXPIRED)

        registry.get(1).webView.webViewClient.onReceivedSslError(
            registry.get(1).webView,
            mock(SslErrorHandler::class.java),
            error,
        )
        shadowOf(Looper.getMainLooper()).idle()

        verify(messenger).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onSslError"),
            any(),
            any(),
        )
    }

    @Test
    fun httpAuthIsCancelledWithoutADelegate() {
        hostApi.create(params(webViewId = 1, hasHttpAuthDelegate = false))
        val handler = mock(HttpAuthHandler::class.java)

        registry.get(1).webView.webViewClient.onReceivedHttpAuthRequest(
            registry.get(1).webView,
            handler,
            "a.test",
            "private",
        )

        verify(handler).cancel()
    }

    @Test
    fun httpAuthIsForwardedToDart() {
        hostApi.create(params(webViewId = 1, hasHttpAuthDelegate = true))

        registry.get(1).webView.webViewClient.onReceivedHttpAuthRequest(
            registry.get(1).webView,
            mock(HttpAuthHandler::class.java),
            "a.test",
            "private",
        )
        shadowOf(Looper.getMainLooper()).idle()

        verify(messenger).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onHttpAuthRequest"),
            any(),
            any(),
        )
    }

    @Test
    fun clientCertRequestsAreCancelledWithoutADelegate() {
        hostApi.create(params(webViewId = 1, hasClientCertDelegate = false))
        val request = mock(ClientCertRequest::class.java)

        registry.get(1).webView.webViewClient.onReceivedClientCertRequest(registry.get(1).webView, request)

        verify(request).cancel()
    }

    @Test
    fun clientCertRequestsAreForwardedToDart() {
        hostApi.create(params(webViewId = 1, hasClientCertDelegate = true))
        val request = mock(ClientCertRequest::class.java)
        `when`(request.host).thenReturn("a.test")
        `when`(request.port).thenReturn(8443)

        registry.get(1).webView.webViewClient.onReceivedClientCertRequest(registry.get(1).webView, request)
        shadowOf(Looper.getMainLooper()).idle()

        verify(messenger).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onClientCertRequest"),
            any(),
            any(),
        )
    }

    @Test
    fun downloadsAreOnlyInterceptedWithADelegate() {
        hostApi.create(params(webViewId = 1, hasDownloadDelegate = false))

        assertNull(shadowOf(registry.get(1).webView).downloadListener)
    }

    @Test
    fun downloadsAreForwardedToDart() {
        hostApi.create(params(webViewId = 1, hasDownloadDelegate = true))
        val listener = shadowOf(registry.get(1).webView).downloadListener
        assertNotNull(listener)

        listener.onDownloadStart(
            "https://example.com/a.pdf",
            "ua",
            "attachment; filename=\"a.pdf\"",
            "application/pdf",
            42,
        )
        shadowOf(Looper.getMainLooper()).idle()

        verify(messenger).send(
            eq("dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onDownloadStart"),
            any(),
            any(),
        )
    }

    @Test
    fun mediaPermissionsAreDeniedWithoutADelegate() {
        hostApi.create(params(webViewId = 1, hasPermissionDelegate = false))
        val request = mock(PermissionRequest::class.java)
        `when`(request.resources).thenReturn(arrayOf(PermissionRequest.RESOURCE_VIDEO_CAPTURE))

        registry.get(1).webView.webChromeClient!!.onPermissionRequest(request)

        verify(request).deny()
    }

    @Test
    fun resourcesWithoutADartEquivalentAreDenied() {
        hostApi.create(params(webViewId = 1, hasPermissionDelegate = true))
        val request = mock(PermissionRequest::class.java)
        `when`(request.resources).thenReturn(arrayOf(PermissionRequest.RESOURCE_PROTECTED_MEDIA_ID))

        registry.get(1).webView.webChromeClient!!.onPermissionRequest(request)

        verify(request).deny()
    }

    @Test
    fun geolocationIsDeniedWithoutADelegate() {
        hostApi.create(params(webViewId = 1, hasPermissionDelegate = false))
        val callback = mock(GeolocationPermissions.Callback::class.java)

        registry.get(1).webView.webChromeClient!!.onGeolocationPermissionsShowPrompt("https://a.test", callback)

        verify(callback).invoke("https://a.test", false, false)
    }

    @Test
    fun noBridgeIsInstalledWithoutHandlers() {
        mockStatic(WebViewCompat::class.java).use { compat ->
            hostApi.create(params(webViewId = 1))
            compat.verifyNoInteractions()
        }
    }

    @Test
    fun javaScriptHandlersNeedWebMessageListenerSupport() {
        mockStatic(WebViewFeature::class.java).use { features ->
            features.`when`<Boolean> { WebViewFeature.isFeatureSupported(any()) }.thenReturn(false)

            assertFailsWith<IllegalStateException> {
                hostApi.create(params(webViewId = 1, handlers = listOf("sum")))
            }
        }
    }

    @Test
    fun navigationIsNotInterceptedWithoutADelegate() {
        hostApi.create(params(webViewId = 1, hasNavigationDelegate = false))
        val webView = registry.get(1).webView

        assertFalse(shouldOverride(webView, "https://example.com/", isMainFrame = true))
    }

    @Test
    fun onlyMainFrameNavigationsAreSentToTheDelegate() {
        hostApi.create(params(webViewId = 1, hasNavigationDelegate = true))
        val webView = registry.get(1).webView

        // Main frame: cancelled now, re-loaded once Dart allows it.
        assertTrue(shouldOverride(webView, "https://example.com/", isMainFrame = true))
        assertFalse(shouldOverride(webView, "https://example.com/frame", isMainFrame = false))
    }

    @Test
    fun factoryReturnsTheExistingInstanceAndDetachesIt() {
        hostApi.create(params(webViewId = 5))
        val instance = registry.get(5)
        val oldParent = FrameLayout(RuntimeEnvironment.getApplication())
        oldParent.addView(instance.container)

        val view = AdvancedWebViewFactory(registry)
            .create(RuntimeEnvironment.getApplication(), 0, mapOf("webViewId" to 5))

        assertSame(instance, view)
        assertNull(instance.container.parent)
        assertSame(instance.container, instance.view)
    }

    @Test
    fun pullToRefreshIsOffByDefaultAndReloadsWhenEnabled() {
        hostApi.create(params(webViewId = 1))
        val instance = registry.get(1)
        assertFalse(instance.container.isEnabled)
        assertSame(instance.webView, instance.container.getChildAt(0))

        hostApi.updateSettings(1, settings(pullToRefreshEnabled = true))
        assertTrue(instance.container.isEnabled)

        hostApi.updateSettings(1, settings(pullToRefreshEnabled = false))
        assertFalse(instance.container.isEnabled)
    }

    private fun shouldOverride(webView: WebView, url: String, isMainFrame: Boolean): Boolean {
        val request = mock(WebResourceRequest::class.java)
        `when`(request.url).thenReturn(Uri.parse(url))
        `when`(request.isForMainFrame).thenReturn(isMainFrame)
        return shadowOf(webView).webViewClient.shouldOverrideUrlLoading(webView, request)
    }

    private fun params(
        webViewId: Long,
        settings: WebViewSettingsMessage = settings(),
        channels: List<String> = emptyList(),
        handlers: List<String> = emptyList(),
        handlerObjectName: String = "advanced_webview",
        hasNavigationDelegate: Boolean = false,
        hasNewWindowDelegate: Boolean = false,
        hasPermissionDelegate: Boolean = false,
        hasDownloadDelegate: Boolean = false,
        hasSslErrorDelegate: Boolean = false,
        hasHttpAuthDelegate: Boolean = false,
        hasClientCertDelegate: Boolean = false,
        hasScrollDelegate: Boolean = false,
        hasLongPressDelegate: Boolean = false,
        hasConsoleMessageDelegate: Boolean = false,
        hasJsDialogDelegate: Boolean = false,
        hasHttpErrorDelegate: Boolean = false,
        hasFindDelegate: Boolean = false,
        hasFaviconDelegate: Boolean = false,
        hasFullscreenDelegate: Boolean = false,
        interceptSchemes: List<String> = emptyList(),
        userScripts: List<UserScriptMessage> = emptyList(),
    ) = CreationParamsMessage(
        webViewId,
        settings,
        channels,
        handlers,
        handlerObjectName,
        hasNavigationDelegate,
        hasNewWindowDelegate,
        hasPermissionDelegate,
        hasDownloadDelegate,
        hasSslErrorDelegate,
        hasHttpAuthDelegate,
        hasClientCertDelegate,
        hasScrollDelegate,
        hasLongPressDelegate,
        hasConsoleMessageDelegate,
        hasJsDialogDelegate,
        hasHttpErrorDelegate,
        hasFindDelegate,
        hasFaviconDelegate,
        hasFullscreenDelegate,
        interceptSchemes,
        userScripts,
    )

    private fun settings(
        javaScriptEnabled: Boolean = true,
        supportZoom: Boolean = true,
        builtInZoomControls: Boolean = true,
        displayZoomControls: Boolean = false,
        transparentBackground: Boolean = false,
        userAgent: String? = null,
        passkeysEnabled: Boolean = false,
        inspectable: Boolean = false,
        textZoom: Long = 100,
        cacheMode: CacheModeMessage = CacheModeMessage.NORMAL,
        incognito: Boolean = false,
        javaScriptCanOpenWindowsAutomatically: Boolean = true,
        scrollbarsVisible: Boolean = true,
        overScrollEnabled: Boolean = true,
        pullToRefreshEnabled: Boolean = false,
        domStorageEnabled: Boolean = true,
        allowFileAccess: Boolean = false,
        allowContentAccess: Boolean = false,
        mixedContentMode: MixedContentModeMessage = MixedContentModeMessage.NEVER_ALLOW,
        geolocationEnabled: Boolean = true,
        minimumFontSize: Long? = null,
    ) = WebViewSettingsMessage(
        javaScriptEnabled = javaScriptEnabled,
        mediaPlaybackRequiresUserGesture = true,
        allowsInlineMediaPlayback = false,
        supportZoom = supportZoom,
        builtInZoomControls = builtInZoomControls,
        displayZoomControls = displayZoomControls,
        transparentBackground = transparentBackground,
        passkeysEnabled = passkeysEnabled,
        allowsBackForwardNavigationGestures = false,
        inspectable = inspectable,
        textZoom = textZoom,
        cacheMode = cacheMode,
        incognito = incognito,
        javaScriptCanOpenWindowsAutomatically = javaScriptCanOpenWindowsAutomatically,
        scrollbarsVisible = scrollbarsVisible,
        overScrollEnabled = overScrollEnabled,
        pullToRefreshEnabled = pullToRefreshEnabled,
        domStorageEnabled = domStorageEnabled,
        allowFileAccess = allowFileAccess,
        allowContentAccess = allowContentAccess,
        mixedContentMode = mixedContentMode,
        contentMode = ContentModeMessage.RECOMMENDED,
        allowsLinkPreview = true,
        geolocationEnabled = geolocationEnabled,
        minimumFontSize = minimumFontSize,
        userAgent = userAgent,
    )
}

private const val INTERCEPT_CHANNEL =
    "dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onInterceptRequest"
