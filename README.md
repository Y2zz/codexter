# Codexter

给网页版 ChatGPT 使用的本地 MCP 插件服务，让网页端也能安全地调用本地开发工具。

Codexter 将本地项目目录映射为独立的 MCP 地址，并统一提供文件操作、代码搜索、命令执行、Skills、下游 MCP、Cloudflare Tunnel 和调用日志等能力。

![Codexter](docs/screenshot.png)

## 下载与安装

### Windows

前往 **[GitHub Releases](https://github.com/meesii/codexter/releases/latest)** 下载最新版本。

推荐下载：

- `Codexter-x.x.x-Setup.exe`：安装版，推荐普通用户使用。
- `Codexter-x.x.x-windows-x64.zip`：免安装版，解压后直接运行。

当前正式发布以 **Windows x64** 为主，安装版支持应用内检查更新。

> 当前安装包暂未配置 Windows 代码签名。如果 SmartScreen 出现提示，请确认安装包来自本仓库的 GitHub Releases。

### macOS

macOS 可从源码开发运行；CI 会构建 `.app` 压缩包（`Codexter-*-macos-*.zip`），并写入更新清单的 `macos` 字段。应用内可通过「检查更新」下载 zip 并用 Finder 打开。内置 Computer Use 目前仅 Windows。

配置目录：

```text
~/Library/Application Support/codexter-dev   # Debug
~/Library/Application Support/codexter       # Release
```

> 正式分发尚需 Developer ID 签名与公证；未签名包可能被 Gatekeeper 拦截。

## 快速开始

### 1. 准备 Cloudflare

如果需要让网页版 ChatGPT 访问本机 MCP，需要：

- 一个 Cloudflare 账号；
- 一个已接入 Cloudflare 的域名。

Codexter 会在首次启动向导中帮助安装 `cloudflared`、登录 Cloudflare、创建 Tunnel 并配置域名。

### 2. 完成首次启动配置

启动 Codexter，按照向导依次完成：

```text
Cloudflared → 域名 → Tunnel → 完成
```

配置完成后，本地 MCP 服务和 Cloudflare Tunnel 会由 Codexter 统一管理。

### 3. 创建工作区

点击左侧工作区旁的 `+`：

1. 选择本地项目目录；
2. Codexter 自动为工作区生成独立 UUID；
3. 启动工作区；
4. 复制工作区对应的 MCP 地址。

### 4. 添加到 ChatGPT

将 Codexter 显示的 HTTPS MCP 地址添加到支持远程 MCP 的 ChatGPT 中，即可在网页端调用本地工具。

公网地址格式：

```text
https://mcp.example.com/{workspace-uuid}/mcp
```

不同工作区通过 UUID 隔离，共用同一个本地服务和 Cloudflare Tunnel。

## 主要功能

- **多工作区**：每个项目目录对应独立 MCP 地址，由一个 Codexter 实例统一管理。
- **本地开发工具**：内置 `read`、`apply_patch`、`ls`、`grep`、`glob`、`code_explore`、`exec_command`、`write_stdin` 等工具。
- **图片读取**：支持读取本地 PNG、JPEG、GIF、WebP，并自动压缩过大的图片后交给模型。
- **Skills 管理**：支持从 Codex 导入 Skills，也可以手动创建、编辑、启停。
- **下游 MCP**：支持导入或添加其他 MCP Server，并通过 `mcp_tools` / `mcp_call` 统一调用；Windows 上内置可开关的 `Computer Use`，可复用本机 Codex runtime 控制桌面应用。
- **Cloudflare Tunnel**：统一管理公网 HTTPS 入口，无需手动维护 cloudflared 命令。
- **实时日志**：查看工具调用、执行耗时、失败状态和运行中的命令进程。
- **环境检测**：检查 Cloudflared、Tunnel、域名、本地服务、Git 和工作区路径等状态。
- **在线更新**：Windows / macOS 均可通过 `帮助 → 检查更新` 获取更新包（Windows 为 Setup.exe，macOS 为 zip）。

## MCP 地址

默认本地监听地址：

```text
http://127.0.0.1:18920/{workspace-uuid}/mcp
```

公网地址：

```text
https://mcp.example.com/{workspace-uuid}/mcp
```

通常网页版 ChatGPT 使用公网 HTTPS 地址；本地地址主要用于调试和本机客户端。

## 开发运行

需要 Flutter 开发环境。

```bash
flutter pub get
flutter run -d macos    # 或 windows / linux
```

Debug / Release 使用独立配置目录：

| 平台 | Debug | Release |
|------|-------|---------|
| Windows | `%APPDATA%\codexter-dev` | `%APPDATA%\codexter` |
| macOS | `~/Library/Application Support/codexter-dev` | `~/Library/Application Support/codexter` |

两者目录内部结构一致，可以直接复制配置进行开发测试。

### Windows 发布包

```powershell
.\scripts\build_windows.ps1
```

产物输出到 `dist/`：

```text
Codexter-x.x.x-Setup.exe
Codexter-x.x.x-windows-x64.zip
```

### macOS 发布包

```bash
./scripts/build_macos.sh
```

产物：

```text
dist/Codexter-x.x.x-macos-arm64.zip   # 或 macos-x64
```

推送与 `pubspec.yaml` 版本一致的 `v*` Tag 后，GitHub Actions 会自动完成测试、构建并创建 Release。

## 技术栈

- Flutter / Dart
- shadcn_flutter
- Hive
- MCP
- Cloudflare Tunnel / cloudflared
- GitHub Actions / Inno Setup
