package com.example.zhendu_app

import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker

class MediaPipeKeypointExtractor(context: Context) {
    private val face = FaceLandmarker.createFromOptions(
        context,
        FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetPath("face_landmarker.task").build())
            .setRunningMode(RunningMode.IMAGE)
            .setNumFaces(1)
            .build()
    )
    private val hands = HandLandmarker.createFromOptions(
        context,
        HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetPath("hand_landmarker.task").build())
            .setRunningMode(RunningMode.IMAGE)
            .setNumHands(2)
            .build()
    )
    private val pose = PoseLandmarker.createFromOptions(
        context,
        PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetPath("pose_landmarker.task").build())
            .setRunningMode(RunningMode.IMAGE)
            .setNumPoses(1)
            .build()
    )

    fun extract(bitmap: Bitmap): List<Float> {
        val image = BitmapImageBuilder(bitmap).build()
        val output = ArrayList<Float>(1692)

        val poseLandmarks = pose.detect(image).landmarks().firstOrNull().orEmpty()
        poseLandmarks.forEach { landmark ->
            output.add(landmark.x())
            output.add(landmark.y())
            output.add(landmark.z())
            output.add(landmark.visibility().orElse(0f))
        }
        repeat(33 - poseLandmarks.size) { repeat(4) { output.add(0f) } }

        val faceLandmarks = face.detect(image).faceLandmarks().firstOrNull().orEmpty()
        faceLandmarks.forEach { landmark ->
            output.add(landmark.x())
            output.add(landmark.y())
            output.add(landmark.z())
        }
        repeat(478 - faceLandmarks.size) { repeat(3) { output.add(0f) } }

        val detectedHands = hands.detect(image)
        appendHand(output, detectedHands, "Left")
        appendHand(output, detectedHands, "Right")

        check(output.size == 1692) { "MediaPipe output has ${output.size} values, expected 1692" }
        return output
    }

    private fun appendHand(output: MutableList<Float>, result: HandLandmarkerResult, side: String) {
        val index = result.handedness().indexOfFirst {
            it.firstOrNull()?.categoryName() == side
        }
        val landmarks = if (index >= 0) result.landmarks()[index] else emptyList()
        landmarks.forEach { landmark ->
            output.add(landmark.x())
            output.add(landmark.y())
            output.add(landmark.z())
        }
        repeat(21 - landmarks.size) { repeat(3) { output.add(0f) } }
    }

    companion object {
        /**
         * La personne est-elle droite ? `null` si aucun corps n'est détecté.
         * Pose : 33 points × (x, y, z, visibilité) en tête du vecteur.
         */
        fun isUpright(keypoints: List<Float>): Boolean? {
            if (keypoints.size < 132 || keypoints.subList(0, 132).all { it == 0f }) return null
            val noseY = keypoints[1]
            val leftX = keypoints[11 * 4]
            val leftY = keypoints[11 * 4 + 1]
            val rightX = keypoints[12 * 4]
            val rightY = keypoints[12 * 4 + 1]
            val shouldersHorizontal = kotlin.math.abs(leftX - rightX) > kotlin.math.abs(leftY - rightY)
            return shouldersHorizontal && noseY < (leftY + rightY) / 2
        }
    }

    fun close() {
        face.close()
        hands.close()
        pose.close()
    }
}