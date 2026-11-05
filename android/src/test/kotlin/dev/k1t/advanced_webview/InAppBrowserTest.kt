package dev.k1t.advanced_webview

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Looper
import android.view.ViewGroup
import android.widget.Toolbar
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
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ActivityController
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
class InAppBrowserTest {
    private lateinit var messenger: BinaryMessenger
    private lateinit var scope: CoroutineScope
    private lateinit var registry: WebViewRegistry
    private lateinit var hostApi: WebViewHostApiImpl
    private var host: Activity? = null

    @Before
    fun setUp() {
        messenger = mock(BinaryMessenger::class.java)
        scope = MainScope()
        registry = WebViewRegistry()
        host = Robolectric.buildActivity(Activity::class.java).setup().get()
        hostApi = newHostApi { host }
        hostApi.create(webViewParams(webViewId = 1))
    }

    @After
    fun tearDown() {
        InAppBrowserSessions.remove(1)
        hostApi.disposeAll()
        scope.cancel()
    }

    @Test
    fun openFailsWithoutAnActivity() {
        val detached = newHostApi { null }

        val error = assertFailsWith<FlutterError> { detached.openInAppBrowser(browserParams()) }

        assertEquals("not-attached", error.code)
        assertNull(InAppBrowserSessions.get(1))
    }

    @Test
    fun openFailsForAnUnknownWebView() {
        val error = assertFailsWith<FlutterError> { hostApi.openInAppBrowser(browserParams(webViewId = 99)) }

        assertEquals("not-found", error.code)
    }

    @Test
    fun openStartsTheActivityOnce() {
        hostApi.openInAppBrowser(browserParams())

        val started = shadowOf(host).nextStartedActivity
        assertEquals(InAppBrowserActivity::class.java.name, started.component?.className)
        assertEquals(1L, started.getLongExtra(InAppBrowserActivity.EXTRA_WEB_VIEW_ID, -1))
        val error = assertFailsWith<FlutterError> { hostApi.openInAppBrowser(browserParams()) }
        assertEquals("already-open", error.code)
    }

    @Test
    fun theActivityShowsTheWebViewBelowTheToolbar() {
        val controller = startActivity()
        val web = registry.get(1)

        val toolbar = controller.get().findToolbar()
        assertNotNull(toolbar)
        assertNotNull(web.container.parent)
        assertSame(controller.get(), web.webView.context.let { (it as android.content.ContextWrapper).baseContext })
        assertEquals(controller.get(), InAppBrowserSessions.get(1)?.activity)
    }

    @Test
    fun finishingReportsClosedOnceAndReleasesTheWebView() {
        val controller = startActivity()
        val web = registry.get(1)

        controller.get().finish()
        controller.pause().stop().destroy()
        shadowOf(Looper.getMainLooper()).idle()

        assertNull(web.container.parent)
        assertNull(InAppBrowserSessions.get(1))
        verify(messenger, times(1)).send(eq(CLOSED_CHANNEL), any(), any())
        // The WebView belongs to Dart and is still registered.
        assertSame(web, registry.get(1))
    }

    @Test
    fun closeFinishesTheActivity() {
        val controller = startActivity()

        hostApi.closeInAppBrowser(1)

        assertTrue(controller.get().isFinishing)
    }

    @Test
    fun closeBeforeTheActivityExistsReportsClosedAtOnce() {
        hostApi.openInAppBrowser(browserParams())

        hostApi.closeInAppBrowser(1)
        shadowOf(Looper.getMainLooper()).idle()

        assertNull(InAppBrowserSessions.get(1))
        verify(messenger, times(1)).send(eq(CLOSED_CHANNEL), any(), any())
    }

    @Test
    fun closeIsANoOpWhenNotOpen() {
        hostApi.closeInAppBrowser(1)

        verify(messenger, times(0)).send(eq(CLOSED_CHANNEL), any(), any())
    }

    @Test
    fun theToolbarShowsTheFixedTitleAndUrl() {
        val controller = startActivity(browserParams(toolbarTitle = "Docs", showUrl = true, toolbarColor = 0xFF102030))
        registry.get(1).onPageStateChanged?.invoke()

        val toolbar = controller.get().findToolbar()
        assertEquals("Docs", toolbar.title)
        assertTrue(toolbar.background is ColorDrawable)
        assertEquals(0xFF102030.toInt(), (toolbar.background as ColorDrawable).color)
    }

