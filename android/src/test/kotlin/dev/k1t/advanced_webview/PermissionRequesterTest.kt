package dev.k1t.advanced_webview

import android.app.Activity
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PermissionRequesterTest {
    @Test
    fun grantsNothingWithoutAnActivity() {
        var result: Set<String>? = null

        PermissionRequester().request(listOf("android.permission.CAMERA")) { result = it }

        assertEquals(emptySet(), result)
    }

    @Test
    fun ignoresResultsFromOtherRequests() {
        assertFalse(PermissionRequester().onRequestPermissionsResult(1, emptyArray(), IntArray(0)))
    }

    @Test
    fun consumesItsOwnResultEvenWhenNothingIsPending() {
        assertTrue(PermissionRequester().onRequestPermissionsResult(0x5732, emptyArray(), IntArray(0)))
    }

    @Test
    fun asksFromTheHostActivityAndSettlesWhenItIsReleased() {
        val host = Robolectric.buildActivity(Activity::class.java).setup().get()
        val requester = PermissionRequester()
        var result: Set<String>? = null

        requester.request(listOf("android.permission.CAMERA"), host) { result = it }

        assertEquals(
            listOf("android.permission.CAMERA"),
            shadowOf(host).lastRequestedPermission.requestedPermissions.toList(),
        )
        assertEquals(null, result)
        requester.release(host)
        assertEquals(emptySet(), result)
    }
}
