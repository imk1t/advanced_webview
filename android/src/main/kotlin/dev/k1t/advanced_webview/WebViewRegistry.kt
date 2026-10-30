package dev.k1t.advanced_webview

/** Maps Dart-allocated `webViewId`s to live native instances. Main thread only. */
class WebViewRegistry {
    private val instances = mutableMapOf<Long, AdvancedWebView>()

    fun add(instance: AdvancedWebView) {
        check(!instances.containsKey(instance.id)) { "webViewId ${instance.id} is already in use" }
        instances[instance.id] = instance
    }

    fun get(id: Long): AdvancedWebView =
        instances[id] ?: throw FlutterError("not-found", "No WebView with id $id", null)

    fun remove(id: Long): AdvancedWebView? = instances.remove(id)

    fun removeAll(): List<AdvancedWebView> = instances.values.toList().also { instances.clear() }
}
