import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var players: [AVAudioPlayer] = []
  private var musicPlayer: AVAudioPlayer?
  // True while the music loop should be audible (startLoop until stopLoop),
  // so it can resume after a call or Siri interrupted the audio session.
  private var musicWanted = false
  private var interruptionObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      self?.handleInterruption(notification)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureAudioChannel(pluginRegistry: engineBridge.pluginRegistry)
  }

  private func configureAudioChannel(pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "NonoGridAudio") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "nono_grid/audio",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "play":
        let args = call.arguments as? [String: Any]
        if let asset = args?["asset"] as? String {
          let volume = (args?["volume"] as? NSNumber)?.floatValue ?? 0.7
          self.playSound(asset: asset, volume: volume)
        }
        result(nil)
      case "startLoop":
        let args = call.arguments as? [String: Any]
        if let asset = args?["asset"] as? String {
          let volume = (args?["volume"] as? NSNumber)?.floatValue ?? 0.4
          self.startLoop(asset: asset, volume: volume)
        }
        result(nil)
      case "stopLoop":
        self.stopLoop()
        result(nil)
      case "disposeAudio":
        self.disposeAudio()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // .ambient respects the silent switch and keeps the user's music playing.
  private func configureAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
    }
  }

  private func playSound(asset: String, volume: Float) {
    configureAudioSession()
    guard let url = assetURL(for: asset) else {
      return
    }

    do {
      players.removeAll { !$0.isPlaying }
      let player = try AVAudioPlayer(contentsOf: url)
      player.volume = volume
      player.prepareToPlay()
      player.play()
      players.append(player)
    } catch {
    }
  }

  private func handleInterruption(_ notification: Notification) {
    guard
      let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw)
    else {
      return
    }
    if type == .ended, musicWanted, let player = musicPlayer, !player.isPlaying {
      configureAudioSession()
      player.play()
    }
  }

  private func startLoop(asset: String, volume: Float) {
    stopLoop()
    configureAudioSession()
    guard let url = assetURL(for: asset) else {
      return
    }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.numberOfLoops = -1
      player.volume = volume
      player.prepareToPlay()
      player.play()
      musicPlayer = player
      musicWanted = true
    } catch {
    }
  }

  private func stopLoop() {
    musicWanted = false
    musicPlayer?.stop()
    musicPlayer = nil
  }

  private func disposeAudio() {
    stopLoop()
    players.forEach { $0.stop() }
    players.removeAll()
  }

  private func assetURL(for asset: String) -> URL? {
    // lookupKey is relative to the main bundle.
    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    return Bundle.main.bundleURL.appendingPathComponent(assetKey)
  }
}
