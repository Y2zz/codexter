import Cocoa

/// Mac 原生适配集中于此；窗口入口只调用，不向 Dart 业务散布环境修补。
enum MacOSIntegration {
  static func prepareEnvironment() {
    let systemPath = "/usr/bin:/bin:/usr/sbin:/sbin"
    let path = ProcessInfo.processInfo.environment["PATH"] ?? systemPath
    var entries = path.components(separatedBy: ":").filter { !$0.isEmpty }
    if entries.isEmpty { entries = systemPath.components(separatedBy: ":") }
    // 只补缺少的目录，保留虚拟环境和用户原有 PATH 优先级。
    for entry in ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin"] {
      if !entries.contains(entry) { entries.append(entry) }
    }
    // 必须早于 FlutterViewController 创建，后续 Dart 子进程才能继承。
    setenv("PATH", entries.joined(separator: ":"), 1)
  }

  static func reopen(_ application: NSApplication, window: NSWindow?) -> Bool {
    guard let window = window else { return false }
    if window.isMiniaturized { window.deminiaturize(nil) }
    window.makeKeyAndOrderFront(nil)
    application.activate(ignoringOtherApps: true)
    return true
  }
}
