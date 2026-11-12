package dev.k1t.advanced_webview

import android.app.Activity
import android.app.Application
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent

/**
 * Opens pages in Chrome Custom Tabs (the default browser's own tab UI, or a plain browser when none supports them).
 *
 * Custom Tabs report nothing when they close, so [onClosed] fires when the Activity that launched the tab resumes
 * again after pausing: best effort, as documented in Dart.
 */
internal class SystemBrowser(
    private val context: Context,
    private val activityProvider: () -> Activity?,
    private val onClosed: (Long) -> Unit,
) {
    fun isAvailable(): Boolean = Intent(Intent.ACTION_VIEW, Uri.parse(PROBE_URL))
        .resolveActivity(context.packageManager) != null

    fun open(params: SystemBrowserParamsMessage) {
        val activity = activityProvider() ?: throw FlutterError("not-attached", "No Activity to present from", null)
        if (!isAvailable()) throw FlutterError("unavailable", "No browser can open ${params.url}", null)
        val builder = CustomTabsIntent.Builder()
        params.toolbarColor?.let {
            builder.setDefaultColorSchemeParams(
                CustomTabColorSchemeParams.Builder().setToolbarColor(it.toInt()).build(),
            )
        }
        val callbacks = ReturnWatcher(activity, params.sessionId)
        activity.application.registerActivityLifecycleCallbacks(callbacks)
        try {
            builder.build().launchUrl(activity, Uri.parse(params.url))
        } catch (e: ActivityNotFoundException) {
            activity.application.unregisterActivityLifecycleCallbacks(callbacks)
            throw FlutterError("unavailable", "No browser can open ${params.url}", null)
        } catch (e: RuntimeException) {
            activity.application.unregisterActivityLifecycleCallbacks(callbacks)
            throw e
        }
    }

    /** Reports the session closed when [host] comes back to the foreground after the tab covered it. */
    private inner class ReturnWatcher(private val host: Activity, private val sessionId: Long) :
        Application.ActivityLifecycleCallbacks {
        private var covered = false

        override fun onActivityPaused(activity: Activity) {
            if (activity === host) covered = true
        }

        override fun onActivityResumed(activity: Activity) {
            if (activity === host && covered) finish()
        }

        override fun onActivityDestroyed(activity: Activity) {
            if (activity === host) finish()
        }

        private fun finish() {
            host.application.unregisterActivityLifecycleCallbacks(this)
            onClosed(sessionId)
        }

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit

        override fun onActivityStarted(activity: Activity) = Unit

        override fun onActivityStopped(activity: Activity) = Unit

        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
    }

    private companion object {
        const val PROBE_URL = "https://example.com"
    }
}
