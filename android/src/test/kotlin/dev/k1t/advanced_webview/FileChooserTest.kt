package dev.k1t.advanced_webview

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.webkit.ValueCallback
import android.webkit.WebChromeClient.FileChooserParams
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.verifyNoInteractions
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
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

    @Test
    fun startsThePickerFromTheHostActivity() {
        val host = Robolectric.buildActivity(Activity::class.java).setup().get()
        val params = mock(FileChooserParams::class.java)
        org.mockito.Mockito.`when`(params.createIntent()).thenReturn(Intent(Intent.ACTION_GET_CONTENT))

        assertTrue(FileChooser().show(callback, params, host))

        assertEquals(0x5731, shadowOf(host).nextStartedActivityForResult.requestCode)
    }

    @Test
    fun releasingTheHostCancelsItsRequest() {
        val host = Robolectric.buildActivity(Activity::class.java).setup().get()
        val params = mock(FileChooserParams::class.java)
        org.mockito.Mockito.`when`(params.createIntent()).thenReturn(Intent(Intent.ACTION_GET_CONTENT))
        val chooser = FileChooser()
        chooser.show(callback, params, host)

        chooser.release(host)

        verify(callback).onReceiveValue(null)
    }
}
