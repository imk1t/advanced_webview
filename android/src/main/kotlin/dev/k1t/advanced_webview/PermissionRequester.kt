package dev.k1t.advanced_webview

import android.app.Activity
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/**
 * Asks the user for Android runtime permissions (camera, microphone, location)
 * after Dart allowed a page to use them. It needs the host Activity, which the
 * plugin only has between `onAttachedToActivity` and `onDetachedFromActivity`.
 */
class PermissionRequester : PluginRegistry.RequestPermissionsResultListener {
    private class Pending(val permissions: List<String>, val host: Activity, val onResult: (Set<String>) -> Unit)

    private var binding: ActivityPluginBinding? = null
    private var pending: Pending? = null

    fun attach(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    fun detach() {
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
        finishPending()
    }

    /**
     * Calls [onResult] exactly once with the subset of [permissions] the app holds afterwards.
     * Without an Activity nothing can be asked, so only permissions already granted count.
     *
     * The system dialog is shown over [host] (for example the in-app browser Activity, so it is not
     * hidden behind it) or, when `null`, over the Flutter Activity. A [host] must forward its results
     * to [onRequestPermissionsResult].
     */
    fun request(permissions: List<String>, host: Activity? = null, onResult: (Set<String>) -> Unit) {
        val activity = host ?: binding?.activity
        if (activity == null) {
            onResult(emptySet())
            return
        }
        val missing = permissions.filter { activity.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isEmpty()) {
            onResult(permissions.toSet())
            return
        }
        // Only one system dialog at a time: a new request settles the old one with what is held now.
        finishPending()
        pending = Pending(permissions, activity, onResult)
        activity.requestPermissions(missing.toTypedArray(), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        finishPending()
        return true
    }

    private fun finishPending() {
        val request = pending ?: return
        pending = null
        val activity = request.host
        request.onResult(
            request.permissions.filter {
                activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
            }.toSet(),
        )
    }

    /** Settles a request shown over [host] with what is held now because [host] is going away. */
    fun release(host: Activity) {
        if (pending?.host === host) finishPending()
    }

    private companion object {
        // Must fit in 16 bits for FragmentActivity.
        const val REQUEST_CODE = 0x5732
    }
}
