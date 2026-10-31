package dev.k1t.advanced_webview

import android.net.Uri
import android.webkit.ValueCallback
import android.webkit.WebChromeClient.FileChooserParams
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.verifyNoInteractions
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class FileChooserTest {
    @Suppress("UNCHECKED_CAST")
    private val callback = mock(ValueCallback::class.java) as ValueCallback<Array<Uri>>

    @Test
    fun showReturnsFalseAndLeavesTheCallbackAloneWithoutAnActivity() {
        val shown = FileChooser().show(callback, mock(FileChooserParams::class.java))

        assertFalse(shown)
        verifyNoInteractions(callback)
    }

    @Test
    fun ignoresActivityResultsFromOtherRequests() {
        assertFalse(FileChooser().onActivityResult(1, 0, null))
    }

    @Test
    fun consumesItsOwnResultEvenWhenNothingIsPending() {
        assertTrue(FileChooser().onActivityResult(0x5731, 0, null))
    }
}
