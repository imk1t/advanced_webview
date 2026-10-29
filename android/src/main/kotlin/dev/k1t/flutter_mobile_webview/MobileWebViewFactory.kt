package dev.k1t.flutter_mobile_webview

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * The native WebView is created ahead of time by `MobileWebViewHostApi.create`;
 * the factory only looks it up by `webViewId` and attaches it.
 */
class MobileWebViewFactory(private val registry: WebViewRegistry) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as Map<*, *>
        val webViewId = (params["webViewId"] as Number).toLong()
        return registry.get(webViewId).also { it.attachToContext(context) }
    }
}
