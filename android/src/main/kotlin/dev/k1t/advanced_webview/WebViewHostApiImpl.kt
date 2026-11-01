package dev.k1t.advanced_webview

import android.content.Context
import kotlinx.coroutines.CoroutineScope

/** Implements the Dart -> native calls by dispatching to [WebViewRegistry]. */
class WebViewHostApiImpl(
    private val context: Context,
    private val registry: WebViewRegistry,
    private val flutterApi: AdvancedWebViewFlutterApi,
    private val scope: CoroutineScope,
    private val fileChooser: FileChooser = FileChooser(),
    private val permissionRequester: PermissionRequester = PermissionRequester(),
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

    override fun updateSettings(webViewId: Long, settings: WebViewSettingsMessage) =
        registry.get(webViewId).applySettings(settings)

    override suspend fun setCookie(webViewId: Long, cookie: CookieMessage) = registry.get(webViewId).setCookie(cookie)

    override suspend fun getCookies(webViewId: Long, url: String): List<CookieMessage> =
        registry.get(webViewId).getCookies(url)

    override suspend fun clearCookies(webViewId: Long) = registry.get(webViewId).clearCookies()

    override fun addUserScript(webViewId: Long, script: UserScriptMessage) =
        registry.get(webViewId).addUserScript(script)

    override fun removeAllUserScripts(webViewId: Long) = registry.get(webViewId).removeAllUserScripts()
}
