import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
  private var audioChannel: FlutterMethodChannel?
  private var systemChannel: FlutterMethodChannel?
  private var videoGenerationCancelled: Bool = false
  private weak var activeVideoExporter: AVAssetExportSession?
  private var audioPlayer: AVAudioPlayer?
  private lazy var speechSynthesizer: AVSpeechSynthesizer = {
    let synth = AVSpeechSynthesizer()
    synth.delegate = self
    return synth
  }()
  private var currentPlaybackId: Int = 0

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MushafAudioChannel") {
      let channel = FlutterMethodChannel(
        name: "com.mushaf.app/audio",
        binaryMessenger: registrar.messenger()
      )
      self.audioChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleAudioMethodCall(call: call, result: result)
      }
    }

    if let sysRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "MushafSystemChannel") {
      let sysChannel = FlutterMethodChannel(
        name: "com.mushaf.app/system",
        binaryMessenger: sysRegistrar.messenger()
      )
      self.systemChannel = sysChannel
      sysChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleSystemMethodCall(call: call, result: result)
      }
    }
  }

  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try session.setActive(true)
    } catch {
      // Fallback to default playback category
      try? session.setCategory(.playback)
      try? session.setActive(true)
    }
  }

  private func stopActivePlayback() {
    if let player = audioPlayer, player.isPlaying {
      player.stop()
    }
    audioPlayer = nil
    if speechSynthesizer.isSpeaking {
      speechSynthesizer.stopSpeaking(at: .immediate)
    }
  }

  private func handleSystemMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "openUrl":
      guard let args = call.arguments as? [String: Any],
            let urlStr = args["url"] as? String,
            let url = URL(string: urlStr) else {
        result(false)
        return
      }
      DispatchQueue.main.async {
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }
      }

    case "scheduleKhatmaReminder":
      guard let args = call.arguments as? [String: Any],
            let title = args["title"] as? String,
            let body = args["body"] as? String else {
        result(false)
        return
      }
      let delaySeconds = max(Double((args["delaySeconds"] as? Int) ?? 86400), 60.0)
      let center = UNUserNotificationCenter.current()
      center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        guard granted else {
          result(false)
          return
        }
        center.removePendingNotificationRequests(
          withIdentifiers: ["khatma_24h_reminder", "khatma_48h_reminder"]
        )

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger24 = UNTimeIntervalNotificationTrigger(
          timeInterval: delaySeconds,
          repeats: false
        )
        let req24 = UNNotificationRequest(
          identifier: "khatma_24h_reminder",
          content: content,
          trigger: trigger24
        )
        center.add(req24, withCompletionHandler: nil)

        let trigger48 = UNTimeIntervalNotificationTrigger(
          timeInterval: delaySeconds + 86400.0,
          repeats: false
        )
        let req48 = UNNotificationRequest(
          identifier: "khatma_48h_reminder",
          content: content,
          trigger: trigger48
        )
        center.add(req48, withCompletionHandler: nil)

        result(true)
      }

    case "cancelKhatmaReminder":
      UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: ["khatma_24h_reminder", "khatma_48h_reminder"]
      )
      result(true)

    case "testKhatmaReminder":
      guard let args = call.arguments as? [String: Any],
            let title = args["title"] as? String,
            let body = args["body"] as? String else {
        result(false)
        return
      }
      let delaySeconds = max(Double((args["delaySeconds"] as? Int) ?? 5), 2.0)
      let center = UNUserNotificationCenter.current()
      center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        guard granted else {
          result(false)
          return
        }
        center.removePendingNotificationRequests(withIdentifiers: ["khatma_test_reminder"])
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
          timeInterval: delaySeconds,
          repeats: false
        )
        let req = UNNotificationRequest(
          identifier: "khatma_test_reminder",
          content: content,
          trigger: trigger
        )
        center.add(req, withCompletionHandler: nil)
        result(true)
      }

    case "shareText":
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String else {
        result(false)
        return
      }
      DispatchQueue.main.async { [weak self] in
        self?.presentShareSheet(items: [text], result: result)
      }

    case "shareImage":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(false)
        return
      }
      let fileUrl = URL(fileURLWithPath: path)
      DispatchQueue.main.async { [weak self] in
        if let image = UIImage(contentsOfFile: path) {
          self?.presentShareSheet(items: [image], result: result)
        } else if FileManager.default.fileExists(atPath: path) {
          self?.presentShareSheet(items: [fileUrl], result: result)
        } else {
          result(false)
        }
      }

    case "createAndShareRecitationVideo":
      guard let args = call.arguments as? [String: Any],
            let imagePath = args["imagePath"] as? String,
            let audioPaths = args["audioPaths"] as? [String],
            !audioPaths.isEmpty else {
        result(false)
        return
      }
      self.videoGenerationCancelled = false
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        self?.buildAndShareRecitationVideo(
          imagePath: imagePath,
          audioPaths: audioPaths,
          result: result
        )
      }

    case "cancelRecitationVideo":
      self.videoGenerationCancelled = true
      self.activeVideoExporter?.cancelExport()
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func reportVideoProgress(_ progress: Double) {
    DispatchQueue.main.async { [weak self] in
      self?.systemChannel?.invokeMethod("onVideoProgress", arguments: ["progress": progress])
    }
  }

  private func buildAndShareRecitationVideo(
    imagePath: String,
    audioPaths: [String],
    result: @escaping FlutterResult
  ) {
    guard let uiImage = UIImage(contentsOfFile: imagePath),
          let cgImage = uiImage.cgImage else {
      DispatchQueue.main.async { result(false) }
      return
    }

    // 1. Concatenate audio files into an AVMutableComposition audio track
    let audioComposition = AVMutableComposition()
    guard let compAudioTrack = audioComposition.addMutableTrack(
      withMediaType: .audio,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      DispatchQueue.main.async { result(false) }
      return
    }

    var cursorTime = CMTime.zero
    for path in audioPaths {
      if self.videoGenerationCancelled {
        DispatchQueue.main.async { result(false) }
        return
      }
      let url = URL(fileURLWithPath: path)
      let asset = AVURLAsset(url: url)
      let tracks = asset.tracks(withMediaType: .audio)
      guard let assetTrack = tracks.first else { continue }
      let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
      do {
        try compAudioTrack.insertTimeRange(timeRange, of: assetTrack, at: cursorTime)
        cursorTime = CMTimeAdd(cursorTime, asset.duration)
      } catch {
        continue
      }
    }

    let totalSeconds = CMTimeGetSeconds(cursorTime)
    guard totalSeconds > 0.2, !self.videoGenerationCancelled else {
      DispatchQueue.main.async { result(false) }
      return
    }

    // 2. Compute hardware-safe even H.264 dimensions (max 720w x 1280h)
    let rawW = Double(cgImage.width)
    let rawH = Double(cgImage.height)
    let scale = min(1.0, min(720.0 / max(rawW, 1.0), 1280.0 / max(rawH, 1.0)))
    let videoWidth = max(320, (Int(rawW * scale) / 2) * 2)
    let videoHeight = max(320, (Int(rawH * scale) / 2) * 2)

    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory
    let ts = Int(Date().timeIntervalSince1970 * 1000)
    let tempVideoOnlyUrl = tempDir.appendingPathComponent("mushaf_vid_track_\(ts).mp4")
    let finalMp4Url = tempDir.appendingPathComponent("Khatma_Mushaf_Recitation_\(ts).mp4")
    try? fm.removeItem(at: tempVideoOnlyUrl)
    try? fm.removeItem(at: finalMp4Url)

    guard let writer = try? AVAssetWriter(outputURL: tempVideoOnlyUrl, fileType: .mp4) else {
      DispatchQueue.main.async { result(false) }
      return
    }

    let compressionProps: [String: Any] = [
      AVVideoAverageBitRateKey: 800_000,
    ]
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: videoWidth,
      AVVideoHeightKey: videoHeight,
      AVVideoCompressionPropertiesKey: compressionProps,
    ]

    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    writerInput.expectsMediaDataInRealTime = false

    let sourceAttrs: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
      kCVPixelBufferWidthKey as String: videoWidth,
      kCVPixelBufferHeightKey as String: videoHeight,
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: writerInput,
      sourcePixelBufferAttributes: sourceAttrs
    )

    guard writer.canAdd(writerInput) else {
      DispatchQueue.main.async { result(false) }
      return
    }
    writer.add(writerInput)
    guard writer.startWriting() else {
      DispatchQueue.main.async { result(false) }
      return
    }
    writer.startSession(atSourceTime: .zero)

    let fps: Int32 = 8
    let totalFrames = max(1, Int(ceil(totalSeconds * Double(fps))))
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var aborted = false

    for frameIdx in 0...totalFrames {
      if self.videoGenerationCancelled || writer.status != .writing {
        aborted = true
        break
      }

      // Wait for hardware encoder readiness with safety timeout and status check
      var waitedMs = 0
      while !writerInput.isReadyForMoreMediaData {
        if self.videoGenerationCancelled || writer.status != .writing || waitedMs >= 3000 {
          aborted = true
          break
        }
        Thread.sleep(forTimeInterval: 0.005)
        waitedMs += 5
      }
      if aborted { break }

      autoreleasepool {
        var pixelBufferOut: CVPixelBuffer?
        guard let pool = adaptor.pixelBufferPool,
              CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBufferOut) == kCVReturnSuccess,
              let pixelBuffer = pixelBufferOut else {
          return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
          let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
          if let ctx = CGContext(
            data: baseAddress,
            width: videoWidth,
            height: videoHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
          ) {
            let rect = CGRect(x: 0, y: 0, width: videoWidth, height: videoHeight)
            ctx.draw(cgImage, in: rect)

            // Lightweight ambient golden light effect + RTL recitation progress thread
            let tSec = Double(frameIdx) / Double(fps)
            let progress = min(1.0, max(0.0, Double(frameIdx) / Double(max(1, totalFrames))))
            let w = CGFloat(videoWidth)
            let h = CGFloat(videoHeight)

            // 1. Soft breathing golden radial shimmer orbiting across the card
            let pulseAlpha = CGFloat(0.07 + 0.055 * (0.5 + 0.5 * sin(tSec * 2.2)))
            let cx = w * CGFloat(0.5 + 0.24 * cos(tSec * 1.15))
            let cy = h * CGFloat(0.52 + 0.18 * sin(tSec * 0.85))
            let colors = [
              UIColor(red: 0.96, green: 0.80, blue: 0.36, alpha: pulseAlpha).cgColor,
              UIColor(red: 0.85, green: 0.64, blue: 0.25, alpha: pulseAlpha * 0.35).cgColor,
              UIColor(red: 0.85, green: 0.64, blue: 0.25, alpha: 0.0).cgColor,
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.45, 1.0]
            if let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
              ctx.drawRadialGradient(
                grad,
                startCenter: CGPoint(x: cx, y: cy),
                startRadius: 2.0,
                endCenter: CGPoint(x: cx, y: cy),
                endRadius: max(w, h) * 0.62,
                options: []
              )
            }

            // 2. RTL golden progress bar with glowing tip along the bottom inner border
            let marginX: CGFloat = 24.0
            let barY: CGFloat = 13.0
            let trackWidth = max(10.0, w - marginX * 2.0)
            let activeWidth = trackWidth * CGFloat(progress)
            let rightX = w - marginX
            let tipX = rightX - activeWidth

            // Subtle background track
            ctx.setFillColor(UIColor(red: 0.85, green: 0.64, blue: 0.25, alpha: 0.18).cgColor)
            ctx.fill(CGRect(x: marginX, y: barY - 1.5, width: trackWidth, height: 3.0))

            // Active RTL golden progress bar
            ctx.setFillColor(UIColor(red: 0.85, green: 0.64, blue: 0.25, alpha: 0.88).cgColor)
            ctx.fill(CGRect(x: tipX, y: barY - 1.5, width: activeWidth, height: 3.0))

            // Glowing light orb at the leading RTL tip
            if let orbGrad = CGGradient(
              colorsSpace: colorSpace,
              colors: [
                UIColor(red: 1.0, green: 0.93, blue: 0.65, alpha: 0.95).cgColor,
                UIColor(red: 0.85, green: 0.64, blue: 0.25, alpha: 0.0).cgColor,
              ] as CFArray,
              locations: [0.0, 1.0]
            ) {
              ctx.drawRadialGradient(
                orbGrad,
                startCenter: CGPoint(x: tipX, y: barY),
                startRadius: 1.0,
                endCenter: CGPoint(x: tipX, y: barY),
                endRadius: 9.0,
                options: []
              )
            }
          }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let presentationTime = CMTimeMake(value: Int64(frameIdx), timescale: fps)
        if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
          aborted = true
        }
      }

      if frameIdx % 4 == 0 || frameIdx == totalFrames {
        let frac = Double(frameIdx) / Double(max(1, totalFrames))
        self.reportVideoProgress(0.72 + frac * 0.20)
      }
    }

    if aborted || self.videoGenerationCancelled {
      writer.cancelWriting()
      try? fm.removeItem(at: tempVideoOnlyUrl)
      DispatchQueue.main.async { result(false) }
      return
    }

    writerInput.markAsFinished()
    let writeSem = DispatchSemaphore(value: 0)
    writer.finishWriting {
      writeSem.signal()
    }
    writeSem.wait()

    if self.videoGenerationCancelled || writer.status != .completed {
      try? fm.removeItem(at: tempVideoOnlyUrl)
      DispatchQueue.main.async { result(false) }
      return
    }

    self.reportVideoProgress(0.94)

    // 3. Mux the rendered video track with the concatenated audio track into finalMp4Url
    let videoAsset = AVURLAsset(url: tempVideoOnlyUrl)
    if let srcVideoTrack = videoAsset.tracks(withMediaType: .video).first,
       let compVideoTrack = audioComposition.addMutableTrack(
         withMediaType: .video,
         preferredTrackID: kCMPersistentTrackID_Invalid
       ) {
      let vDuration = min(videoAsset.duration, cursorTime)
      try? compVideoTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: vDuration),
        of: srcVideoTrack,
        at: .zero
      )
    }

    guard let exporter = AVAssetExportSession(
      asset: audioComposition,
      presetName: AVAssetExportPresetMediumQuality
    ) else {
      try? fm.removeItem(at: tempVideoOnlyUrl)
      DispatchQueue.main.async { result(false) }
      return
    }
    self.activeVideoExporter = exporter
    exporter.outputURL = finalMp4Url
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true

    let exportSem = DispatchSemaphore(value: 0)
    exporter.exportAsynchronously {
      exportSem.signal()
    }
    exportSem.wait()
    self.activeVideoExporter = nil
    try? fm.removeItem(at: tempVideoOnlyUrl)

    guard !self.videoGenerationCancelled,
          exporter.status == .completed,
          fm.fileExists(atPath: finalMp4Url.path) else {
      try? fm.removeItem(at: finalMp4Url)
      DispatchQueue.main.async { result(false) }
      return
    }

    self.reportVideoProgress(1.0)
    DispatchQueue.main.async { [weak self] in
      self?.presentShareSheet(items: [finalMp4Url], result: result)
    }
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    var rootVC: UIViewController?
    for scene in scenes {
      if let keyWin = scene.windows.first(where: { $0.isKeyWindow }) {
        rootVC = keyWin.rootViewController
        break
      }
      if rootVC == nil, let firstWin = scene.windows.first {
        rootVC = firstWin.rootViewController
      }
    }
    var current = rootVC
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }

  private func presentShareSheet(items: [Any], result: @escaping FlutterResult) {
    guard let presenter = topViewController() else {
      result(false)
      return
    }
    let activityVC = UIActivityViewController(
      activityItems: items,
      applicationActivities: nil
    )
    if let popover = activityVC.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 1,
        height: 1
      )
      popover.permittedArrowDirections = []
    }
    presenter.present(activityVC, animated: true) {
      result(true)
    }
  }

  private func handleAudioMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "playFile":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing file path", details: nil))
        return
      }
      let playbackId = (args["playbackId"] as? Int) ?? 0
      stopActivePlayback()
      currentPlaybackId = playbackId
      configureAudioSession()

      let fileUrl = URL(fileURLWithPath: path)
      do {
        let player = try AVAudioPlayer(contentsOf: fileUrl)
        player.delegate = self
        player.prepareToPlay()
        let started = player.play()
        self.audioPlayer = player
        result(started)
      } catch {
        result(FlutterError(code: "PLAY_ERROR", message: error.localizedDescription, details: nil))
      }

    case "speakArabic":
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing text", details: nil))
        return
      }
      let playbackId = (args["playbackId"] as? Int) ?? 0
      let rate = (args["rate"] as? Double) ?? 0.42
      stopActivePlayback()
      currentPlaybackId = playbackId
      configureAudioSession()

      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = AVSpeechSynthesisVoice(language: "ar-SA")
        ?? AVSpeechSynthesisVoice(language: "ar")
      utterance.rate = Float(rate)
      utterance.pitchMultiplier = 1.0
      speechSynthesizer.speak(utterance)
      result(true)

    case "stop":
      stopActivePlayback()
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    let finishedId = currentPlaybackId
    DispatchQueue.main.async { [weak self] in
      self?.audioChannel?.invokeMethod(
        "onPlaybackCompleted",
        arguments: ["playbackId": finishedId, "success": flag]
      )
    }
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    let finishedId = currentPlaybackId
    DispatchQueue.main.async { [weak self] in
      self?.audioChannel?.invokeMethod(
        "onPlaybackCompleted",
        arguments: ["playbackId": finishedId, "success": false]
      )
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    let finishedId = currentPlaybackId
    DispatchQueue.main.async { [weak self] in
      self?.audioChannel?.invokeMethod(
        "onPlaybackCompleted",
        arguments: ["playbackId": finishedId, "success": true]
      )
    }
  }
}
