import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
  private var audioChannel: FlutterMethodChannel?
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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
