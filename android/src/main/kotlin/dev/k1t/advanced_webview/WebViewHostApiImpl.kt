package dev.k1t.advanced_webview

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.io.File

/** Implements the Dart -> native calls by dispatching to [WebViewRegistry]. */
class WebViewHostApiImpl(
    private val context: Context,
    private val registry: WebViewRegistry,
    private val flutterApi: AdvancedWebViewFlutterApi,
    private val scope: CoroutineScope,
    private val fileChooser: FileChooser = FileChooser(),
    private val permissionRequester: PermissionRequester = PermissionRequester(),
    private val activityProvider: () -> Activity? = { null },
    /** Maps a Flutter asset key to its path in the APK assets (`flutter_assets/<key>` unless overridden). */
    private val flutterAssetPath: (String) -> String = { "flutter_assets/$it" },
) : AdvancedWebViewHostApi {
    override fun create(params: CreationParamsMessage) {
        registry.add(AdvancedWebView(context, params, flutterApi, scope, fileChooser, permissionRequester))
    }

    override fun dispose(webViewId: Long) {
        registry.remove(webViewId)?.destroy()
    }

    fun disposeAll() {
        registry.removeAll().forEach { it.destroy() }
    }

    override fun loadUrl(webViewId: Long, url: String, headers: Map<String, String>) =
        registry.get(webViewId).webView.loadUrl(url, headers)

    override fun loadHtmlString(webViewId: Long, html: String, baseUrl: String?) =
        registry.get(webViewId).webView.loadDataWithBaseURL(baseUrl, html, "text/html", "UTF-8", null)

    override fun loadRequest(
        webViewId: Long,
        url: String,
        method: HttpMethodMessage,
        headers: Map<String, String>,
        body: ByteArray?,
    ) {
        val webView = registry.get(webViewId).webView
        when (method) {
            HttpMethodMessage.GET -> webView.loadUrl(url, headers)

            HttpMethodMessage.POST -> {
                // WebView.postUrl cannot carry custom headers.
                if (headers.isNotEmpty()) {
                    throw FlutterError("unsupported", "Android cannot send custom headers with a POST request", null)
                }
                webView.postUrl(url, body ?: ByteArray(0))
            }
        }
    }

    override fun loadFlutterAsset(webViewId: Long, key: String) =
        registry.get(webViewId).webView.loadUrl(AdvancedWebView.ASSET_BASE_URL + flutterAssetPath(key))

    override fun loadFile(webViewId: Long, path: String) {
        val webView = registry.get(webViewId).webView
        if (!webView.settings.allowFileAccess) {
            throw FlutterError("file-access-disabled", "Set AndroidWebViewSettings.allowFileAccess to load files", null)
        }
        webView.loadUrl(Uri.fromFile(File(path)).toString())
    }

    override fun reload(webViewId: Long) = registry.get(webViewId).webView.reload()

    override fun stopLoading(webViewId: Long) = registry.get(webViewId).webView.stopLoading()

    override fun goBack(webViewId: Long) = registry.get(webViewId).webView.goBack()

    override fun goForward(webViewId: Long) = registry.get(webViewId).webView.goForward()

    override fun canGoBack(webViewId: Long): Boolean = registry.get(webViewId).webView.canGoBack()

    override fun canGoForward(webViewId: Long): Boolean = registry.get(webViewId).webView.canGoForward()

    override fun getUrl(webViewId: Long): String? = registry.get(webViewId).webView.url

    override fun getTitle(webViewId: Long): String? = registry.get(webViewId).webView.title

    override suspend fun evaluateJavaScript(webViewId: Long, source: String): String? =
        registry.get(webViewId).evaluateJavaScript(source)

    override suspend fun takeScreenshot(webViewId: Long): ByteArray? = registry.get(webViewId).takeScreenshot()

    override suspend fun createPdf(webViewId: Long): ByteArray = registry.get(webViewId).createPdf()

    override suspend fun findText(webViewId: Long, query: String, forward: Boolean): FindResultMessage =
        registry.get(webViewId).find(query, forward)

    override fun clearMatches(webViewId: Long) = registry.get(webViewId).clearMatches()

    override fun scrollTo(webViewId: Long, x: Double, y: Double) = registry.get(webViewId).scrollTo(x, y)

    override fun scrollBy(webViewId: Long, dx: Double, dy: Double) = registry.get(webViewId).scrollBy(dx, dy)

    override fun zoomBy(webViewId: Long, factor: Double) = registry.get(webViewId).zoomBy(factor)

    override fun setZoomScale(webViewId: Long, scale: Double) = registry.get(webViewId).setZoomScale(scale)

    override fun getZoomScale(webViewId: Long): Double = registry.get(webViewId).zoomScale()

    override fun getScrollPosition(webViewId: Long): ScrollPositionMessage = registry.get(webViewId).scrollPosition()

    override fun saveState(webViewId: Long): ByteArray? = registry.get(webViewId).saveState()

    override fun restoreState(webViewId: Long, state: ByteArray): Boolean = registry.get(webViewId).restoreState(state)

    override fun printPage(webViewId: Long, jobName: String?) = registry.get(webViewId).printPage(jobName)

    override fun updateSettings(webViewId: Long, settings: WebViewSettingsMessage) =
        registry.get(webViewId).applySettings(settings)

    override suspend fun setCookie(webViewId: Long, cookie: CookieMessage) = registry.get(webViewId).setCookie(cookie)

    override suspend fun getCookies(webViewId: Long, url: String): List<CookieMessage> =
        registry.get(webViewId).getCookies(url)

    override suspend fun clearCookies(webViewId: Long) = registry.get(webViewId).clearCookies()

    override suspend fun clearWebsiteData(webViewId: Long, types: List<WebsiteDataTypeMessage>) =
        registry.get(webViewId).clearWebsiteData(types)

    override fun addUserScript(webViewId: Long, script: UserScriptMessage) =
        registry.get(webViewId).addUserScript(script)

    override fun removeAllUserScripts(webViewId: Long) = registry.get(webViewId).removeAllUserScripts()

    override fun openInAppBrowser(params: InAppBrowserParamsMessage) {
        val webView = registry.get(params.webViewId)
        val activity = activityProvider() ?: throw FlutterError("not-attached", "No Activity to present from", null)
        if (InAppBrowserSessions.get(params.webViewId) != null) {
            throw FlutterError("already-open", "The in-app browser of ${params.webViewId} is already open", null)
        }
        InAppBrowserSessions.add(
            InAppBrowserSession(webView, params) {
                scope.launch {
                    try {
                        flutterApi.onInAppBrowserClosed(params.webViewId)
                    } catch (e: Throwable) {
                        Log.w(TAG, "Failed to deliver event to Dart: ${e.message}")
                    }
                }
            },
        )
        try {
            activity.startActivity(
                Intent(activity, InAppBrowserActivity::class.java)
                    .putExtra(InAppBrowserActivity.EXTRA_WEB_VIEW_ID, params.webViewId),
            )
        } catch (e: RuntimeException) {
            InAppBrowserSessions.remove(params.webViewId)
            throw e
        }
    }

    override fun closeInAppBrowser(webViewId: Long) {
        val session = InAppBrowserSessions.get(webViewId) ?: return
        val activity = session.activity
        if (activity != null) {
            activity.finish()
        } else {
            // The Activity has not been created yet; it will find no session and finish itself.
            InAppBrowserSessions.remove(webViewId)
            session.onClosed()
        }
    }

    private companion object {
        const val TAG = "AdvancedWebView"
    }
}
