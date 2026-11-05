package android.print

import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import java.io.File

/**
 * Writes a [PrintDocumentAdapter] to a PDF file. [PrintDocumentAdapter.LayoutResultCallback] and
 * [PrintDocumentAdapter.WriteResultCallback] have package-private constructors, so this lives in the
 * `android.print` package. Must be called on the main thread; [onDone] runs there too.
 */
object PdfExporter {
    fun export(adapter: PrintDocumentAdapter, file: File, onDone: (Throwable?) -> Unit) {
        val attributes = PrintAttributes.Builder()
            .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
            .setResolution(PrintAttributes.Resolution("pdf", "pdf", 300, 300))
            .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
            .build()
        adapter.onLayout(
            null,
            attributes,
            CancellationSignal(),
            object : PrintDocumentAdapter.LayoutResultCallback() {
                override fun onLayoutFinished(info: PrintDocumentInfo?, changed: Boolean) {
                    val descriptor = try {
                        ParcelFileDescriptor.open(
                            file,
                            ParcelFileDescriptor.MODE_READ_WRITE or ParcelFileDescriptor.MODE_CREATE or
                                ParcelFileDescriptor.MODE_TRUNCATE,
                        )
                    } catch (e: Exception) {
                        adapter.onFinish()
                        onDone(e)
                        return
                    }
                    adapter.onWrite(
                        arrayOf(PageRange.ALL_PAGES),
                        descriptor,
                        CancellationSignal(),
                        object : PrintDocumentAdapter.WriteResultCallback() {
                            override fun onWriteFinished(pages: Array<out PageRange>?) {
                                descriptor.close()
                                adapter.onFinish()
                                onDone(null)
                            }

                            override fun onWriteFailed(error: CharSequence?) {
                                descriptor.close()
                                adapter.onFinish()
                                onDone(IllegalStateException(error?.toString() ?: "Writing the PDF failed"))
                            }
                        },
                    )
                }

                override fun onLayoutFailed(error: CharSequence?) {
                    adapter.onFinish()
                    onDone(IllegalStateException(error?.toString() ?: "Laying out the PDF failed"))
                }
            },
            null,
        )
    }
}
