# 桌面平台适配边界

## 维护原则

Windows 是主开发平台。共享业务保留一份，Mac 差异独立维护；不为支持 Mac 复制整个 AppState、SetupService、MCP 服务或 UI。比例是减少原文件改动的方向，不通过增加无用代码凑到 90%。

共享业务只导入 `lib/platform/desktop_platform.dart`。该入口按 `Platform.operatingSystem` 选择适配器；不要用 `dart.library.io` 判断 Windows，因为 macOS 也支持 dart:io。构造适配器没有原生副作用，只有选中的实现才执行钩子。此处是运行行为隔离，不是让另一平台的 Dart 源码完全免于编译或静态分析。

## 文件职责

```text
lib/platform/
  desktop_platform.dart          # 唯一的平台选择入口
  desktop_adapter.dart           # 能力枚举、默认关闭和不接管的钩子
  windows/windows_adapter.dart   # 显式启用 Windows 能力，沿用原业务
  macos/macos_adapter.dart        # Mac 能力、窗口和托盘接入
  macos/macos_lifecycle.dart      # Flutter 退出请求、去重和失败处理
  macos/macos_cloudflared.dart    # Mac 架构选择、tgz 安装事务
macos/Runner/MacOSIntegration.swift  # Flutter 启动前补 PATH、Dock 重开
```

布尔异步钩子返回 `false` 表示没有接管，调用方继续原实现。Mac 已开始操作却失败时必须抛错，不能返回 false 后执行 Windows 路径。不要在共享入口导入 Mac/Windows 具体实现目录；边界测试会阻止这种依赖扩散。

CocoaPods 接入、Xcode 文件注册和 entitlements 属于 Mac 原生工程配置，仍需要修改原配置文件，不能为了“全新增”把必要构建配置藏起来。

## Windows 新功能怎么做

纯共享业务仍在原文件开发。涉及系统 API、外部可执行文件或平台插件的新功能，先在 `DesktopFeature` 增加一个能力，再只在 `WindowsAdapter.supports` 的白名单启用。UI 及实际调用入口检查该能力；Mac 白名单没有该项时默认关闭，后续适配不要求改动 Windows 实现。

只有确实需要平台差异时才为 `DesktopAdapter` 增加小接口，提供明确的不支持/不接管默认行为，具体实现放到对应目录。不要把平台层变成新的业务协调中心，也不要在每个共享服务里增加一组 isMacOS 分支。

修改公共接口、共享业务或升级跨平台插件仍可能影响 Mac。文件隔离不能保证 Mac 永不回归，必须保留双平台编译检查。

## 本轮范围

保留的 Mac 能力是源码开发运行、首次 cloudflared 安装、目录选择、托盘、关闭后隐藏、Dock 恢复，以及正常退出时调用现有服务清理。内置 Computer Use 和应用内更新均未在 Mac 开放；菜单、关于对话框共用现有实现。

PATH 在创建 FlutterViewController 之前设置，保留用户原有顺序并追加缺失的 Homebrew 目录；不改命令会话、下游 MCP 和 Tunnel 的进程启动方式。

退出复用 Flutter 生命周期，不新增原生退出通道。失败/超时取消退出；超时不会取消底层 Future，因此重试复用仍在运行的清理任务，避免并发清理。强制结束进程、断电等情况不会可靠触发正常退出回调。本轮未重写原有 Unix 进程树清理，不能承诺任意脱离父进程的孙进程都会退出。

Mac 安装只在私有暂存目录内操作，解压并验证可执行文件后才替换旧程序；下载、解压、校验失败保留旧程序。不执行 xattr、不关闭 Gatekeeper。当前仍依赖固定官方 HTTPS 下载地址及运行探测，尚未新增独立的发行签名/供应链校验机制。

原 Release 工作流、更新清单、Windows 安装器和 Windows Job 实现不变。本轮不提供 Mac 自动发布、自动升级、签名或公证。

## 开发与验证

工程最低 Mac 部署目标为 12.0；使用与 Windows CI 一致的 Flutter 3.44.9、现有依赖锁文件，安装 Xcode 和 CocoaPods 后执行：

```sh
flutter pub get --enforce-lockfile
flutter run -d macos
```

`.github/workflows/desktop-compatibility.yml` 是独立的只读检查，覆盖 PR 和 main 更新。分别在 Windows/macOS 执行锁文件校验、格式、分析、测试与 Release 编译；Mac 另编译 Debug。没有发布凭据，不创建 Release，不改更新清单。未提交/推送的本地修改不会触发远端检查。

Windows 本地可以执行 `flutter test test/platform`，验证平台分流、默认能力、退出回调并发/超时，以及通过回环 HTTP 和真实 tar 验证安装事务。Mac 可执行文件校验测试使用本地脚本夹具；这些测试不等于完整 Mac 应用验收。

合并前应由 Mac CI 验证编译，并在真实 Mac 上验收：首次向导和隧道启动；Finder 启动后命令及下游 MCP 找到 Homebrew；目录选择；托盘和 Dock 恢复；菜单/托盘退出；运行任务时退出后的进程及端口状态。Apple Silicon 与 Intel 的包名分流测试通过不代表两个架构都已完成实机测试。

官方接口参考：

- Dart 条件导入：https://dart.dev/tools/pub/create-packages#conditionally-importing-and-exporting-library-files
- Flutter 退出回调：https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver/didRequestAppExit.html
- Flutter 退出请求：https://api.flutter.dev/flutter/services/ServicesBinding/exitApplication.html
