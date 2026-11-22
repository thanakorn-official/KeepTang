package com.example.expense_tracker

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ColorSpace
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Build
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.io.IOException
import kotlin.math.max
import kotlin.math.roundToInt

internal class ThaiSlipTextRecognizer(private val context: Context) {
    companion object {
        private const val CHANNEL = "keeptang/slip_ocr"
        private const val MAX_IMAGE_SIDE = 2200
        private val modelCopyLock = Any()

        fun register(context: Context, messenger: BinaryMessenger): MethodChannel {
            val recognizer = ThaiSlipTextRecognizer(context)
            return MethodChannel(
                messenger,
                CHANNEL,
                StandardMethodCodec.INSTANCE,
                messenger.makeBackgroundTaskQueue(),
            ).apply {
                setMethodCallHandler { call, result ->
                    if (call.method != "recognizeThai") {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(recognizer.recognize(File(path)))
                    } catch (error: Exception) {
                        // Flutter will continue using its existing recognizer.
                        result.error("thai_ocr_failed", "Thai OCR was unavailable", null)
                    } catch (error: LinkageError) {
                        result.error("thai_ocr_unavailable", "Thai OCR was unavailable", null)
                    }
                }
            }
        }
    }

    private fun recognize(file: File): String? {
        val dataDirectory = prepareModelFiles()
        val image = decodeImage(file) ?: return null
        try {
            val tesseract = TessBaseAPI()
            try {
                if (!tesseract.init(dataDirectory.absolutePath, "tha+eng", TessBaseAPI.OEM_LSTM_ONLY)) {
                    return null
                }
                tesseract.setPageSegMode(TessBaseAPI.PageSegMode.PSM_AUTO)
                tesseract.setImage(image)
                return tesseract.getUTF8Text()?.takeIf { it.isNotBlank() }
            } finally {
                tesseract.recycle()
            }
        } finally {
            image.recycle()
        }
    }

    private fun prepareModelFiles(): File = synchronized(modelCopyLock) {
        val dataDirectory = File(context.noBackupFilesDir, "tesseract-4.1.0")
        val modelDirectory = File(dataDirectory, "tessdata")
        if (!modelDirectory.isDirectory && !modelDirectory.mkdirs()) {
            throw IOException("Could not prepare OCR model directory")
        }
        for ((language, fileSize) in mapOf("tha" to 1_072_600L, "eng" to 4_113_088L)) {
            val name = "$language.traineddata"
            val model = File(modelDirectory, name)
            if (model.isFile && model.length() == fileSize) continue

            val staged = File.createTempFile(language, ".tmp", modelDirectory)
            try {
                context.assets.open("ocr/$name").use { source ->
                    staged.outputStream().use { output -> source.copyTo(output) }
                }
                if (staged.length() != fileSize || !staged.renameTo(model)) {
                    throw IOException("Could not install OCR model")
                }
            } finally {
                staged.delete()
            }
        }
        dataDirectory
    }

    private fun decodeImage(file: File): Bitmap? {
        if (!file.isFile) return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // ImageDecoder applies the image orientation before OCR.
            return ImageDecoder.decodeBitmap(ImageDecoder.createSource(file)) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                decoder.setTargetColorSpace(ColorSpace.get(ColorSpace.Named.SRGB))
                val maxSide = max(info.size.width, info.size.height)
                if (maxSide > MAX_IMAGE_SIDE) {
                    val ratio = MAX_IMAGE_SIDE.toDouble() / maxSide
                    decoder.setTargetSize(
                        (info.size.width * ratio).roundToInt().coerceAtLeast(1),
                        (info.size.height * ratio).roundToInt().coerceAtLeast(1),
                    )
                }
            }
        }

        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, options)
        val maxSide = max(options.outWidth, options.outHeight)
        if (maxSide <= 0) return null
        var sampleSize = 1
        while (maxSide / sampleSize > MAX_IMAGE_SIDE) sampleSize *= 2
        options.inJustDecodeBounds = false
        options.inSampleSize = sampleSize
        val bitmap = BitmapFactory.decodeFile(file.absolutePath, options) ?: return null
        return applyExifOrientation(file, bitmap)
    }

    private fun applyExifOrientation(file: File, bitmap: Bitmap): Bitmap {
        val orientation = try {
            ExifInterface(file.absolutePath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (error: IOException) {
            ExifInterface.ORIENTATION_NORMAL
        }
        val transform = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> transform.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> transform.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> transform.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                transform.setRotate(90f)
                transform.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> transform.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                transform.setRotate(-90f)
                transform.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> transform.setRotate(-90f)
            else -> return bitmap
        }
        try {
            return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, transform, true)
        } finally {
            bitmap.recycle()
        }
    }
}
