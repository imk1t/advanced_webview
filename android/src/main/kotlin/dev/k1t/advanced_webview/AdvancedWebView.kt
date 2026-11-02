package dev.k1t.advanced_webview

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.MutableContextWrapper
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.net.http.SslError
import android.os.Message
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.GeolocationPermissions
import android.webkit.HttpAuthHandler
import android.webkit.JavascriptInterface
import android.webkit.PermissionRequest
import android.webkit.SslErrorHandler
import android.webkit.URLUtil
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.ScriptHandler
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.Log
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import org.json.JSONException
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.coroutines.resume

/** One native WebView plus the clients that forward its callbacks to Dart. */
class AdvancedWebView(
    context: Context,
    params: CreationParamsMessage,
    private val flutterApi: AdvancedWebViewFlutterApi,
    private val scope: CoroutineScope,
    private val fileChooser: FileChooser,
    private val permissionRequester: PermissionRequester,
) : PlatformView {
    val id: Long = params.webViewId

    // Created before a platform view exists; the real (Activity) context is
    // swapped in by [attachToContext] so dialogs and IME work correctly.
    private val contextWrapper = MutableContextWrapper(context)
    val webView: WebView = WebView(contextWrapper)

    private val hasNavigationDelegate = params.hasNavigationDelegate
    private val hasNewWindowDelegate = params.hasNewWindowDelegate
    private val hasPermissionDelegate = params.hasPermissionDelegate
    private val hasSslErrorDelegate = params.hasSslErrorDelegate
    private val hasHttpAuthDelegate = params.hasHttpAuthDelegate
    private val scriptHandlers = mutableListOf<ScriptHandler>()
    private var isDestroyed = false

    init {
        webView.settings.domStorageEnabled = true
        // Without a delegate, window.open and target=_blank load in this WebView.
        webView.settings.setSupportMultipleWindows(hasNewWindowDelegate)
        applySettings(params.settings)
        webView.webViewClient = Client()
        webView.webChromeClient = ChromeClient()
        params.javaScriptChannelNames.forEach(::addJavaScriptChannel)
        params.userScripts.forEach(::addUserScript)
        if (params.hasDownloadDelegate) webView.setDownloadListener(::onDownload)
        if (params.javaScriptHandlerNames.isNotEmpty()) installHandlerBridge(params.javaScriptHandlerObjectName)
    }

    private fun onDownload(
        url: String,
        @Suppress("UNUSED_PARAMETER") userAgent: String?,
        contentDisposition: String?,
        mimeType: String?,
        contentLength: Long,
    ) {
        val request = DownloadRequestMessage(
            url = url,
            suggestedFilename = URLUtil.guessFileName(url, contentDisposition, mimeType),
            mimeType = mimeType?.takeIf { it.isNotEmpty() },
            contentLength = contentLength.takeIf { it > 0 },
        )
        send { flutterApi.onDownloadStart(id, request) }
    }

    fun attachToContext(context: Context) {
        contextWrapper.baseContext = context
        // A re-created platform view reuses this WebView; detach it from the
        // previous container so it can be added to the new one.
        (webView.parent as? ViewGroup)?.removeView(webView)
    }

    @SuppressLint("SetJavaScriptEnabled")
    fun applySettings(settings: WebViewSettingsMessage) {
        with(webView.settings) {
            javaScriptEnabled = settings.javaScriptEnabled
            mediaPlaybackRequiresUserGesture = settings.mediaPlaybackRequiresUserGesture
            setSupportZoom(settings.supportZoom)
            builtInZoomControls = settings.supportZoom
            displayZoomControls = false
            javaScriptCanOpenWindowsAutomatically = settings.javaScriptCanOpenWindowsAutomatically
            textZoom = settings.textZoom.toInt()
            cacheMode = when (settings.cacheMode) {
                CacheModeMessage.NORMAL -> WebSettings.LOAD_DEFAULT
                CacheModeMessage.PREFER_CACHE -> WebSettings.LOAD_CACHE_ELSE_NETWORK
                CacheModeMessage.CACHE_ONLY -> WebSettings.LOAD_CACHE_ONLY
                CacheModeMessage.NO_CACHE -> WebSettings.LOAD_NO_CACHE
            }
            minimumFontSize = settings.minimumFontSize?.toInt() ?: DEFAULT_MINIMUM_FONT_SIZE
            userAgentString = settings.userAgent ?: WebSettings.getDefaultUserAgent(webView.context)
        }
        if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_AUTHENTICATION)) {
            WebSettingsCompat.setWebAuthenticationSupport(
                webView.settings,
                if (settings.passkeysEnabled) {
                    WebSettingsCompat.WEB_AUTHENTICATION_SUPPORT_FOR_APP
                } else {
                    WebSettingsCompat.WEB_AUTHENTICATION_SUPPORT_NONE
                },
            )
        }
        webView.isVerticalScrollBarEnabled = settings.scrollbarsVisible
        webView.isHorizontalScrollBarEnabled = settings.scrollbarsVisible
        webView.overScrollMode =
            if (settings.overScrollEnabled) View.OVER_SCROLL_IF_CONTENT_SCROLLS else View.OVER_SCROLL_NEVER
        WebView.setWebContentsDebuggingEnabled(settings.inspectable)
        webView.setBackgroundColor(if (settings.transparentBackground) Color.TRANSPARENT else Color.WHITE)
    }

    suspend fun evaluateJavaScript(source: String): String? = suspendCancellableCoroutine { cont ->
        webView.evaluateJavascript(source) { result ->
            // Android already returns JSON; "null" covers both null and undefined.
            cont.resume(if (result == null || result == "null") null else result)
        }
    }

    fun addUserScript(script: UserScriptMessage) {
        check(WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            "User scripts need a WebView that supports DOCUMENT_START_SCRIPT"
        }
        scriptHandlers += WebViewCompat.addDocumentStartJavaScript(webView, script.wrapped(), setOf("*"))
    }

    fun removeAllUserScripts() {
        scriptHandlers.forEach { it.remove() }
        scriptHandlers.clear()
    }

    /**
     * Document-start scripts run in every frame, so a main-frame-only script
     * checks `window.top`, and an at-document-end script waits for the DOM.
     */
    private fun UserScriptMessage.wrapped(): String {
        val frameGuard = if (mainFrameOnly) "if (window.top !== window) return;" else ""
        val schedule = if (injectionTime == UserScriptInjectionTimeMessage.AT_DOCUMENT_END) {
            "if (document.readyState === 'loading') " +
                "document.addEventListener('DOMContentLoaded', run); else run();"
        } else {
            "run();"
        }
        return "(function() { $frameGuard function run() {\n$source\n} $schedule })();"
    }

    suspend fun setCookie(cookie: CookieMessage) {
        val scheme = if (cookie.isSecure) "https" else "http"
        val url = "$scheme://${cookie.domain.trimStart('.')}${cookie.path}"
        val stored = suspendCancellableCoroutine { cont ->
            CookieManager.getInstance().setCookie(url, cookie.toSetCookieHeader()) { cont.resume(it) }
        }
        check(stored) { "The cookie '${cookie.name}' was rejected for $url" }
        CookieManager.getInstance().flush()
    }

    /** Android only exposes `name=value` pairs, so the other attributes are defaults. */
    fun getCookies(url: String): List<CookieMessage> {
        val host = Uri.parse(url).host.orEmpty()
        val header = CookieManager.getInstance().getCookie(url) ?: return emptyList()
        return header.split(";").mapNotNull { pair ->
            val separator = pair.indexOf('=')
            if (separator <= 0) return@mapNotNull null
            CookieMessage(
                name = pair.substring(0, separator).trim(),
                value = pair.substring(separator + 1).trim(),
                domain = host,
                path = "/",
                isSecure = false,
                isHttpOnly = false,
            )
        }
    }

    suspend fun clearCookies() {
        suspendCancellableCoroutine<Boolean> { cont ->
            CookieManager.getInstance().removeAllCookies { cont.resume(it) }
        }
        CookieManager.getInstance().flush()
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

    /**
     * Exposes `window.<objectName>.callHandler(name, ...args)`. Requests travel over a
     * `WebMessageListener` (which replies to the frame that asked), and a document-start
     * shim turns them into promises. The shim is not tracked in [scriptHandlers], so
     * [removeAllUserScripts] leaves it alone.
     */
    private fun installHandlerBridge(objectName: String) {
        check(
            WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER) &&
                WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT),
        ) {
            "JavaScript handlers need a WebView that supports WEB_MESSAGE_LISTENER and DOCUMENT_START_SCRIPT"
        }
        WebViewCompat.addWebMessageListener(webView, BRIDGE_NAME, setOf("*")) { _, message, _, _, replyProxy ->
            handleHandlerCall(message.data, replyProxy)
        }
        WebViewCompat.addDocumentStartJavaScript(webView, handlerShim(objectName), setOf("*"))
    }

    private fun handleHandlerCall(data: String?, replyProxy: JavaScriptReplyProxy) {
        val request = try {
            JSONObject(data ?: return)
        } catch (e: JSONException) {
            return
        }
        val callId = request.optString("id")
        scope.launch {
            val response = JSONObject().put("id", callId)
            try {
                val value = flutterApi.onJavaScriptHandlerCall(
                    id,
                    request.getString("name"),
                    request.getString("args"),
                )
                response.put("ok", true).put("value", value)
            } catch (e: Throwable) {
                response.put("ok", false).put("error", e.message ?: e.toString())
            }
            if (isDestroyed) return@launch
            try {
                replyProxy.postMessage(response.toString())
            } catch (e: Throwable) {
                // The frame went away (navigation) before the answer was ready.
                Log.w(TAG, "Failed to reply to a JavaScript handler call: ${e.message}")
            }
        }
    }

    override fun getView(): View = webView

    override fun dispose() {
        // Lifetime is owned by Dart (AdvancedWebViewHostApi.dispose), not by the
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

        override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {
            if (!hasSslErrorDelegate) {
                handler.cancel()
                return
            }
            val url = error.url.orEmpty()
            val message = SslErrorMessage(url, Uri.parse(url).host.orEmpty(), error.describe())
            scope.launch {
                val decision = try {
                    flutterApi.onSslError(id, message)
                } catch (e: Throwable) {
                    Log.w(TAG, "SSL error delegate failed, refusing the load: ${e.message}")
                    SslErrorDecisionMessage.CANCEL
                }
                if (decision == SslErrorDecisionMessage.PROCEED && !isDestroyed) handler.proceed() else handler.cancel()
            }
        }

        override fun onReceivedHttpAuthRequest(view: WebView, handler: HttpAuthHandler, host: String, realm: String?) {
            if (!hasHttpAuthDelegate) {
                handler.cancel()
                return
            }
            val request = HttpAuthRequestMessage(host, realm?.takeIf { it.isNotEmpty() })
            scope.launch {
                val credentials = try {
                    flutterApi.onHttpAuthRequest(id, request)
                } catch (e: Throwable) {
                    Log.w(TAG, "HTTP auth delegate failed, cancelling: ${e.message}")
                    null
                }
                if (credentials != null && !isDestroyed) {
                    handler.proceed(credentials.username, credentials.password)
                } else {
                    handler.cancel()
                }
            }
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

    /** Asks Dart whether a page may use [resources]. Errors count as a denial. */
    private fun askDart(origin: String, resources: List<PermissionResourceMessage>, onDecision: (Boolean) -> Unit) {
        scope.launch {
            val allowed = try {
                flutterApi.onPermissionRequest(id, PermissionRequestMessage(origin, resources)) ==
                    PermissionDecisionMessage.GRANT
            } catch (e: Throwable) {
                Log.w(TAG, "Permission delegate failed, denying: ${e.message}")
                false
            }
            if (!isDestroyed) onDecision(allowed)
        }
    }

    private inner class ChromeClient : WebChromeClient() {
        override fun onProgressChanged(view: WebView, newProgress: Int) {
            send { flutterApi.onProgressChanged(id, newProgress.toLong()) }
        }

        override fun onReceivedTitle(view: WebView, title: String?) {
            send { flutterApi.onTitleChanged(id, title) }
        }

        override fun onShowFileChooser(
            webView: WebView,
            filePathCallback: ValueCallback<Array<Uri>>,
            fileChooserParams: FileChooserParams,
        ): Boolean = fileChooser.show(filePathCallback, fileChooserParams)

        override fun onPermissionRequest(request: PermissionRequest) {
            // Resources without a Dart equivalent (protected media, MIDI) are never granted.
            val mapped = request.resources.mapNotNull { resource ->
                when (resource) {
                    PermissionRequest.RESOURCE_VIDEO_CAPTURE ->
                        Triple(resource, PermissionResourceMessage.CAMERA, Manifest.permission.CAMERA)

                    PermissionRequest.RESOURCE_AUDIO_CAPTURE ->
                        Triple(resource, PermissionResourceMessage.MICROPHONE, Manifest.permission.RECORD_AUDIO)

                    else -> null
                }
            }
            if (!hasPermissionDelegate || mapped.isEmpty() || mapped.size != request.resources.size) {
                request.deny()
                return
            }
            askDart(request.origin.toString(), mapped.map { it.second }) { allowed ->
                if (!allowed) {
                    request.deny()
                    return@askDart
                }
                // The page may only use what the user also allowed the app to use.
                permissionRequester.request(mapped.map { it.third }) { held ->
                    val granted = mapped.filter { it.third in held }.map { it.first }
                    if (granted.size == mapped.size) request.grant(granted.toTypedArray()) else request.deny()
                }
            }
        }

        override fun onGeolocationPermissionsShowPrompt(origin: String, callback: GeolocationPermissions.Callback) {
            if (!hasPermissionDelegate) {
                callback.invoke(origin, false, false)
                return
            }
            askDart(origin, listOf(PermissionResourceMessage.GEOLOCATION)) { allowed ->
                if (!allowed) {
                    callback.invoke(origin, false, false)
                    return@askDart
                }
                permissionRequester.request(listOf(Manifest.permission.ACCESS_FINE_LOCATION)) { held ->
                    callback.invoke(origin, Manifest.permission.ACCESS_FINE_LOCATION in held, false)
                }
            }
        }

        override fun onCreateWindow(
            view: WebView,
            isDialog: Boolean,
            isUserGesture: Boolean,
            resultMsg: Message,
        ): Boolean {
            if (!hasNewWindowDelegate) return false
            // The URL is only known once the new window starts loading, so hand
            // the page a throwaway WebView, report the first URL it navigates
            // to, and destroy it.
            val popup = WebView(view.context)
            popup.webViewClient = object : WebViewClient() {
                private var reported = false

                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    report(view, request.url.toString())
                    return true
                }

                override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
                    report(view, url)
                }

                private fun report(view: WebView, url: String) {
                    if (reported || url == "about:blank") return
                    reported = true
                    send { flutterApi.onNewWindowRequest(id, url) }
                    view.stopLoading()
                    view.post { view.destroy() }
                }
            }
            (resultMsg.obj as WebView.WebViewTransport).webView = popup
            resultMsg.sendToTarget()
            return true
        }
    }

    private fun SslError.describe(): String = when (primaryError) {
        SslError.SSL_NOTYETVALID -> "The certificate is not valid yet"
        SslError.SSL_EXPIRED -> "The certificate has expired"
        SslError.SSL_IDMISMATCH -> "The certificate does not match the host name"
        SslError.SSL_UNTRUSTED -> "The certificate authority is not trusted"
        SslError.SSL_DATE_INVALID -> "The certificate date is invalid"
        else -> "The certificate is invalid"
    }

    private fun CookieMessage.toSetCookieHeader(): String = buildString {
        append("$name=$value; Domain=$domain; Path=$path")
        expiresMillis?.let {
            val format = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", Locale.US)
            format.timeZone = TimeZone.getTimeZone("GMT")
            append("; Expires=${format.format(Date(it))}")
        }
        if (isSecure) append("; Secure")
        if (isHttpOnly) append("; HttpOnly")
    }

    companion object {
        private const val TAG = "AdvancedWebView"

        // WebSettings.getMinimumFontSize() default.
        private const val DEFAULT_MINIMUM_FONT_SIZE = 8
        private const val BRIDGE_NAME = "advancedWebViewBridge"

        // Same contract as the iOS shim: callHandler(name, ...args) returns a promise.
        internal fun handlerShim(objectName: String) = """
            (function () {
              if (window.$objectName) return;
              var bridge = window.$BRIDGE_NAME;
              var pending = {};
              var counter = 0;
              var prefix = Math.random().toString(36).slice(2) + '-';
              bridge.onmessage = function (event) {
                var reply = JSON.parse(event.data);
                var call = pending[reply.id];
                if (!call) return;
                delete pending[reply.id];
                if (reply.ok) call.resolve(JSON.parse(reply.value));
                else call.reject(new Error(reply.error));
              };
              window.$objectName = Object.freeze({
                callHandler: function (name) {
                  var args = Array.prototype.slice.call(arguments, 1);
                  return new Promise(function (resolve, reject) {
                    var id = prefix + (++counter);
                    pending[id] = { resolve: resolve, reject: reject };
                    try {
                      bridge.postMessage(JSON.stringify({ id: id, name: String(name), args: JSON.stringify(args) }));
                    } catch (e) {
                      delete pending[id];
                      reject(e);
                    }
                  });
                }
              });
            })();
        """.trimIndent()
    }
}
