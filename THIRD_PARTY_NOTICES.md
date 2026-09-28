# 开源许可与致谢

## 融合版本

桌伴将 DockDoor 的部分源码、ScreenEdge 与原启动台组合为一个应用。
此组合版本按 **GNU GPL v3 或更新版本（GPL-3.0-or-later）** 发布，
完整许可见 [LICENSE](LICENSE)。

原启动台代码的 MIT 许可保持有效。原有代码的版权和许可
保留在 [LICENSES/Launch-MIT.txt](LICENSES/Launch-MIT.txt)。
本次新增及修改的集成代码按 GPL-3.0-or-later 提供。

## DockDoor

- 上游：https://github.com/ejbills/DockDoor
- 固定源码提交：48483a7704a2430dceabd9465b65434dfbb3bff0
- 版权：Copyright (C) 2024 ejbills and contributors
- 许可：[GPL-3.0-or-later](LICENSES/DockDoor-GPL-3.0.txt)
- 改编文件：Sources/Launch/Services/DockDoorAccessibility.swift
- 改编来源：DockObserver.swift 的选中 Dock 图标与运行中应用识别，
  AXUIElement.swift / PrivateApis.swift 的窗口 ID 桥接模式。

本次改编增加了 AX 超时、指针位置验证和运行时符号检查，并移除
DockDoor 的 Defaults、窗口缓存及 Dock 修改逻辑。启动台的窗口截图、
预览面板、设置和生命周期管理由本项目实现；无需另外安装 DockDoor。

没有集成 DockDoor Pro、广告、更新器、统计、全局 Alt-Tab 或 Cmd-Tab。
保留 DockDoor 对借鉴 AltTab 的说明：
https://github.com/lwouis/alt-tab-macos/blob/master/src/api-wrappers/AXUIElement.swift
（GPL-3.0）。本次仅使用窗口 ID 桥接，不引入其其他实现。

## ScreenEdge（跨屏边缘）

- 原项目：ScreenEdge（跨屏边缘），原仓库 vincilawyer/ScreenEdge；相关源码现位于本仓库。
- 固定源码提交：7e418d6352b5a839bd01f4b723f54f3f4d5d9e1c（1.5.0 / 7）
- 版权：Copyright (c) 2026 ScreenEdge contributors
- 许可：[MIT](LICENSES/ScreenEdge-MIT.txt)
- 改编文件：Sources/Launch/ScreenEdge/、Sources/ScreenEdgeBridge/、Tests/ScreenEdgeGeometryChecks.swift

保留自动扩展屏、只读通用控制通道、手动标记、三种显示模式、独立外观和锁屏覆盖层。
设置作为桌伴的独立模块；独立应用的登录项及菜单栏由桌伴统一管理。
本机光标读取与五指手势共用；首次启用采用显式开关，不提供旧应用设置导入。
原 MIT 许可及署名保持有效；与 GPL 代码组合后的整合应用遵循上述 GPL 许可。

## 二进制与源码

本项目的安装包应和对应版本的完整源码、此说明及许可证一起交付。
scripts/package-source.sh 生成可独立构建的对应源码 ZIP；
scripts/build-app.sh 将许可证和署名复制到应用资源目录。
本地构建使用 ad-hoc 签名；公开正式二进制发行仍需维护者的
Developer ID 签名和 Apple 公证。
