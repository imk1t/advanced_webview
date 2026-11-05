package dev.k1t.advanced_webview

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.webkit.ValueCallback
import android.webkit.WebChromeClient.FileChooserParams
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/**
 * Shows the system file picker for `<input type="file">`. It needs the host
 * Activity, which the plugin only has between `onAttachedToActivity` and
 * `onDetachedFromActivity`.
 */
class FileChooser : PluginRegistry.ActivityResultListener {
    private var binding: ActivityPluginBinding? = null
    private var pending: ValueCallback<Array<Uri>>? = null
    private var pendingHost: Activity? = null

    fun attach(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
    }

    fun detach() {
        binding?.removeActivityResultListener(this)
        binding = null
        cancelPending()
    }

    /**
     * Returns false, without touching [callback], when no picker can be shown. The picker starts from
     * [host] (for example the in-app browser Activity, so it is not hidden behind it) or, when `null`,
     * from the Flutter Activity. A [host] must forward its results to [onActivityResult].
     */
    fun show(callback: ValueCallback<Array<Uri>>, params: FileChooserParams, host: Activity? = null): Boolean {
        val activity = host ?: binding?.activity ?: return false
        // The WebView needs an answer for every request, so a new request cancels the old one.
        cancelPending()
        return try {
            activity.startActivityForResult(params.createIntent(), REQUEST_CODE)
            pending = callback
            pendingHost = host
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val callback = pending ?: return true
        pending = null
        pendingHost = null
        // A cancelled picker answers null, which the WebView treats as "no file chosen".
        val uris = if (resultCode == Activity.RESULT_OK) FileChooserParams.parseResult(resultCode, data) else null
        callback.onReceiveValue(uris)
        return true
    }

    /** Answers a request shown from [host] with "no file chosen" because [host] is going away. */
    fun release(host: Activity) {
        if (pendingHost === host) cancelPending()
    }

    private fun cancelPending() {
        pending?.onReceiveValue(null)
        pending = null
        pendingHost = null
    }

    private companion object {
        // Must fit in 16 bits for FragmentActivity.
        const val REQUEST_CODE = 0x5731
    }
}
