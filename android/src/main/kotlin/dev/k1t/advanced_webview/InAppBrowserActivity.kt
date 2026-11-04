package dev.k1t.advanced_webview

import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.Toolbar
import android.window.OnBackInvokedDispatcher

/** A browser that is on screen: the WebView it shows and how to report that it is gone. */
class InAppBrowserSession(
    val webView: AdvancedWebView,
    val params: InAppBrowserParamsMessage,
    val onClosed: () -> Unit,
) {
    /** The Activity showing this session; `null` until it is created and after it is destroyed. */
    var activity: InAppBrowserActivity? = null
}

/**
 * Sessions by `webViewId`, shared between the plugin and [InAppBrowserActivity], which the system
 * creates and can only be given an id. Main thread only.
 */
object InAppBrowserSessions {
    private val sessions = mutableMapOf<Long, InAppBrowserSession>()

    fun add(session: InAppBrowserSession) {
        sessions[session.webView.id] = session
    }

    fun get(id: Long): InAppBrowserSession? = sessions[id]

    fun remove(id: Long): InAppBrowserSession? = sessions.remove(id)
}

/**
 * Full-screen in-app browser: a toolbar above the WebView of an [AdvancedWebView] that Dart created.
 * The WebView outlives the Activity; Dart disposes it after [InAppBrowserSession.onClosed].
 */
class InAppBrowserActivity : Activity() {
    private var session: InAppBrowserSession? = null
    private var toolbar: Toolbar? = null
    private var foreground = Color.BLACK

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val session = InAppBrowserSessions.get(intent.getLongExtra(EXTRA_WEB_VIEW_ID, -1))
        if (session == null || session.activity != null) {
            // Recreated by the system after the process died, or opened twice: nothing to show.
            finish()
            return
        }
        this.session = session
        session.activity = this
        val web = session.webView
        web.attachToContext(this)

        val toolbar = Toolbar(this).also { this.toolbar = it }
        val params = session.params
        params.toolbarColor?.let {
            val color = it.toInt()
            toolbar.background = ColorDrawable(color)
            foreground = if (Color.luminance(color) > LUMINANCE_THRESHOLD) Color.BLACK else Color.WHITE
            toolbar.setTitleTextColor(foreground)
            toolbar.setSubtitleTextColor(foreground)
        }
        val content = FrameLayout(this)
        content.addView(web.container, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            fitsSystemWindows = true
            addView(toolbar, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
            addView(content, LinearLayout.LayoutParams(MATCH_PARENT, 0, 1f))
        }
        setContentView(root)
        buildMenu(toolbar, params)
        web.onPageStateChanged = ::refreshToolbar
        refreshToolbar()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) {
                handleBack()
            }
        }
    }

    private fun buildMenu(toolbar: Toolbar, params: InAppBrowserParamsMessage) {
        val menu = toolbar.menu
        val label = params.closeButtonLabel
        if (label != null) {
            menu.add(Menu.NONE, ID_CLOSE, ORDER_CLOSE, tinted(label)).setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
        } else {
            toolbar.navigationIcon = getDrawable(android.R.drawable.ic_menu_close_clear_cancel)?.mutate()?.apply {
                setTint(foreground)
            }
            toolbar.navigationContentDescription = getString(android.R.string.cancel)
            toolbar.setNavigationOnClickListener { finish() }
        }
        if (params.showNavigationButtons) {
            menu.add(Menu.NONE, ID_BACK, ORDER_BACK, tinted("‹")).setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
            menu.add(Menu.NONE, ID_FORWARD, ORDER_FORWARD, tinted("›"))
                .setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
            menu.add(Menu.NONE, ID_RELOAD, ORDER_RELOAD, tinted("↻")).setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
        }
        toolbar.setOnMenuItemClickListener(::onMenuItem)
    }

    private fun tinted(text: String): CharSequence = SpannableString(text).apply {
        setSpan(ForegroundColorSpan(foreground), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

    private fun onMenuItem(item: MenuItem): Boolean {
        val webView = session?.webView?.webView ?: return false
        when (item.itemId) {
            ID_CLOSE -> finish()
            ID_BACK -> webView.goBack()
            ID_FORWARD -> webView.goForward()
            ID_RELOAD -> webView.reload()
            else -> return false
        }
        return true
    }

    private fun refreshToolbar() {
        val toolbar = toolbar ?: return
        val webView = session?.webView?.webView ?: return
        val params = session?.params ?: return
        toolbar.title = params.toolbarTitle ?: webView.title.orEmpty()
        toolbar.subtitle = if (params.showUrl) webView.url else null
        toolbar.menu.findItem(ID_BACK)?.isEnabled = webView.canGoBack()
        toolbar.menu.findItem(ID_FORWARD)?.isEnabled = webView.canGoForward()
    }

    private fun handleBack() {
        val webView = session?.webView?.webView
        if (webView != null && webView.canGoBack()) webView.goBack() else finish()
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            super.onBackPressed()
        } else {
            handleBack()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        val session = session ?: return
        this.session = null
        session.webView.onPageStateChanged = null
        // The WebView belongs to Dart and may be shown again; take it out of this Activity's views.
        (session.webView.container.parent as? ViewGroup)?.removeView(session.webView.container)
        session.activity = null
        InAppBrowserSessions.remove(session.webView.id)
        session.onClosed()
    }

    companion object {
        const val EXTRA_WEB_VIEW_ID = "dev.k1t.advanced_webview.WEB_VIEW_ID"

        private const val MATCH_PARENT = ViewGroup.LayoutParams.MATCH_PARENT
        private const val WRAP_CONTENT = ViewGroup.LayoutParams.WRAP_CONTENT
        private const val LUMINANCE_THRESHOLD = 0.5f
        private const val ID_CLOSE = 1
        private const val ID_BACK = 2
        private const val ID_FORWARD = 3
        private const val ID_RELOAD = 4
        private const val ORDER_CLOSE = 0
        private const val ORDER_BACK = 1
        private const val ORDER_FORWARD = 2
        private const val ORDER_RELOAD = 3
    }
}
