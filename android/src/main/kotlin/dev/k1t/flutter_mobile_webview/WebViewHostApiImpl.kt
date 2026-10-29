package dev.k1t.flutter_mobile_webview

import android.content.Context
import kotlinx.coroutines.CoroutineScope

/** Implements the Dart -> native calls by dispatching to [WebViewRegistry]. */
class WebViewHostApiImpl(
    private val context: Context,
    private val registry: WebViewRegistry,
    private val flutterApi: MobileWebViewFlutterApi,
    private val scope: CoroutineScope,
) : MobileWebViewHostApi {
    override fun create(params: CreationParamsMessage) {
        registry.add(MobileWebView(context, params, flutterApi, scope))
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
}
