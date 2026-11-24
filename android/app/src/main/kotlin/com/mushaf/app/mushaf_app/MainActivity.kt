package com.mushaf.app.mushaf_app

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private var audioChannel: MethodChannel? = null
    private var systemChannel: MethodChannel? = null
    private var mediaPlayer: MediaPlayer? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var currentPlaybackId: Int = 0
    private val mainHandler = Handler(Looper.getMainLooper())
    private val videoExecutor = Executors.newSingleThreadExecutor()
    private val videoCancelled = AtomicBoolean(false)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tts = TextToSpeech(this, this)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mushaf.app/audio")
        audioChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "playFile" -> {
                    val path = call.argument<String>("path")
                    val playbackId = call.argument<Int>("playbackId") ?: 0
                    if (path == null) {
                        result.error("INVALID_ARGS", "Missing file path", null)
                        return@setMethodCallHandler
                    }
                    stopActivePlayback()
                    currentPlaybackId = playbackId
                    try {
                        val mp = MediaPlayer()
                        mp.setDataSource(path)
                        mp.setOnCompletionListener {
                            val finishedId = currentPlaybackId
                            mainHandler.post {
                                audioChannel?.invokeMethod(
                                    "onPlaybackCompleted",
                                    mapOf("playbackId" to finishedId, "success" to true)
                                )
                            }
                        }
                        mp.setOnErrorListener { _, _, _ ->
                            val finishedId = currentPlaybackId
                            mainHandler.post {
                                audioChannel?.invokeMethod(
                                    "onPlaybackCompleted",
                                    mapOf("playbackId" to finishedId, "success" to false)
                                )
                            }
                            true
                        }
                        mp.prepare()
                        mp.start()
                        mediaPlayer = mp
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PLAY_ERROR", e.localizedMessage, null)
                    }
                }
                "speakArabic" -> {
                    val text = call.argument<String>("text")
                    val playbackId = call.argument<Int>("playbackId") ?: 0
                    if (text == null) {
                        result.error("INVALID_ARGS", "Missing text", null)
                        return@setMethodCallHandler
                    }
                    stopActivePlayback()
                    currentPlaybackId = playbackId
                    if (ttsReady && tts != null) {
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, playbackId.toString())
                        result.success(true)
                    } else {
                        result.error("TTS_UNAVAILABLE", "Arabic TTS not ready", null)
                    }
                }
                "stop" -> {
                    stopActivePlayback()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val sysChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.mushaf.app/system")
        systemChannel = sysChannel
        sysChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "scheduleKhatmaReminder" -> {
                    val title = call.argument<String>("title") ?: "مصحف الختمة"
                    val body = call.argument<String>("body") ?: ""
                    val delaySeconds = (call.argument<Int>("delaySeconds") ?: 86400).coerceAtLeast(60)
                    if (Build.VERSION.SDK_INT >= 33) {
                        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2401)
                        }
                    }
                    scheduleAndroidKhatmaReminder(title, body, delaySeconds)
                    result.success(true)
                }
                "cancelKhatmaReminder" -> {
                    cancelAndroidKhatmaReminder()
                    result.success(true)
                }
                "shareText" -> {
                    val text = call.argument<String>("text")
                    if (text.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        startActivity(Intent.createChooser(sendIntent, null))
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "shareImage" -> {
                    val path = call.argument<String>("path")
                    val caption = call.argument<String>("caption")
                    if (path.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val ok = shareMediaFileViaProvider(
                        srcPath = path,
                        targetFileName = "Khatma_Mushaf_${System.currentTimeMillis()}.png",
                        mimeType = "image/png",
                        caption = caption
                    )
                    result.success(ok)
                }
                "createAndShareRecitationVideo" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val audioPaths = call.argument<List<String>>("audioPaths")
                    val caption = call.argument<String>("caption")
                    if (imagePath.isNullOrBlank() || audioPaths.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    videoCancelled.set(false)
                    videoExecutor.execute {
                        val shareDir = prepareSharedMediaDir()
                        val outFile = File(shareDir, "Khatma_Mushaf_Recitation_${System.currentTimeMillis()}.mp4")
                        val exporter = RecitationVideoExporter()
                        val ok = exporter.buildRecitationVideo(
                            imagePath = imagePath,
                            audioPaths = audioPaths,
                            outputFile = outFile,
                            isCancelled = { videoCancelled.get() },
                            onProgress = { progress ->
                                mainHandler.post {
                                    systemChannel?.invokeMethod(
                                        "onVideoProgress",
                                        mapOf("progress" to progress)
                                    )
                                }
                            }
                        )
                        mainHandler.post {
                            if (ok && !videoCancelled.get() && outFile.exists()) {
                                val shared = launchShareIntentForFile(
                                    file = outFile,
                                    mimeType = "video/mp4",
                                    caption = caption
                                )
                                result.success(shared)
                            } else {
                                outFile.delete()
                                result.success(false)
                            }
                        }
                    }
                }
                "cancelRecitationVideo" -> {
                    videoCancelled.set(true)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun prepareSharedMediaDir(): File {
        val dir = File(cacheDir, "shared_media")
        if (!dir.exists()) dir.mkdirs()
        val cutoff = System.currentTimeMillis() - 60L * 60L * 1000L
        dir.listFiles()?.forEach { f ->
            if (f.lastModified() < cutoff) {
                f.delete()
            }
        }
        return dir
    }

    private fun shareMediaFileViaProvider(
        srcPath: String,
        targetFileName: String,
        mimeType: String,
        caption: String?
    ): Boolean {
        return try {
            val srcFile = File(srcPath)
            if (!srcFile.exists()) return false
            val shareDir = prepareSharedMediaDir()
            val outFile = File(shareDir, targetFileName)
            srcFile.copyTo(outFile, overwrite = true)
            launchShareIntentForFile(outFile, mimeType, caption)
        } catch (_: Exception) {
            false
        }
    }

    private fun launchShareIntentForFile(
        file: File,
        mimeType: String,
        caption: String?
    ): Boolean {
        return try {
            val authority = "$packageName.fileprovider"
            val uri = FileProvider.getUriForFile(this, authority, file)
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                if (!caption.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_TEXT, caption)
                }
                clipData = ClipData.newRawUri(file.name, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(sendIntent, null).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(chooser)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun scheduleAndroidKhatmaReminder(title: String, body: String, delaySeconds: Int) {
        try {
            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, KhatmaReminderReceiver::class.java).apply {
                putExtra("title", title)
                putExtra("body", body)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pi = PendingIntent.getBroadcast(this, 2401, intent, flags)
            val triggerAt = System.currentTimeMillis() + (delaySeconds.toLong() * 1000L)
            am.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                AlarmManager.INTERVAL_DAY,
                pi
            )
        } catch (_: Exception) {}
    }

    private fun cancelAndroidKhatmaReminder() {
        try {
            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, KhatmaReminderReceiver::class.java)
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pi = PendingIntent.getBroadcast(this, 2401, intent, flags)
            am.cancel(pi)
        } catch (_: Exception) {}
    }

    private fun stopActivePlayback() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
        } catch (_: Exception) {}
        mediaPlayer = null
        tts?.stop()
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale("ar")
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) {
                    val finishedId = currentPlaybackId
                    mainHandler.post {
                        audioChannel?.invokeMethod(
                            "onPlaybackCompleted",
                            mapOf("playbackId" to finishedId, "success" to true)
                        )
                    }
                }
                override fun onError(utteranceId: String?) {
                    val finishedId = currentPlaybackId
                    mainHandler.post {
                        audioChannel?.invokeMethod(
                            "onPlaybackCompleted",
                            mapOf("playbackId" to finishedId, "success" to false)
                        )
                    }
                }
            })
            ttsReady = true
        }
    }

    override fun onDestroy() {
        videoCancelled.set(true)
        videoExecutor.shutdownNow()
        stopActivePlayback()
        tts?.shutdown()
        super.onDestroy()
    }
}
