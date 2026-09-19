import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var lifecycleChannel: FlutterMethodChannel?
  private var preparingQuit = false

  func registerLifecycleChannel(controller: FlutterViewController) {
    lifecycleChannel = FlutterMethodChannel(
      name: "com.codexter/lifecycle",
      binaryMessenger: controller.engine.binaryMessenger
    )
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // 关闭主窗口只隐藏，由菜单栏/托盘退出；勿在关窗后直接终止进程。
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    lifecycleChannel?.invokeMethod("reopen", arguments: nil)
    return true
  }

  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if preparingQuit {
      return .terminateNow
    }
    guard let channel = lifecycleChannel else {
      return .terminateNow
    }
    preparingQuit = true
    channel.invokeMethod("prepareQuit", arguments: nil) { [weak self] _ in
      DispatchQueue.main.async {
        self?.preparingQuit = false
        NSApp.reply(toApplicationShouldTerminate: true)
      }
    }
    return .terminateLater
  }

  @IBAction func showAboutDialog(_ sender: Any?) {
    lifecycleChannel?.invokeMethod("showAbout", arguments: nil)
  }

  @IBAction func showPreferences(_ sender: Any?) {
    lifecycleChannel?.invokeMethod("showSettings", arguments: nil)
  }

  @IBAction func openConfigDirectory(_ sender: Any?) {
    lifecycleChannel?.invokeMethod("openConfigDirectory", arguments: nil)
  }

  @IBAction func toggleDarkMode(_ sender: Any?) {
    lifecycleChannel?.invokeMethod("toggleDarkMode", arguments: nil)
  }

  @IBAction func openGithub(_ sender: Any?) {
    lifecycleChannel?.invokeMethod("openGithub", arguments: nil)
  }

  @IBAction func checkForUpdates(_ sender: Any?) {
    lifecycleChannel?.invokeMethod("checkForUpdates", arguments: nil)
  }
}
