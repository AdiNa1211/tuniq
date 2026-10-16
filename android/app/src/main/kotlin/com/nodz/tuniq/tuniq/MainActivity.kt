package com.nodz.tuniq.tuniq

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

// Shares audio_service's Flutter engine, so playback outlives the activity.
class MainActivity : AudioServiceActivity() {
    private var mediaStore: MediaStoreChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaStore = MediaStoreChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        mediaStore?.dispose()
        mediaStore = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        mediaStore?.onRequestPermissionsResult(requestCode, grantResults)
    }
}
