
//package com.example.aigetai
//
//import io.flutter.embedding.android.FlutterActivity
//
//class MainActivity : FlutterActivity()


package com.example.aigetai

import android.content.pm.PackageInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.util.Log
import android.util.Rational
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val APK_CHANNEL = "apk_icon_channel"
    private val PIP_CHANNEL = "pip_channel"
    private var videoIsPlaying = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // APK ICON CHANNEL (UNCHANGED)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getApkIcon") {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath != null) {
                        val iconBytes = getApkIconBytes(apkPath)
                        if (iconBytes != null) {
                            result.success(iconBytes)
                        } else {
                            result.error("ICON_ERROR", "Failed to extract APK icon", null)
                        }
                    } else {
                        result.error("NULL_PATH", "APK path is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // PiP CHANNEL
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPiPSupported" -> {
                        val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                        Log.d("PiP_DEBUG", "isPiPSupported: $supported")
                        result.success(supported)
                    }
                    "setVideoPlaying" -> {
                        videoIsPlaying = call.argument<Boolean>("playing") ?: false
                        Log.d("PiP_DEBUG", "setVideoPlaying: $videoIsPlaying")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onStop() {
        Log.d("PiP_DEBUG", "onStop called — videoIsPlaying=$videoIsPlaying, isFinishing=$isFinishing, isInPiP=$isInPictureInPictureMode")
        if (videoIsPlaying &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !isFinishing &&
            !isInPictureInPictureMode) {
            Log.d("PiP_DEBUG", " Entering PiP mode!")
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
        } else {
            Log.d("PiP_DEBUG", "PiP skipped")
        }
        super.onStop()
    }

    // APK ICON FUNCTION (UNCHANGED)
    private fun getApkIconBytes(apkPath: String): ByteArray? {
        val pm = applicationContext.packageManager
        val info = pm.getPackageArchiveInfo(apkPath, 0) ?: return null
        val appInfo = info.applicationInfo ?: return null
        appInfo.sourceDir = apkPath
        appInfo.publicSourceDir = apkPath
        val icon = appInfo.loadIcon(pm) ?: return null
        val bitmap = Bitmap.createBitmap(
            icon.intrinsicWidth,
            icon.intrinsicHeight,
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        icon.setBounds(0, 0, canvas.width, canvas.height)
        icon.draw(canvas)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }
}
