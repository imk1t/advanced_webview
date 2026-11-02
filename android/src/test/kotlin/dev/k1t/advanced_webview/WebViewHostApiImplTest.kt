package dev.k1t.advanced_webview

import android.graphics.Color
import android.net.Uri
import android.net.http.SslError
import android.os.Looper
import android.view.View
import android.webkit.GeolocationPermissions
import android.webkit.HttpAuthHandler
import android.webkit.PermissionRequest
import android.webkit.SslErrorHandler
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
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
    fun cacheModeIsAppliedAtCreationAndOnUpdate() {
        hostApi.create(params(webViewId = 1, settings = settings(cacheMode = CacheModeMessage.CACHE_ONLY)))
        val nativeSettings = registry.get(1).webView.settings
        assertEquals(WebSettings.LOAD_CACHE_ONLY, nativeSettings.cacheMode)

        hostApi.updateSettings(1, settings(cacheMode = CacheModeMessage.NO_CACHE))

        assertEquals(WebSettings.LOAD_NO_CACHE, nativeSettings.cacheMode)
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
        oldParent.addView(instance.webView)

        val view = AdvancedWebViewFactory(registry)
            .create(RuntimeEnvironment.getApplication(), 0, mapOf("webViewId" to 5))

        assertSame(instance, view)
        assertNull(instance.webView.parent)
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
        userScripts,
    )

    private fun settings(
        javaScriptEnabled: Boolean = true,
        supportZoom: Boolean = true,
        transparentBackground: Boolean = false,
        userAgent: String? = null,
        passkeysEnabled: Boolean = false,
        inspectable: Boolean = false,
        textZoom: Long = 100,
        cacheMode: CacheModeMessage = CacheModeMessage.NORMAL,
        javaScriptCanOpenWindowsAutomatically: Boolean = true,
        scrollbarsVisible: Boolean = true,
        overScrollEnabled: Boolean = true,
        minimumFontSize: Long? = null,
    ) = WebViewSettingsMessage(
        javaScriptEnabled = javaScriptEnabled,
        mediaPlaybackRequiresUserGesture = true,
        allowsInlineMediaPlayback = false,
        supportZoom = supportZoom,
        transparentBackground = transparentBackground,
        passkeysEnabled = passkeysEnabled,
        allowsBackForwardNavigationGestures = false,
        inspectable = inspectable,
        textZoom = textZoom,
        cacheMode = cacheMode,
        javaScriptCanOpenWindowsAutomatically = javaScriptCanOpenWindowsAutomatically,
        scrollbarsVisible = scrollbarsVisible,
        overScrollEnabled = overScrollEnabled,
        minimumFontSize = minimumFontSize,
        userAgent = userAgent,
    )
}
