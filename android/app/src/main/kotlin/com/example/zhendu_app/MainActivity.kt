package com.example.zhendu_app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

private const val LANDMARK_CHANNEL = "zhenu/mediapipe"
private const val TAG = "NeuroSigne"

class MainActivity : FlutterActivity() {
	private var extractor: MediaPipeKeypointExtractor? = null

	// Les détecteurs MediaPipe sont lourds : ils tournent hors du fil principal
	// pour ne pas figer l'interface.
	private val worker = Executors.newSingleThreadExecutor()

	// Correction d'orientation trouvée automatiquement (voir [uprightFrom]).
	private var rotationFix: Int? = null

	/**
	 * Création à la première utilisation (ou à l'ouverture de la caméra via
	 * « warmup »), jamais au démarrage : un problème MediaPipe ne peut pas
	 * empêcher l'application de s'ouvrir.
	 */
	private fun extractorOrNull(): MediaPipeKeypointExtractor? {
		extractor?.let { return it }
		return try {
			MediaPipeKeypointExtractor(applicationContext).also { extractor = it }
		} catch (error: Throwable) {
			Log.e(TAG, "MediaPipe indisponible", error)
			null
		}
	}

	private fun rotate(bitmap: Bitmap, degrees: Int): Bitmap {
		if (degrees % 360 == 0) return bitmap
		val matrix = Matrix().apply { postRotate(degrees.toFloat()) }
		return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
	}

	/** Image NV21 du flux caméra ➜ Bitmap. */
	private fun nv21ToBitmap(bytes: ByteArray, width: Int, height: Int): Bitmap {
		val yuv = YuvImage(bytes, ImageFormat.NV21, width, height, null)
		val out = ByteArrayOutputStream()
		yuv.compressToJpeg(Rect(0, 0, width, height), 85, out)
		val jpeg = out.toByteArray()
		return BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)
			?: throw IllegalArgumentException("Image caméra illisible")
	}

	/**
	 * Le modèle a été entraîné sur des personnes debout. La rotation fournie
	 * par la caméra est essayée en premier ; si le corps détecté n'est pas
	 * droit (nez sous les épaules ou épaules verticales), les autres
	 * orientations sont testées et la bonne est mémorisée.
	 */
	private fun uprightFrom(frame: Bitmap, sensorRotation: Int, instance: MediaPipeKeypointExtractor): List<Float> {
		rotationFix?.let { return instance.extract(rotate(frame, it)) }
		val candidates = listOf(0, 180, 90, 270).map { (sensorRotation + it) % 360 }
		var first: List<Float>? = null
		for (degrees in candidates) {
			val keypoints = instance.extract(rotate(frame, degrees))
			if (first == null) first = keypoints
			when (MediaPipeKeypointExtractor.isUpright(keypoints)) {
				true -> {
					rotationFix = degrees
					return keypoints
				}
				null -> return keypoints // personne non détectée : on ne peut pas juger
				false -> Unit
			}
		}
		return first!!
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LANDMARK_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					// Prépare les détecteurs dès l'ouverture de la caméra.
					"warmup" -> worker.execute {
						val ready = extractorOrNull() != null
						runOnUiThread { result.success(ready) }
					}

					"extractKeypointsFromNv21", "extractKeypointsFromJpeg" -> {
						val bytes = call.argument<ByteArray>(
							if (call.method == "extractKeypointsFromNv21") "nv21" else "jpeg")
						if (bytes == null) {
							result.error("INVALID_IMAGE", "image manquante", null)
							return@setMethodCallHandler
						}
						val width = call.argument<Int>("width") ?: 0
						val height = call.argument<Int>("height") ?: 0
						val rotation = call.argument<Int>("rotation") ?: 0
						worker.execute {
							var keypoints: List<Float>? = null
							var failure: String? = null
							try {
								val instance = extractorOrNull()
									?: throw IllegalStateException("MediaPipe indisponible sur cet appareil")
								val frame = if (call.method == "extractKeypointsFromNv21") {
									nv21ToBitmap(bytes, width, height)
								} else {
									BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
										?: throw IllegalArgumentException("Image illisible")
								}
								keypoints = uprightFrom(frame, rotation, instance)
							} catch (error: Throwable) {
								Log.e(TAG, "Extraction des points clés impossible", error)
								failure = error.message ?: error.javaClass.simpleName
							}
							runOnUiThread {
								val values = keypoints
								if (values != null) {
									result.success(values)
								} else {
									result.error("LANDMARK_EXTRACTION", failure, null)
								}
							}
						}
					}

					else -> result.notImplemented()
				}
			}
	}

	override fun onDestroy() {
		worker.shutdown()
		try {
			extractor?.close()
		} catch (_: Throwable) {
		}
		extractor = null
		super.onDestroy()
	}
}
