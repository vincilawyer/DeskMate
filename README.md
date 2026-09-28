# 桌伴 · DeskMate

一个原生 macOS 桌面助手，将应用启动、Dock 窗口预览和跨屏边缘提示放在同一个应用中。
使用 Swift、SwiftUI 与 AppKit 编写，无第三方运行时或额外应用依赖。

## 获取源码

[下载 1.13.2 源码](https://github.com/vincilawyer/DeskMate/releases/latest) · [使用说明](使用说明.md) · [验证范围](docs/validation.md) · [许可与致谢](THIRD_PARTY_NOTICES.md)

当前公开发布提供完整源码与 SHA-256 校验文件，可自行构建。尚未提供经过 Developer ID 签名与 Apple 公证的公开安装包。
此仓库仅收录当前 1.13.2 最终快照，使用一个 `main` 分支和一次初始提交，不包含旧项目的提交、标签或发布记录。

## 三个功能模块

| 模块 | 功能 |
| --- | --- |
| 启动台 | 全屏应用网格、搜索、多页、文件夹、拖动排序、快捷键与触控板手势 |
| Dock 预览 | 悬停查看窗口缩略图、指定窗口切换、最小化恢复、多窗口横向滚动 |
| 跨屏边缘 | 扩展屏与通用控制入口提示、三种显示模式、配色、手动标记及登录后的锁屏提示 |

### 启动台

- 默认使用 `⌥ Space` 显示或隐藏，可在设置中更改或停用。
- 五指收拢打开、张开关闭；启动台内使用精确二指横滑翻页。
- 拖动图标排序、跨页移动、创建文件夹；拖到文件夹可在同一次拖拽中展开并选择落点。
- 统一应用列表管理隐藏与显示；安装或移除应用后自动更新。
- 可从主微信的“**双开**”操作创建或更新独立副本，签名与身份校验后才替换。

### Dock 预览

在“设置 → Dock 预览”启用，再按需授予辅助功能与屏幕录制权限。辅助功能用于读取 Dock 图标和切换窗口，屏幕录制用于窗口缩略图；未授予屏幕录制时仍可显示窗口标题列表。

支持底部、左侧、右侧 Dock 及本机扩展屏。大小设置同步缩放缩略图宽高与面板高度，画面保持原比例。受保护或无法截图的窗口显示占位卡片，图片只在本机内存中使用。

### 跨屏边缘

在“设置 → 跨屏边缘”启用，可选择始终显示、靠近边缘时显示全部、仅鼠标所在本机屏幕显示。
扩展屏与通用控制可分别设置配色与透明度；提示线穿透点击，不接管键鼠。

手动标记与对端示意不代表设备已连接。锁屏提示仅适用于登录后的锁屏，不支持 FileVault 或首次登录界面。

## 通用设置

“通用”统一管理登录启动和菜单栏图标；三个模块在侧栏中并列。
启动台下的“布局、选项、触控板”管理网格、应用列表、打开快捷键和手势说明。
可从设置、应用菜单或 `⌘Q` 退出全部模块，布局和偏好自动保存。

## 构建

需要 macOS 14 或更高版本，以及 Xcode 或 Command Line Tools。本次已验证的工具链为 Swift 6.1 与 macOS SDK 15.4，运行系统为 macOS 26.6.2。
构建脚本会从已安装 SDK 中选择与编译器兼容的版本。默认仅构建 Apple Silicon（arm64）。

```sh
git clone https://github.com/vincilawyer/DeskMate.git
cd DeskMate
./scripts/run-tests.sh
./scripts/package-dmg.sh
./scripts/package-source.sh
```

输出为 `dist/桌伴.app`、`dist/桌伴-1.13.2.dmg` 和 `dist/桌伴-1.13.2-source.zip`。
编译缓存保存在仓库外，可通过 `LAUNCH_BUILD_ROOT` 指定持久目录。
脚本生成本机临时签名的应用；向其他 Mac 正式分发安装包仍需 Developer ID 签名和 Apple 公证。

自行构建后，把 `桌伴.app` 放入“应用程序”文件夹并打开。macOS 提示重新打开以启用权限时，退出后重新打开桌伴。

下载源码附件与 `SHA256SUMS` 后，可在下载目录校验：

```sh
shasum -a 256 -c SHA256SUMS
```

## 兼容性与范围

- 264 项自动检查通过；原生合成预览已验证大小同步缩放、多窗口滚动及卡片点击，详见 [验证记录](docs/validation.md)。
- 全局五指与通用控制查询使用按版本限制的系统私有接口；未验证的系统安全降级，详见 [兼容性说明](docs/compatibility.md)。当前实现不适合 Mac App Store。
- 本机指针离开时抑制启动台手势；双 Mac 通用控制往返、另一端五指、断连重连和真实锁屏仍需对应硬件验收。
- 应用浏览与启动支持键盘；文件夹整理和拖动排序尚无完整的 VoiceOver 或纯键盘等价流程。
- 不修改 Dock 或系统触控板偏好，不请求输入监控权限，不拦截 Mission Control、App Exposé 或 Spaces 手势。

## 许可

融合应用按 [GPL-3.0-or-later](LICENSE) 提供。原启动台、ScreenEdge 的 MIT 版权与许可，以及 DockDoor 的来源署名均保留在 [开源许可与致谢](THIRD_PARTY_NOTICES.md) 和 `LICENSES/` 中。

贡献前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [AGENTS.md](AGENTS.md)；安全问题处理方式见 [SECURITY.md](SECURITY.md)。
