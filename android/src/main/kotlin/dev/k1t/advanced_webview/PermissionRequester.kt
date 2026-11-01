package dev.k1t.advanced_webview

import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/**
 * Asks the user for Android runtime permissions (camera, microphone, location)
 * after Dart allowed a page to use them. It needs the host Activity, which the
 * plugin only has between `onAttachedToActivity` and `onDetachedFromActivity`.
 */
class PermissionRequester : PluginRegistry.RequestPermissionsResultListener {
    private class Pending(val permissions: List<String>, val onResult: (Set<String>) -> Unit)

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
     */
    fun request(permissions: List<String>, onResult: (Set<String>) -> Unit) {
        val activity = binding?.activity
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
        pending = Pending(permissions, onResult)
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
        val activity = binding?.activity
        val held = if (activity == null) {
            emptySet()
        } else {
            request.permissions.filter { activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }.toSet()
        }
        request.onResult(held)
    }

    private companion object {
        // Must fit in 16 bits for FragmentActivity.
        const val REQUEST_CODE = 0x5732
    }
}