    @Test
    fun navigationButtonsAreOptional() {
        val shown = startActivity().get().findToolbar()
        assertEquals(3, shown.menu.size())
        InAppBrowserSessions.remove(1)

        val hidden = startActivity(browserParams(showNavigationButtons = false)).get().findToolbar()
        assertEquals(0, hidden.menu.size())
    }

    @Test
    fun aCloseButtonLabelReplacesTheCloseIcon() {
        val toolbar = startActivity(browserParams(closeButtonLabel = "Done")).get().findToolbar()

        assertEquals("Done", toolbar.menu.getItem(0).title.toString())
        assertNull(toolbar.navigationIcon)
    }

    @Test
    fun backGoesBackInThePageThenCloses() {
        val controller = startActivity()
        val activity = controller.get()

        @Suppress("DEPRECATION")
        activity.onBackPressed()

        assertTrue(activity.isFinishing)
    }

    private fun startActivity(
        params: InAppBrowserParamsMessage = browserParams(),
    ): ActivityController<InAppBrowserActivity> {
        hostApi.openInAppBrowser(params)
        val intent = Intent(RuntimeEnvironment.getApplication(), InAppBrowserActivity::class.java)
            .putExtra(InAppBrowserActivity.EXTRA_WEB_VIEW_ID, 1L)
        return Robolectric.buildActivity(InAppBrowserActivity::class.java, intent).setup()
    }

    private fun Activity.findToolbar(): Toolbar {
        val root = findViewById<ViewGroup>(android.R.id.content).getChildAt(0) as ViewGroup
        return root.getChildAt(0) as Toolbar
    }

    private fun newHostApi(activity: () -> Activity?) = WebViewHostApiImpl(
        RuntimeEnvironment.getApplication(),
        registry,
        AdvancedWebViewFlutterApi(messenger),
        scope,
        activityProvider = activity,
    )

    private fun browserParams(
        webViewId: Long = 1,
        toolbarTitle: String? = null,
        showUrl: Boolean = false,
        showNavigationButtons: Boolean = true,
        toolbarColor: Long? = null,
        closeButtonLabel: String? = null,
    ) = InAppBrowserParamsMessage(
        webViewId = webViewId,
        showUrl = showUrl,
        showNavigationButtons = showNavigationButtons,
        toolbarColor = toolbarColor,
        toolbarTitle = toolbarTitle,
        closeButtonLabel = closeButtonLabel,
    )

    private fun webViewParams(webViewId: Long) = CreationParamsMessage(
        webViewId = webViewId,
        settings = WebViewSettingsMessage(
            javaScriptEnabled = true,
            mediaPlaybackRequiresUserGesture = true,
            allowsInlineMediaPlayback = false,
            supportZoom = true,
            transparentBackground = false,
            passkeysEnabled = false,
            allowsBackForwardNavigationGestures = false,
            inspectable = false,
            textZoom = 100,
            cacheMode = CacheModeMessage.NORMAL,
            incognito = false,
            javaScriptCanOpenWindowsAutomatically = true,
            scrollbarsVisible = true,
            overScrollEnabled = true,
            pullToRefreshEnabled = false,
            domStorageEnabled = true,
            allowFileAccess = false,
            allowContentAccess = false,
            mixedContentMode = MixedContentModeMessage.NEVER_ALLOW,
            contentMode = ContentModeMessage.RECOMMENDED,
            allowsLinkPreview = true,
            geolocationEnabled = true,
        ),
        javaScriptChannelNames = emptyList(),
        javaScriptHandlerNames = emptyList(),
        javaScriptHandlerObjectName = "advanced_webview",
        hasNavigationDelegate = false,
        hasNewWindowDelegate = false,
        hasPermissionDelegate = false,
        hasDownloadDelegate = false,
        hasSslErrorDelegate = false,
        hasHttpAuthDelegate = false,
        hasScrollDelegate = false,
        hasLongPressDelegate = false,
        hasConsoleMessageDelegate = false,
        hasJsDialogDelegate = false,
        hasHttpErrorDelegate = false,
        userScripts = emptyList(),
    )

    private companion object {
        const val CLOSED_CHANNEL = "dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onInAppBrowserClosed"
    }
}
