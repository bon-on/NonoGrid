import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var players: [AVAudioPlayer] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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

  private func disposeAudio() {
    players.forEach { $0.stop() }
    players.removeAll()
  }

  private func assetURL(for asset: String) -> URL? {
    // lookupKey is relative to the main bundle.
    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    return Bundle.main.bundleURL.appendingPathComponent(assetKey)
  }
}
