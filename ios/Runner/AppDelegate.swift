import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  // Keep track of active security scopes
  var activeBookmarks: [String: URL] = [:]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // This avoids accessing rootViewController directly during launch
    let registrar = self.registrar(forPlugin: "BookmarkManager")

    let bookmarkChannel = FlutterMethodChannel(
      name: "com.afalphy.bookmark_manager",
      binaryMessenger: registrar!.messenger())

    bookmarkChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }

      switch call.method {
      case "getBookmarkFromPath":
        guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String
        else {
          result(FlutterError(code: "ARG_ERROR", message: "Path is required", details: nil))
          return
        }

        let url = URL(fileURLWithPath: path)
        do {
          let bookmarkData = try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil)
          result(bookmarkData.base64EncodedString())
        } catch {
          result(
            FlutterError(code: "CREATE_FAILED", message: error.localizedDescription, details: nil))
        }

      case "activateAndGetPath":
        guard let args = call.arguments as? [String: Any],
          let bookmarkBase64 = args["bookmark"] as? String,
          let bookmarkData = Data(base64Encoded: bookmarkBase64)
        else {
          result(FlutterError(code: "ARG_ERROR", message: "Invalid data", details: nil))
          return
        }

        var isStale = false
        do {
          let url = try URL(
            resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil,
            bookmarkDataIsStale: &isStale)

          if url.startAccessingSecurityScopedResource() {
            self.activeBookmarks[bookmarkBase64] = url
            result(url.path)
          } else {
            result(FlutterError(code: "DENIED", message: "iOS denied access", details: nil))
          }
        } catch {
          result(
            FlutterError(code: "RESOLVE_FAILED", message: error.localizedDescription, details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
