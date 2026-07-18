import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, UIContextMenuInteractionDelegate {

  private var activeBookmarks: [String: URL] = [:]

  private weak var flutterView: UIView?
  private var currentMenuActions: [[String: Any]] = []
  private var menuChannel: FlutterMethodChannel?

  private var currentMenuRect: CGRect = .zero
  private var previewImageView: UIImageView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let registrar = self.registrar(forPlugin: "NativeBridge")

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
        let bookmarkData = try? url.bookmarkData(
          options: .minimalBookmark,
          includingResourceValuesForKeys: nil,
          relativeTo: nil)

        if let data = bookmarkData {
          result(data.base64EncodedString())
        } else {
          result(
            FlutterError(code: "CREATE_FAILED", message: "Failed to create bookmark", details: nil))
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

    let menuChannel = FlutterMethodChannel(
      name: "com.afalphy.menu",
      binaryMessenger: registrar!.messenger())
    self.menuChannel = menuChannel

    menuChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }

      switch call.method {
      case "initNativeMenu":
        // Global Initialization: Attach interaction to FlutterView at startup to ensure immediate response on first long press.
        guard
          let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive })
            as? UIWindowScene,
          let window = windowScene.windows.first(where: { $0.isKeyWindow }),
          let rootVC = window.rootViewController,
          let flutterView = rootVC.view
        else { return }

        self.flutterView = flutterView
        flutterView.addInteraction(UIContextMenuInteraction(delegate: self))
        result(nil)
      case "showNativeMenu":
        guard let args = call.arguments as? [String: Any],
          let items = args["items"] as? [[String: Any]]
        else {
          result(
            FlutterError(code: "ARG_ERROR", message: "Invalid menu items payload", details: nil))
          return
        }

        // Sync payload data to memory. The interaction is already attached to FlutterView at startup.
        DispatchQueue.main.async {
          self.currentMenuActions = items

          let x = args["x"] as? CGFloat ?? 0.0
          let y = args["y"] as? CGFloat ?? 0.0
          let width = args["width"] as? CGFloat ?? 100.0
          let height = args["height"] as? CGFloat ?? 100.0
          self.currentMenuRect = CGRect(x: x, y: y, width: width, height: height)

          result(true)
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    configurationForMenuAtLocation location: CGPoint
  ) -> UIContextMenuConfiguration? {
    // Smart Routing: Trigger context menu only if the physical long-press coordinate falls within the active Flutter Widget bounds.
    // If coordinates mismatch or no actions available, return nil to pass gestures back to Flutter.
    guard !self.currentMenuActions.isEmpty, self.currentMenuRect.contains(location) else {
      return nil
    }

    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) {
      [weak self] (suggestedActions) -> UIMenu? in
      guard let self = self else { return UIMenu(title: "", children: []) }

      // Core Logic for Menu Dividers
      var topLevelElements: [UIMenuElement] = []
      var currentGroupActions: [UIAction] = []

      for (index, actionData) in self.currentMenuActions.enumerated() {
        let isDivider = actionData["isDivider"] as? Bool ?? false

        if isDivider {
          // Wrap accumulated actions into an inline flat menu to create a native separator line.
          if !currentGroupActions.isEmpty {
            let groupMenu = UIMenu(
              title: "", options: .displayInline, children: currentGroupActions)
            topLevelElements.append(groupMenu)
            currentGroupActions.removeAll()  // Clear the group array for the next batch.
          }
          continue  // Skip the divider item itself.
        }

        let title = actionData["text"] as? String ?? ""
        var iconImage: UIImage? = nil

        if let iconBytesData = actionData["iconBytes"] as? FlutterStandardTypedData {
          iconImage = UIImage(data: iconBytesData.data)
        }

        let action = UIAction(title: title, image: iconImage, identifier: nil) { [weak self] _ in
          self?.menuChannel?.invokeMethod("onMenuItemSelected", arguments: index)
          // Reset data contexts after execution.
          self?.currentMenuActions = []
          self?.currentMenuRect = .zero
        }
        currentGroupActions.append(action)
      }

      // Add remaining actions after looping through the items array.
      if !currentGroupActions.isEmpty {
        let groupMenu = UIMenu(title: "", options: .displayInline, children: currentGroupActions)
        topLevelElements.append(groupMenu)
      }

      // Return composite menus packed with submenus. iOS renders native thin gray lines between groups automatically.
      return UIMenu(title: "", children: topLevelElements)
    }
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
  ) -> UITargetedPreview? {

    guard let flutterView = self.flutterView,
      self.currentMenuRect != .zero
    else { return nil }

    UIGraphicsBeginImageContextWithOptions(self.currentMenuRect.size, false, UIScreen.main.scale)
    let contextOffset = CGPoint(
      x: -self.currentMenuRect.origin.x, y: -self.currentMenuRect.origin.y)
    flutterView.drawHierarchy(
      in: CGRect(origin: contextOffset, size: flutterView.bounds.size), afterScreenUpdates: false)
    let snapshotImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    let mockView = UIImageView(image: snapshotImage)
    mockView.frame = self.currentMenuRect

    flutterView.addSubview(mockView)
    self.previewImageView = mockView

    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear

    let relativeRect = CGRect(origin: .zero, size: self.currentMenuRect.size)
    parameters.visiblePath = UIBezierPath(roundedRect: relativeRect, cornerRadius: 12)

    let targetCenter = CGPoint(x: self.currentMenuRect.midX, y: self.currentMenuRect.midY)
    let target = UIPreviewTarget(container: flutterView, center: targetCenter)

    return UITargetedPreview(view: mockView, parameters: parameters, target: target)
  }

  func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willEndFor configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionAnimating?
  ) {
    // Zero-Delay Dismissal: Instantly rip the mock view out of the host view tree when the dismissal starts.
    // This breaks the rendering pipe, avoiding lingering artifacts while the system closes out the menu.
    if let preview = self.previewImageView {
      preview.removeFromSuperview()  // Unmount from host FlutterView layout tree.
      self.previewImageView = nil
    }

    self.currentMenuRect = .zero
    self.currentMenuActions = []

  }

}
