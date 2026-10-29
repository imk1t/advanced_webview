package dev.k1t.flutter_mobile_webview

import android.annotation.SuppressLint
import android.content.Context
import android.content.MutableContextWrapper
import android.graphics.Bitmap
import android.graphics.Color
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.Log
import io.flutter.plugin.platform.PlatformView
import kotlin.coroutines.resume
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine

/** One native WebView plus the clients that forward its callbacks to Dart. */
class MobileWebView(
    context: Context,
    params: CreationParamsMessage,
    private val flutterApi: MobileWebViewFlutterApi,
    private val scope: CoroutineScope,
) : PlatformView {
    val id: Long = params.webViewId

    // Created before a platform view exists; the real (Activity) context is
    // swapped in by [attachToContext] so dialogs and IME work correctly.
    private val contextWrapper = MutableContextWrapper(context)
    val webView: WebView = WebView(contextWrapper)

    private val hasNavigationDelegate = params.hasNavigationDelegate
    private var isDestroyed = false

    init {
        webView.settings.domStorageEnabled = true
        applySettings(params.settings)
        webView.webViewClient = Client()
        webView.webChromeClient = ChromeClient()
        params.javaScriptChannelNames.forEach(::addJavaScriptChannel)
    }

    fun attachToContext(context: Context) {
        contextWrapper.baseContext = context
    }

    @SuppressLint("SetJavaScriptEnabled")
    fun applySettings(settings: WebViewSettingsMessage) {
        with(webView.settings) {
            javaScriptEnabled = settings.javaScriptEnabled
            mediaPlaybackRequiresUserGesture = settings.mediaPlaybackRequiresUserGesture
            setSupportZoom(settings.supportZoom)
            builtInZoomControls = settings.supportZoom
            displayZoomControls = false
            userAgentString = settings.userAgent ?: WebSettings.getDefaultUserAgent(webView.context)
        }
        webView.setBackgroundColor(if (settings.transparentBackground) Color.TRANSPARENT else Color.WHITE)
    }

    suspend fun evaluateJavaScript(source: String): String? = suspendCancellableCoroutine { cont ->
        webView.evaluateJavascript(source) { result ->
            // Android already returns JSON; "null" covers both null and undefined.
            cont.resume(if (result == null || result == "null") null else result)
        }
    }

    @SuppressLint("JavascriptInterface", "AddJavascriptInterface")
    private fun addJavaScriptChannel(name: String) {
        webView.addJavascriptInterface(
            object {
                @JavascriptInterface
                fun postMessage(message: String) {
                    // Called on a JavaBridge thread; scope dispatches to main.
                    send { flutterApi.onJavaScriptMessage(id, name, message) }
                }
            },
            name,
        )
    }

    override fun getView(): View = webView

    override fun dispose() {
        // Lifetime is owned by Dart (MobileWebViewHostApi.dispose), not by the
        // platform view, so the WebView survives re-attachment.
    }

    fun destroy() {
        if (isDestroyed) return
        isDestroyed = true
        webView.stopLoading()
        webView.destroy()
    }

    /** Fire-and-forget call into Dart. Failures are logged, never thrown. */
    private fun send(block: suspend () -> Unit) {
        scope.launch {
            if (isDestroyed) return@launch
            try {
                block()
            } catch (e: Throwable) {
                Log.w(TAG, "Failed to deliver event to Dart: ${e.message}")
            }
        }
    }

    private inner class Client : WebViewClient() {
        override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
            send { flutterApi.onPageStarted(id, url) }
        }

        override fun onPageFinished(view: WebView, url: String) {
            send { flutterApi.onPageFinished(id, url) }
        }

        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
            val message = WebResourceErrorMessage(
                errorCode = error.errorCode.toLong(),
                message = error.description.toString(),
                isMainFrame = request.isForMainFrame,
                url = request.url.toString(),
            )
            send { flutterApi.onReceivedError(id, message) }
        }

        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
            // Android needs a synchronous answer. For main-frame navigations we
            // cancel, ask Dart, and re-issue the load if allowed. Sub-frame
            // navigations cannot be re-issued, so they are always allowed.
            if (!hasNavigationDelegate || !request.isForMainFrame) return false
            val url = request.url.toString()
            scope.launch {
                val decision = try {
                    flutterApi.shouldOverrideUrlLoading(id, NavigationRequestMessage(url, true))
                } catch (e: Throwable) {
                    Log.w(TAG, "Navigation delegate failed, allowing navigation: ${e.message}")
                    NavigationDecisionMessage.NAVIGATE
                }
                if (decision == NavigationDecisionMessage.NAVIGATE && !isDestroyed) {
                    webView.loadUrl(url)
                }
            }
            return true
        }
    }

    private inner class ChromeClient : WebChromeClient() {
        override fun onProgressChanged(view: WebView, newProgress: Int) {
            send { flutterApi.onProgressChanged(id, newProgress.toLong()) }
        }

        override fun onReceivedTitle(view: WebView, title: String?) {
            send { flutterApi.onTitleChanged(id, title) }
        }
    }

    private companion object {
        const val TAG = "MobileWebView"
    }
}
