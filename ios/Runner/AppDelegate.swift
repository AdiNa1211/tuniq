import AVFoundation
import Flutter
import MediaPlayer
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MediaLibraryChannel") {
      MediaLibraryChannel.register(with: registrar)
    }
  }
}

// Reads the Music app library. Phase 1 spike version; moves to its own file in Phase 3.
final class MediaLibraryChannel: NSObject {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "tuniq/ios_media_library", binaryMessenger: registrar.messenger())
    let handler = MediaLibraryChannel()
    channel.setMethodCallHandler(handler.handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorizationStatus":
      result(Self.name(of: MPMediaLibrary.authorizationStatus()))
    case "requestAuthorization":
      MPMediaLibrary.requestAuthorization { status in
        DispatchQueue.main.async { result(Self.name(of: status)) }
      }
    case "openSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    case "artwork":
      guard let args = call.arguments as? [String: Any],
        let idString = args["id"] as? String,
        let id = UInt64(idString)
      else {
        result(nil)
        return
      }
      let size = (args["size"] as? Int) ?? 256
      DispatchQueue.global(qos: .userInitiated).async {
        let data = Self.artwork(id: id, size: size)
        DispatchQueue.main.async { result(data.map { FlutterStandardTypedData(bytes: $0) }) }
      }
    case "querySongs":
      DispatchQueue.global(qos: .userInitiated).async {
        let songs = Self.querySongs()
        DispatchQueue.main.async { result(songs) }
      }
    case "exportSong":
      guard let args = call.arguments as? [String: Any],
        let idString = args["id"] as? String,
        let id = UInt64(idString)
      else {
        result(FlutterError(code: "bad_args", message: "Expected {id: String}", details: nil))
        return
      }
      Self.exportSong(id: id, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func name(of status: MPMediaLibraryAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unknown"
    }
  }

  private static func querySongs() -> [[String: Any]] {
    guard MPMediaLibrary.authorizationStatus() == .authorized else { return [] }
    let items = MPMediaQuery.songs().items ?? []
    return items.map { item in
      var song: [String: Any] = [
        "id": String(item.persistentID),
        "title": item.title ?? "",
        "artist": item.artist ?? "",
        "album": item.albumTitle ?? "",
        "albumId": String(item.albumPersistentID),
        "trackNumber": item.albumTrackNumber,
        "dateAdded": Int(item.dateAdded.timeIntervalSince1970),
        "durationMs": Int(item.playbackDuration * 1000),
        "isCloudItem": item.isCloudItem,
        "hasProtectedAsset": item.hasProtectedAsset,
      ]
      // Cloud-only and DRM items have no local asset URL.
      if let url = item.assetURL { song["assetUrl"] = url.absoluteString }
      return song
    }
  }

  // Renders at 1x into a size×size box so large covers don't bloat memory.
  private static func artwork(id: UInt64, size: Int) -> Data? {
    let query = MPMediaQuery.songs()
    query.addFilterPredicate(
      MPMediaPropertyPredicate(
        value: NSNumber(value: id), forProperty: MPMediaItemPropertyPersistentID))
    let box = CGSize(width: size, height: size)
    guard let image = query.items?.first?.artwork?.image(at: box) else { return nil }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    let scaled = UIGraphicsImageRenderer(size: box, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: box))
    }
    return scaled.jpegData(compressionQuality: 0.85)
  }

  // Fallback path: copy the song to an .m4a in Caches so any player can open it.
  private static func exportSong(id: UInt64, result: @escaping FlutterResult) {
    let query = MPMediaQuery.songs()
    query.addFilterPredicate(
      MPMediaPropertyPredicate(
        value: NSNumber(value: id), forProperty: MPMediaItemPropertyPersistentID))
    guard let url = query.items?.first?.assetURL else {
      result(FlutterError(code: "no_asset", message: "Song has no local asset URL", details: nil))
      return
    }
    guard
      let session = AVAssetExportSession(
        asset: AVURLAsset(url: url), presetName: AVAssetExportPresetAppleM4A)
    else {
      result(FlutterError(code: "export_unsupported", message: "Cannot export this song", details: nil))
      return
    }
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let output = caches.appendingPathComponent("spike_export_\(id).m4a")
    try? FileManager.default.removeItem(at: output)
    session.outputURL = output
    session.outputFileType = .m4a
    session.exportAsynchronously {
      DispatchQueue.main.async {
        if session.status == .completed {
          result(output.path)
        } else {
          result(
            FlutterError(
              code: "export_failed",
              message: session.error?.localizedDescription ?? "status \(session.status.rawValue)",
              details: nil))
        }
      }
    }
  }
}
