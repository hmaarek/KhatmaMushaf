package com.mushaf.app.mushaf_app

import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private var audioChannel: MethodChannel? = null
    private var mediaPlayer: MediaPlayer? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var currentPlaybackId: Int = 0
    private val mainHandler = Handler(Looper.getMainLooper())

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
        mediaPlayer = nilMediaPlayer()
        tts?.stop()
    }

    private fun nilMediaPlayer(): MediaPlayer? = null

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
        stopActivePlayback()
        tts?.shutdown()
        super.onDestroy()
    }
}
