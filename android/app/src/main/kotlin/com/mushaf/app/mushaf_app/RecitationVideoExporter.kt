package com.mushaf.app.mushaf_app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.GLUtils
import android.view.Surface
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Native Android MP4 recitation video exporter with 1:1 visual parity to iOS:
 * - Decodes and concatenates one or more ayah MP3 audio files into a unified AAC track.
 * - Renders an H.264 video track from the illuminated Ayah card PNG with a soft
 *   breathing golden ambient shimmer and an RTL golden recitation progress bar.
 * - Uses EGL14 + eglPresentationTimeANDROID on a hardware/software MediaCodec input
 *   Surface for deterministic frame timing across all Android devices.
 */
class RecitationVideoExporter {

    private data class EncodedPacket(
        val data: ByteArray,
        val presentationTimeUs: Long,
        val flags: Int
    )

    private data class EncodedAudioResult(
        val format: MediaFormat,
        val packets: List<EncodedPacket>,
        val durationSec: Double
    )

    fun buildRecitationVideo(
        imagePath: String,
        audioPaths: List<String>,
        outputFile: File,
        isCancelled: () -> Boolean,
        onProgress: (Double) -> Unit
    ): Boolean {
        val rawBitmap = BitmapFactory.decodeFile(imagePath) ?: return false
        try {
            if (isCancelled()) return false
            onProgress(0.60)

            // 1. Decode all MP3 ayah files to normalized PCM and encode to AAC
            val audioResult = encodeConcatenatedAudioToAac(
                audioPaths = audioPaths,
                isCancelled = isCancelled,
                onDecodeProgress = { frac -> onProgress(0.60 + frac * 0.14) }
            ) ?: return false

            if (isCancelled() || audioResult.durationSec <= 0.2 || audioResult.packets.isEmpty()) {
                return false
            }

            // 2. Compute hardware-safe dimensions (multiples of 16, max 720x1280)
            val rawW = rawBitmap.width.toDouble().coerceAtLeast(1.0)
            val rawH = rawBitmap.height.toDouble().coerceAtLeast(1.0)
            val scale = min(1.0, min(720.0 / rawW, 1280.0 / rawH))
            val videoWidth = max(320, ((rawW * scale).toInt() / 16) * 16)
            val videoHeight = max(320, ((rawH * scale).toInt() / 16) * 16)

            val scaledCard = Bitmap.createScaledBitmap(rawBitmap, videoWidth, videoHeight, true)
            val frameBitmap = Bitmap.createBitmap(videoWidth, videoHeight, Bitmap.Config.ARGB_8888)
            val frameCanvas = Canvas(frameBitmap)

            if (outputFile.exists()) outputFile.delete()
            outputFile.parentFile?.mkdirs()

            try {
                val ok = encodeVideoAndMux(
                    cardBitmap = scaledCard,
                    frameBitmap = frameBitmap,
                    frameCanvas = frameCanvas,
                    videoWidth = videoWidth,
                    videoHeight = videoHeight,
                    audioResult = audioResult,
                    outputFile = outputFile,
                    isCancelled = isCancelled,
                    onProgress = { frac -> onProgress(0.75 + frac * 0.23) }
                )
                if (!ok || isCancelled() || !outputFile.exists() || outputFile.length() == 0L) {
                    outputFile.delete()
                    return false
                }
                onProgress(1.0)
                return true
            } finally {
                if (scaledCard !== rawBitmap) scaledCard.recycle()
                frameBitmap.recycle()
            }
        } finally {
            rawBitmap.recycle()
        }
    }

