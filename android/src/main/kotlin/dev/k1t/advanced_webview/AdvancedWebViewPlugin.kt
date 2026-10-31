package dev.k1t.advanced_webview

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel

/**
 * Entry point. Wires the Pigeon host API and the platform view factory to the
 * engine. All per-WebView state lives in [WebViewRegistry].
 */
class AdvancedWebViewPlugin :
    FlutterPlugin,
    ActivityAware {
    private val fileChooser = FileChooser()
    private var hostApi: WebViewHostApiImpl? = null
    private var scope: CoroutineScope? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val scope = MainScope().also { scope = it }
        val registry = WebViewRegistry()
        val flutterApi = AdvancedWebViewFlutterApi(binding.binaryMessenger)
        val hostApi = WebViewHostApiImpl(binding.applicationContext, registry, flutterApi, scope, fileChooser)
            .also { hostApi = it }

        AdvancedWebViewHostApi.setUp(binding.binaryMessenger, hostApi)
        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            AdvancedWebViewFactory(registry),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        AdvancedWebViewHostApi.setUp(binding.binaryMessenger, null)
        hostApi?.disposeAll()
        hostApi = null
        scope?.cancel()
        scope = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = fileChooser.attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = fileChooser.detach()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = fileChooser.attach(binding)

    override fun onDetachedFromActivity() = fileChooser.detach()

    companion object {
        /** Must match `AdvancedWebView.viewType` on the Dart side. */
        const val VIEW_TYPE = "dev.k1t.advanced_webview/webview"
    }
}
