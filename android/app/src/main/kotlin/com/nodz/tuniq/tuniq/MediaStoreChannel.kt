package com.nodz.tuniq.tuniq

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Reads the device's music from MediaStore. Method names match the iOS channel. */
class MediaStoreChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPermission: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    private val permission: String
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "authorizationStatus" -> result.success(if (hasPermission()) "authorized" else "denied")
            "requestAuthorization" -> requestPermission(result)
            "openSettings" -> {
                openSettings()
                result.success(null)
            }
            "querySongs" -> querySongs(result)
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE) return
        val result = pendingPermission ?: return
        pendingPermission = null
        val status = when {
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED -> "authorized"
            // After a denial, no rationale means "don't ask again": only Settings can fix it.
            !activity.shouldShowRequestPermissionRationale(permission) -> "permanentlyDenied"
            else -> "denied"
        }
        result.success(status)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    private fun hasPermission() =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success("authorized")
            return
        }
        if (pendingPermission != null) {
            result.error("busy", "A permission request is already showing", null)
            return
        }
        pendingPermission = result
        activity.requestPermissions(arrayOf(permission), REQUEST_CODE)
    }

    private fun openSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null),
        )
        activity.startActivity(intent)
    }

    private fun querySongs(result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error("permission_denied", "Audio permission not granted", null)
            return
        }
        executor.execute {
            try {
                val songs = readSongs()
                mainHandler.post { result.success(songs) }
            } catch (e: Exception) {
                mainHandler.post { result.error("query_failed", e.message, null) }
            }
        }
    }

    @Suppress("DEPRECATION") // DATA is the only folder source below Android 10.
    private fun readSongs(): List<Map<String, Any?>> {
        val modern = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        val collection = if (modern) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
        val folderColumn =
            if (modern) MediaStore.Audio.Media.RELATIVE_PATH else MediaStore.Audio.Media.DATA
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.TRACK,
            folderColumn,
        )
        // IS_MUSIC skips ringtones, alarms, notifications and voice recordings.
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"

        val songs = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(collection, projection, selection, null, sortOrder)
            ?.use { c ->
                val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val albumIdCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
                val durationCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val nameCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                val dateCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
                val trackCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
                val folderCol = c.getColumnIndexOrThrow(folderColumn)
                while (c.moveToNext()) {
                    val id = c.getLong(idCol)
                    val rawFolder = c.getString(folderCol)
                    songs += mapOf(
                        "id" to id.toString(),
                        "title" to (c.getString(titleCol).known() ?: c.getString(nameCol) ?: ""),
                        "artist" to (c.getString(artistCol).known() ?: ""),
                        "album" to (c.getString(albumCol).known() ?: ""),
                        "albumId" to c.getLong(albumIdCol).toString(),
                        "durationMs" to c.getLong(durationCol),
                        "dateAdded" to c.getLong(dateCol),
                        // TRACK encodes disc * 1000 + track number.
                        "trackNumber" to (c.getInt(trackCol) % 1000).takeIf { it > 0 },
                        "folder" to if (modern) rawFolder?.trimEnd('/') else rawFolder?.let { File(it).parent },
                        "assetUrl" to ContentUris.withAppendedId(collection, id).toString(),
                        "isCloudItem" to false,
                        "hasProtectedAsset" to false,
                    )
                }
            }
        return songs
    }

    private fun String?.known(): String? =
        this?.takeIf { it.isNotBlank() && it != MediaStore.UNKNOWN_STRING }

    companion object {
        const val CHANNEL = "tuniq/media_store"
        private const val REQUEST_CODE = 4101
    }
}
