package dev.k1t.flutter_mobile_webview

import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel

/**
 * Entry point. Wires the Pigeon host API and the platform view factory to the
 * engine. All per-WebView state lives in [WebViewRegistry].
 */
class MobileWebViewPlugin : FlutterPlugin {
    private var hostApi: WebViewHostApiImpl? = null
    private var scope: CoroutineScope? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val scope = MainScope().also { scope = it }
        val registry = WebViewRegistry()
        val flutterApi = MobileWebViewFlutterApi(binding.binaryMessenger)
        val hostApi = WebViewHostApiImpl(binding.applicationContext, registry, flutterApi, scope)
            .also { hostApi = it }

        MobileWebViewHostApi.setUp(binding.binaryMessenger, hostApi)
        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            MobileWebViewFactory(registry),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MobileWebViewHostApi.setUp(binding.binaryMessenger, null)
        hostApi?.disposeAll()
        hostApi = null
        scope?.cancel()
        scope = null
    }

    companion object {
        /** Must match `MobileWebView.viewType` on the Dart side. */
        const val VIEW_TYPE = "dev.k1t.flutter_mobile_webview/webview"
    }
}
