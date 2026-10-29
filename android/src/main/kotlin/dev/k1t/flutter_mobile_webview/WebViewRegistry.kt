package dev.k1t.flutter_mobile_webview

/** Maps Dart-allocated `webViewId`s to live native instances. Main thread only. */
class WebViewRegistry {
    private val instances = mutableMapOf<Long, MobileWebView>()

    fun add(instance: MobileWebView) {
        check(!instances.containsKey(instance.id)) { "webViewId ${instance.id} is already in use" }
        instances[instance.id] = instance
    }

    fun get(id: Long): MobileWebView =
        instances[id] ?: throw FlutterError("not-found", "No WebView with id $id", null)

    fun remove(id: Long): MobileWebView? = instances.remove(id)

    fun removeAll(): List<MobileWebView> = instances.values.toList().also { instances.clear() }
}