    private fun encodeConcatenatedAudioToAac(
        audioPaths: List<String>,
        isCancelled: () -> Boolean,
        onDecodeProgress: (Double) -> Unit
    ): EncodedAudioResult? {
        val targetSampleRate = 44100
        val targetChannels = 1
        val pcmOut = ByteArrayOutputStream(256 * 1024)

        for ((idx, path) in audioPaths.withIndex()) {
            if (isCancelled()) return null
            val f = File(path)
            if (!f.exists() || f.length() == 0L) continue
            decodeAudioFileToPcm(
                filePath = path,
                targetSampleRate = targetSampleRate,
                targetChannels = targetChannels,
                outStream = pcmOut,
                isCancelled = isCancelled
            )
            onDecodeProgress((idx + 1).toDouble() / max(1, audioPaths.size) * 0.7)
        }

        val allPcm = pcmOut.toByteArray()
        if (allPcm.isEmpty() || isCancelled()) return null

        val totalSamples = allPcm.size / (2 * targetChannels)
        val durationSec = totalSamples.toDouble() / targetSampleRate.toDouble()
        if (durationSec <= 0.2) return null

        val encoderFormat = MediaFormat.createAudioFormat(
            MediaFormat.MIMETYPE_AUDIO_AAC,
            targetSampleRate,
            targetChannels
        ).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, 96_000)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
        }

        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        val packets = ArrayList<EncodedPacket>()
        var outputFormat: MediaFormat? = null

        try {
            encoder.configure(encoderFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()

            val bufferInfo = MediaCodec.BufferInfo()
            var offset = 0
            var inputDone = false
            var outputDone = false
            var samplesSubmitted = 0L

            while (!outputDone) {
                if (isCancelled()) return null

                if (!inputDone) {
                    val inIdx = encoder.dequeueInputBuffer(10_000)
                    if (inIdx >= 0) {
                        val inBuf = encoder.getInputBuffer(inIdx)
                        if (inBuf != null) {
                            inBuf.clear()
                            val remaining = allPcm.size - offset
                            if (remaining <= 0) {
                                encoder.queueInputBuffer(
                                    inIdx,
                                    0,
                                    0,
                                    (samplesSubmitted * 1_000_000L) / targetSampleRate,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                inputDone = true
                            } else {
                                val chunk = min(remaining, inBuf.capacity())
                                // Keep 16-bit frame alignment
                                val alignedChunk = (chunk / (2 * targetChannels)) * (2 * targetChannels)
                                inBuf.put(allPcm, offset, alignedChunk)
                                val ptsUs = (samplesSubmitted * 1_000_000L) / targetSampleRate
                                encoder.queueInputBuffer(inIdx, 0, alignedChunk, ptsUs, 0)
                                offset += alignedChunk
                                samplesSubmitted += alignedChunk / (2 * targetChannels)
                            }
                        }
                    }
                }

                val outIdx = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
                when {
                    outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        outputFormat = encoder.outputFormat
                    }
                    outIdx >= 0 -> {
                        val outBuf = encoder.getOutputBuffer(outIdx)
                        if (outBuf != null && bufferInfo.size > 0 &&
                            (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0
                        ) {
                            outBuf.position(bufferInfo.offset)
                            outBuf.limit(bufferInfo.offset + bufferInfo.size)
                            val copy = ByteArray(bufferInfo.size)
                            outBuf.get(copy)
                            packets.add(
                                EncodedPacket(
                                    data = copy,
                                    presentationTimeUs = bufferInfo.presentationTimeUs,
                                    flags = bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM.inv()
                                )
                            )
                        }
                        encoder.releaseOutputBuffer(outIdx, false)
                        if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            outputDone = true
                        }
                    }
                }
            }
            onDecodeProgress(1.0)
        } finally {
            try { encoder.stop() } catch (_: Exception) {}
            try { encoder.release() } catch (_: Exception) {}
        }

        val finalFormat = outputFormat ?: return null
        return EncodedAudioResult(
            format = finalFormat,
            packets = packets,
            durationSec = durationSec
        )
    }

    private fun decodeAudioFileToPcm(
        filePath: String,
        targetSampleRate: Int,
        targetChannels: Int,
        outStream: ByteArrayOutputStream,
        isCancelled: () -> Boolean
    ) {
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        try {
            extractor.setDataSource(filePath)
            var audioTrackIndex = -1
            var inputFormat: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val fmt = extractor.getTrackFormat(i)
                val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    inputFormat = fmt
                    break
                }
            }
            if (audioTrackIndex < 0 || inputFormat == null) return
            extractor.selectTrack(audioTrackIndex)

            val mime = inputFormat.getString(MediaFormat.KEY_MIME) ?: return
            var srcSampleRate = if (inputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else {
                targetSampleRate
            }
            var srcChannels = if (inputFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } else {
                1
            }

            decoder = MediaCodec.createDecoderByType(mime)
            decoder.configure(inputFormat, null, null, 0)
            decoder.start()

            val info = MediaCodec.BufferInfo()
            var sawInputEos = false
            var sawOutputEos = false
            val rawPcmForFile = ByteArrayOutputStream(128 * 1024)

            while (!sawOutputEos) {
                if (isCancelled()) return

                if (!sawInputEos) {
                    val inIdx = decoder.dequeueInputBuffer(10_000)
                    if (inIdx >= 0) {
                        val inBuf = decoder.getInputBuffer(inIdx)
                        if (inBuf != null) {
                            val sampleSize = extractor.readSampleData(inBuf, 0)
                            if (sampleSize < 0) {
                                decoder.queueInputBuffer(
                                    inIdx, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                sawInputEos = true
                            } else {
                                decoder.queueInputBuffer(
                                    inIdx, 0, sampleSize, extractor.sampleTime, 0
                                )
                                extractor.advance()
                            }
                        }
                    }
                }

                val outIdx = decoder.dequeueOutputBuffer(info, 10_000)
                when {
                    outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val outFmt = decoder.outputFormat
                        if (outFmt.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                            srcSampleRate = outFmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        }
                        if (outFmt.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                            srcChannels = outFmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        }
                    }
                    outIdx >= 0 -> {
                        val outBuf = decoder.getOutputBuffer(outIdx)
                        if (outBuf != null && info.size > 0) {
                            outBuf.position(info.offset)
                            outBuf.limit(info.offset + info.size)
                            val chunk = ByteArray(info.size)
                            outBuf.get(chunk)
                            rawPcmForFile.write(chunk)
                        }
                        decoder.releaseOutputBuffer(outIdx, false)
                        if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            sawOutputEos = true
                        }
                    }
                }
            }

            val rawBytes = rawPcmForFile.toByteArray()
            if (rawBytes.isEmpty()) return

            // Convert to mono 16-bit LE and linearly resample to targetSampleRate if needed
            val normalized = normalizePcmToMono(
                pcmBytes = rawBytes,
                srcSampleRate = srcSampleRate,
                srcChannels = srcChannels,
                dstSampleRate = targetSampleRate
            )
            if (targetChannels == 1) {
                outStream.write(normalized)
            } else {
                outStream.write(normalized)
            }
        } catch (_: Exception) {
            // Skip unreadable audio chunk
        } finally {
            try { decoder?.stop() } catch (_: Exception) {}
            try { decoder?.release() } catch (_: Exception) {}
            try { extractor.release() } catch (_: Exception) {}
        }
    }

    private fun normalizePcmToMono(
        pcmBytes: ByteArray,
        srcSampleRate: Int,
        srcChannels: Int,
        dstSampleRate: Int
    ): ByteArray {
        val ch = max(1, srcChannels)
        val totalFrames = pcmBytes.size / (2 * ch)
        if (totalFrames <= 0) return ByteArray(0)

        val bb = ByteBuffer.wrap(pcmBytes).order(ByteOrder.LITTLE_ENDIAN)
        val monoSrc = ShortArray(totalFrames)
        if (ch == 1) {
            for (i in 0 until totalFrames) {
                monoSrc[i] = bb.short
            }
        } else {
            for (i in 0 until totalFrames) {
                var sum = 0
                for (c in 0 until ch) {
                    sum += bb.short.toInt()
                }
                monoSrc[i] = (sum / ch).coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }
        }

        val monoDst = if (srcSampleRate == dstSampleRate || srcSampleRate <= 0) {
            monoSrc
        } else {
            val ratio = dstSampleRate.toDouble() / srcSampleRate.toDouble()
            val dstLen = max(1, (totalFrames * ratio).roundToInt())
            val resampled = ShortArray(dstLen)
            for (i in 0 until dstLen) {
                val srcPos = i / ratio
                val idx0 = srcPos.toInt().coerceIn(0, totalFrames - 1)
                val idx1 = min(idx0 + 1, totalFrames - 1)
                val frac = srcPos - idx0
                val sample = monoSrc[idx0] * (1.0 - frac) + monoSrc[idx1] * frac
                resampled[i] = sample.roundToInt()
                    .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }
            resampled
        }

        val outBytes = ByteArray(monoDst.size * 2)
        val outBb = ByteBuffer.wrap(outBytes).order(ByteOrder.LITTLE_ENDIAN)
        for (s in monoDst) {
            outBb.putShort(s)
        }
        return outBytes
    }

    private fun encodeVideoAndMux(
        cardBitmap: Bitmap,
        frameBitmap: Bitmap,
        frameCanvas: Canvas,
        videoWidth: Int,
        videoHeight: Int,
        audioResult: EncodedAudioResult,
        outputFile: File,
        isCancelled: () -> Boolean,
        onProgress: (Double) -> Unit
    ): Boolean {
        val fps = 8
        val totalFrames = max(1, ceil(audioResult.durationSec * fps).toInt())

        val videoFormat = MediaFormat.createVideoFormat(
            MediaFormat.MIMETYPE_VIDEO_AVC,
            videoWidth,
            videoHeight
        ).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface
            )
            setInteger(MediaFormat.KEY_BIT_RATE, 900_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
        }

        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        var inputSurface: Surface? = null
        var eglRenderer: EglBitmapRenderer? = null
        var muxer: MediaMuxer? = null
        var muxerStarted = false
        var videoTrackIndex = -1
        var audioTrackIndex = -1
        var audioWritten = false

        val srcRect = Rect(0, 0, cardBitmap.width, cardBitmap.height)
        val dstRect = RectF(0f, 0f, videoWidth.toFloat(), videoHeight.toFloat())
        val basePaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        val shimmerPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(46, 217, 163, 64)
            style = Paint.Style.FILL
        }
        val activeBarPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(224, 217, 163, 64)
            style = Paint.Style.FILL
        }
        val orbPaint = Paint(Paint.ANTI_ALIAS_FLAG)

        try {
            encoder.configure(videoFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            inputSurface = encoder.createInputSurface()
            encoder.start()

            eglRenderer = EglBitmapRenderer(inputSurface, videoWidth, videoHeight)
            muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            val bufferInfo = MediaCodec.BufferInfo()

            fun drainEncoder(endOfStream: Boolean) {
                if (endOfStream) {
                    encoder.signalEndOfInputStream()
                }
                while (true) {
                    val outIdx = encoder.dequeueOutputBuffer(bufferInfo, if (endOfStream) 10_000 else 0)
                    when {
                        outIdx == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                            if (!endOfStream) break
                        }
                        outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            if (!muxerStarted) {
                                videoTrackIndex = muxer!!.addTrack(encoder.outputFormat)
                                audioTrackIndex = muxer!!.addTrack(audioResult.format)
                                muxer!!.start()
                                muxerStarted = true
                                // Write pre-encoded AAC packets immediately
                                if (!audioWritten) {
                                    val aInfo = MediaCodec.BufferInfo()
                                    for (pkt in audioResult.packets) {
                                        if (isCancelled()) break
                                        val buf = ByteBuffer.wrap(pkt.data)
                                        aInfo.set(0, pkt.data.size, pkt.presentationTimeUs, pkt.flags)
                                        muxer!!.writeSampleData(audioTrackIndex, buf, aInfo)
                                    }
                                    audioWritten = true
                                }
                            }
                        }
                        outIdx >= 0 -> {
                            val encodedData = encoder.getOutputBuffer(outIdx)
                            if (encodedData != null && bufferInfo.size > 0 &&
                                (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0 &&
                                muxerStarted
                            ) {
                                encodedData.position(bufferInfo.offset)
                                encodedData.limit(bufferInfo.offset + bufferInfo.size)
                                muxer!!.writeSampleData(videoTrackIndex, encodedData, bufferInfo)
                            }
                            encoder.releaseOutputBuffer(outIdx, false)
                            if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                                break
                            }
                        }
                    }
                }
            }

            for (frameIdx in 0..totalFrames) {
                if (isCancelled()) return false

                // Draw base Ayah card + ambient golden shimmer + RTL progress thread
                frameCanvas.drawBitmap(cardBitmap, srcRect, dstRect, basePaint)
                drawAmbientOverlay(
                    canvas = frameCanvas,
                    w = videoWidth.toFloat(),
                    h = videoHeight.toFloat(),
                    frameIdx = frameIdx,
                    totalFrames = totalFrames,
                    fps = fps,
                    shimmerPaint = shimmerPaint,
                    trackPaint = trackPaint,
                    activeBarPaint = activeBarPaint,
                    orbPaint = orbPaint
                )

                val ptsNanos = (frameIdx.toLong() * 1_000_000_000L) / fps.toLong()
                eglRenderer.drawBitmapFrame(frameBitmap, ptsNanos)
                drainEncoder(endOfStream = false)

                if (frameIdx % 4 == 0 || frameIdx == totalFrames) {
                    onProgress(frameIdx.toDouble() / max(1, totalFrames).toDouble())
                }
            }

            if (isCancelled()) return false
            drainEncoder(endOfStream = true)
            return muxerStarted
        } catch (_: Exception) {
            return false
        } finally {
            try { eglRenderer?.release() } catch (_: Exception) {}
            try { encoder.stop() } catch (_: Exception) {}
            try { encoder.release() } catch (_: Exception) {}
            try { inputSurface?.release() } catch (_: Exception) {}
            try {
                if (muxerStarted) {
                    muxer?.stop()
                }
            } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
        }
    }

    private fun drawAmbientOverlay(
        canvas: Canvas,
        w: Float,
        h: Float,
        frameIdx: Int,
        totalFrames: Int,
        fps: Int,
        shimmerPaint: Paint,
        trackPaint: Paint,
        activeBarPaint: Paint,
        orbPaint: Paint
    ) {
        val tSec = frameIdx.toDouble() / fps.toDouble()
        val progress = (frameIdx.toDouble() / max(1, totalFrames).toDouble()).coerceIn(0.0, 1.0).toFloat()

        // 1. Soft breathing golden radial shimmer orbiting across the card
        val pulseAlpha = (0.07 + 0.055 * (0.5 + 0.5 * sin(tSec * 2.2))).toFloat()
        val cx = w * (0.5 + 0.24 * cos(tSec * 1.15)).toFloat()
        val cy = h * (0.48 - 0.18 * sin(tSec * 0.85)).toFloat()
        val radius = max(w, h) * 0.62f

        shimmerPaint.shader = RadialGradient(
            cx,
            cy,
            radius,
            intArrayOf(
                Color.argb((pulseAlpha * 255).toInt().coerceIn(0, 255), 245, 204, 92),
                Color.argb((pulseAlpha * 0.35f * 255).toInt().coerceIn(0, 255), 217, 163, 64),
                Color.argb(0, 217, 163, 64)
            ),
            floatArrayOf(0f, 0.45f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawRect(0f, 0f, w, h, shimmerPaint)

        // 2. RTL golden progress bar with glowing tip along bottom inner border
        val marginX = 24f
        val barY = h - 13f
        val trackWidth = max(10f, w - marginX * 2f)
        val activeWidth = trackWidth * progress
        val rightX = w - marginX
        val tipX = rightX - activeWidth

        canvas.drawRect(marginX, barY - 1.5f, marginX + trackWidth, barY + 1.5f, trackPaint)
        canvas.drawRect(tipX, barY - 1.5f, rightX, barY + 1.5f, activeBarPaint)

        orbPaint.shader = RadialGradient(
            tipX,
            barY,
            9f,
            intArrayOf(
                Color.argb(242, 255, 237, 166),
                Color.argb(0, 217, 163, 64)
            ),
            floatArrayOf(0f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(tipX, barY, 9f, orbPaint)
    }

    /**
     * Minimal EGL14 + GLES20 renderer that draws a Bitmap onto a MediaCodec input Surface
     * with exact presentation timestamps via EGLExt.eglPresentationTimeANDROID.
     */
    private class EglBitmapRenderer(
        surface: Surface,
        private val width: Int,
        private val height: Int
    ) {
        private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
        private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
        private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
        private var program = 0
        private var textureId = 0
        private var aPosLoc = 0
        private var aTexLoc = 0
        private var textureInitialized = false

        private val vertexData: FloatBuffer = ByteBuffer
            .allocateDirect(4 * 4 * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                // Fullscreen triangle strip: (x, y, u, v) with v flipped for Android Bitmap top-down
                put(
                    floatArrayOf(
                        -1f, -1f, 0f, 1f,
                         1f, -1f, 1f, 1f,
                        -1f,  1f, 0f, 0f,
                         1f,  1f, 1f, 0f
                    )
                )
                position(0)
            }

        init {
            eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
                throw IllegalStateException("Unable to get EGL14 display")
            }
            val version = IntArray(2)
            if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
                throw IllegalStateException("Unable to initialize EGL14")
            }
            val attribList = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                0x3142, 1, // EGL_RECORDABLE_ANDROID
                EGL14.EGL_NONE
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val numConfigs = IntArray(1)
            if (!EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, configs.size, numConfigs, 0) ||
                numConfigs[0] <= 0 || configs[0] == null
            ) {
                throw IllegalStateException("Unable to choose EGLConfig")
            }
            val contextAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
            eglContext = EGL14.eglCreateContext(eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, contextAttribs, 0)
            val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
            eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, configs[0], surface, surfaceAttribs, 0)

            if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
                throw IllegalStateException("eglMakeCurrent failed")
            }

            setupGlPipeline()
        }

        private fun setupGlPipeline() {
            val vsSrc = """
                attribute vec2 aPos;
                attribute vec2 aTex;
                varying vec2 vTex;
                void main() {
                    gl_Position = vec4(aPos, 0.0, 1.0);
                    vTex = aTex;
                }
            """.trimIndent()
            val fsSrc = """
                precision mediump float;
                varying vec2 vTex;
                uniform sampler2D uTex;
                void main() {
                    gl_FragColor = texture2D(uTex, vTex);
                }
            """.trimIndent()

            val vs = compileShader(GLES20.GL_VERTEX_SHADER, vsSrc)
            val fs = compileShader(GLES20.GL_FRAGMENT_SHADER, fsSrc)
            program = GLES20.glCreateProgram()
            GLES20.glAttachShader(program, vs)
            GLES20.glAttachShader(program, fs)
            GLES20.glLinkProgram(program)
            GLES20.glDeleteShader(vs)
            GLES20.glDeleteShader(fs)

            aPosLoc = GLES20.glGetAttribLocation(program, "aPos")
            aTexLoc = GLES20.glGetAttribLocation(program, "aTex")

            val texIds = IntArray(1)
            GLES20.glGenTextures(1, texIds, 0)
            textureId = texIds[0]
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        }

        private fun compileShader(type: Int, src: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, src)
            GLES20.glCompileShader(shader)
            return shader
        }

        fun drawBitmapFrame(bitmap: Bitmap, ptsNanos: Long) {
            GLES20.glViewport(0, 0, width, height)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

            GLES20.glUseProgram(program)
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
            if (!textureInitialized) {
                GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
                textureInitialized = true
            } else {
                GLUtils.texSubImage2D(GLES20.GL_TEXTURE_2D, 0, 0, 0, bitmap)
            }

            vertexData.position(0)
            GLES20.glEnableVertexAttribArray(aPosLoc)
            GLES20.glVertexAttribPointer(aPosLoc, 2, GLES20.GL_FLOAT, false, 16, vertexData)

            vertexData.position(2)
            GLES20.glEnableVertexAttribArray(aTexLoc)
            GLES20.glVertexAttribPointer(aTexLoc, 2, GLES20.GL_FLOAT, false, 16, vertexData)

            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

            EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, ptsNanos)
            EGL14.eglSwapBuffers(eglDisplay, eglSurface)
        }

        fun release() {
            if (eglDisplay !== EGL14.EGL_NO_DISPLAY) {
                if (textureId != 0) {
                    GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
                    textureId = 0
                }
                if (program != 0) {
                    GLES20.glDeleteProgram(program)
                    program = 0
                }
                EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
                if (eglSurface !== EGL14.EGL_NO_SURFACE) {
                    EGL14.eglDestroySurface(eglDisplay, eglSurface)
                }
                if (eglContext !== EGL14.EGL_NO_CONTEXT) {
                    EGL14.eglDestroyContext(eglDisplay, eglContext)
                }
                EGL14.eglReleaseThread()
                EGL14.eglTerminate(eglDisplay)
            }
            eglDisplay = EGL14.EGL_NO_DISPLAY
            eglContext = EGL14.EGL_NO_CONTEXT
            eglSurface = EGL14.EGL_NO_SURFACE
        }
    }
}
