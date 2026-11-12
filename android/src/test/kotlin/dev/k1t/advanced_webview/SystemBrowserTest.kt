package dev.k1t.advanced_webview

import android.app.Activity
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Looper
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
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SystemBrowserTest {
    private lateinit var messenger: BinaryMessenger
    private lateinit var scope: CoroutineScope
    private lateinit var hostApi: WebViewHostApiImpl
    private val activityController = Robolectric.buildActivity(Activity::class.java).setup()
    private val host: Activity = activityController.get()

    @Before
    fun setUp() {
        messenger = mock(BinaryMessenger::class.java)
        scope = MainScope()
        hostApi = newHostApi { host }
    }

    @After
    fun tearDown() {
        hostApi.disposeAll()
        scope.cancel()
    }

    @Test
    fun isUnavailableWithoutABrowserThatHandlesHttps() {
        assertFalse(hostApi.isSystemBrowserAvailable())

        val error = assertFailsWith<FlutterError> { hostApi.openSystemBrowser(params()) }
        assertEquals("unavailable", error.code)
    }

    @Test
    fun opensTheUrlInACustomTab() {
        installBrowser()
        assertTrue(hostApi.isSystemBrowserAvailable())

        hostApi.openSystemBrowser(params(url = "https://example.com/login", toolbarColor = 0xFF112233))

        val started = shadowOf(host).nextStartedActivity
        assertEquals(Intent.ACTION_VIEW, started.action)
        assertEquals(Uri.parse("https://example.com/login"), started.data)
    }

    @Test
    fun failsWithoutAnActivity() {
        installBrowser()
        val detached = newHostApi { null }

        val error = assertFailsWith<FlutterError> { detached.openSystemBrowser(params()) }

        assertEquals("not-attached", error.code)
    }

    @Test
    fun reportsClosedWhenTheAppComesBackToTheForeground() {
        installBrowser()
        hostApi.openSystemBrowser(params(sessionId = 7))
        shadowOf(Looper.getMainLooper()).idle()
        verify(messenger, never()).send(eq(CLOSED_CHANNEL), any(), any())

        activityController.pause()
        activityController.resume()
        shadowOf(Looper.getMainLooper()).idle()

        verify(messenger).send(eq(CLOSED_CHANNEL), any(), any())
    }

    private fun installBrowser() {
        val probe = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
        val info = ResolveInfo().apply {
            activityInfo = ActivityInfo().apply {
                packageName = "com.example.browser"
                name = "com.example.browser.Main"
            }
        }
        shadowOf(RuntimeEnvironment.getApplication().packageManager).addResolveInfoForIntent(probe, info)
    }

    private fun newHostApi(activity: () -> Activity?) = WebViewHostApiImpl(
        RuntimeEnvironment.getApplication(),
        WebViewRegistry(),
        AdvancedWebViewFlutterApi(messenger),
        scope,
        activityProvider = activity,
    )

    private fun params(sessionId: Long = 1, url: String = "https://example.com/", toolbarColor: Long? = null) =
        SystemBrowserParamsMessage(sessionId = sessionId, url = url, toolbarColor = toolbarColor)

    private companion object {
        const val CLOSED_CHANNEL = "dev.flutter.pigeon.advanced_webview.AdvancedWebViewFlutterApi.onSystemBrowserClosed"
    }
}
