# AI maintenance guide

This file applies to the whole repository. Read it before changing DeskMate.

## Product boundaries

DeskMate（桌伴）is a native macOS desktop assistant combining an application
launcher, Dock window previews and display-edge hints, written in Swift, SwiftUI
and AppKit. It has no package dependencies. It supports macOS 14 or later, while
some global trackpad behavior is intentionally limited to explicitly verified
MultitouchSupport versions.

Do not change the user's Dock preferences, restart Dock, rewrite trackpad
preferences, or claim that Launch can consume macOS Mission Control/Spaces
gestures. Do not ask for Input Monitoring. The Carbon shortcut and local touch
handling do not need Accessibility. Optional Dock previews use Accessibility
to read Dock icons and raise windows, and Screen Recording for thumbnails;
request these only from explicit permission buttons after the user enables it.
Never persist or upload window thumbnails.

## Build and verification

Run these from the repository root:

```sh
./scripts/run-tests.sh
./scripts/build-app.sh
./scripts/package-dmg.sh
```

`run-tests.sh` is the required baseline. It builds the app and runs the core,
gesture and menu-bar geometry checks. Some checks need to run outside a
restrictive sandbox because they exercise FSEvents and `iconutil`.

Before a release, also verify the Release build, strict code-signature check,
Info.plist syntax, DMG verification and the manual scenarios listed below.
Never make a real `/Applications` mutation during automated or UI acceptance
tests.

## Architecture map

- `Sources/Launch/Models`: serializable layout, preferences and pure mutation
  state. Keep these types independent of SwiftUI.
- `Sources/Launch/Services/LayoutStore.swift`: the persistence boundary.
- `Sources/Launch/Services/AppScanner.swift`: application discovery and
  localized display-name resolution.
- `Sources/Launch/Controllers/LauncherModel.swift`: main-actor application
  state and the only normal bridge between Views and model mutations.
- `Sources/Launch/Views`: rendering and pointer/keyboard interaction.
- `Sources/Launch/AppDelegate.swift` and `Controllers/LauncherWindowController.swift`:
  process, window, menu-bar item, shortcut and focus lifecycle.
- `Sources/Launch/Services/TrackpadGestureManager.swift`: local touch handling
  plus the version-gated private raw-touch fallback.
- `Sources/Launch/Services/WeChatCompanionRefreshService.swift`: transactional
  creation or replacement of the WeChat companion application.
- `Tests/CoreChecks.swift`, `Tests/GestureChecks.swift` and
  `Tests/MenuBarCoverChecks.swift`: executable regression suites used by the
  project scripts.

## Invariants that must not regress

### Persistence and scanning

- Layout and preferences are one atomic `snapshot.json`; never persist them as
  two independent transactions.
- A failed load must not overwrite a valid or recoverable snapshot with
  defaults.
- An incomplete application scan may merge safe metadata, but must not remove
  applications or folder members from the saved layout.
- Full reconciliation contains each visible installed application at most once.
- Application identity is stable and separate from its localized display name.
  Only real name collisions should invoke the fallback disambiguation rules.

### Layout and drag operations

- Every user drop is one atomic model mutation and one persistence request.
  Do not implement a precise drop as “append, then reorder”.
- A stale target, self-drop, hidden application or missing source is a strict
  no-op. Validate all source and target identities before removing anything.
- `LaunchEntry.id`, `LaunchFolder.id` and application IDs are different
  identities. Preserve entry/folder UUIDs across compaction, reconciliation and
  single-member folder dissolution.
- Pages never exceed `preferences.pageCapacity`. When hiding, uninstalling,
  making a folder or otherwise removing a top-level entry, compact later pages
  forward without changing the existing global order.
- A drag session owns one mouse-down through preview, cross-page movement,
  folder spring-loading and final commit. External state changes cancel and
  quarantine that session until mouse-up; they must not let the same gesture
  create a second session.

### Trackpad and windows

- Page navigation accepts an exact two-finger horizontal sequence. Three or
  more touches block the complete physical sequence until all touches lift.
- A held primary pointer button quarantines touch pagination through all-up, so
  a palm or second finger cannot cancel an icon drag.
- Five-finger open/close is separate from page navigation. Private raw-touch
  code must be version-gated, fail closed and retain a public/local fallback.
  Callback shutdown order and in-flight draining are safety-critical.
- macOS system gestures are observed, not consumed. Keep user-facing guidance
  honest about Mission Control, App Exposé and Spaces conflicts.
- The main Launch panel stays above normal application windows but below Dock.
  The menu-bar cover may cover only the current screen's top inset and must
  never modify or obscure Dock.
- Raw and public global pinch paths must check local pointer visibility and
  local display geometry at recognition and again before queued presentation.
  A Universal Control handoff must never open the launcher on the source Mac.
- Dock previews must stop when disabled, while launcher/settings/menu UI is
  active, on sleep or a Space/display change. Discard stale AX/capture results.
- Settings, sheets, menu tracking, app deactivation and delayed gesture tasks
  must have explicit focus/cancellation behavior. A delayed task must not
  re-open Launch after the user's intent changed.

### WeChat companion transaction

- Source is the current, validated main WeChat bundle. Build the companion in a
  same-volume staging location before touching the installed destination.
- Validate bundle IDs, names, signature and generated icon before commit.
- Do not use shell interpolation, `sudo`, forced termination or in-place edits
  of the main WeChat bundle.
- The existing companion remains usable until the new staged bundle is ready.
  Commit and rollback must never leave two registered `.app` bundles with the
  companion bundle ID. A launch failure restores the prior version.
- Tests use temporary fixture bundles only. Never run the real rebuild action as
  part of automated acceptance testing.

## SwiftUI and concurrency guidance

- `LauncherModel` is main-actor isolated. Keep blocking filesystem, process and
  image work off the main actor, then publish results on the main actor.
- High-frequency pointer, geometry and wiggle state belongs in small reference
  objects or leaf views. Do not make the root grid re-render for every mouse or
  touch sample.
- Use one source of truth for a visible control. Lists that filter or regroup
  after a toggle need stable application IDs and live model-derived bindings.
- Long-press, tap and drag recognition must share one state machine; after drag
  or long-press wins, mouse-up must not launch the application.

## Required manual checks

Use an isolated application-support directory and acceptance build whenever
possible. Verify:

1. Short click, long press, edit exit and drag do not conflict.
2. Same-page/cross-page reorder, app-to-app folder creation, spring-loaded
   folder insertion, folder-member reorder and member drag-out persist once.
3. Hide/unhide under an active search updates the switch and grouping instantly.
4. Exact two-finger slow drag and quick flick both page; vertical, three-finger
   and pointer-drag contacts do not.
5. Five-finger open does not leave App Exposé labels over Launch and never
   reappears after focus loss or an explicit hide.
6. Notched and non-notched screens, visible Dock on every edge, page dots,
   errors and enlarged icons do not overlap.
7. Menu-bar icon/shortcut enable, disable, conflict rollback and restart restore
   the persisted state without a transient default shortcut.
8. WeChat context-menu confirmation can be cancelled safely. Do not confirm the
   real rebuild during UI acceptance.

## Generated and release files

`.build/`, `dist/`, `.DS_Store`, local gesture logs and preview images are not
source. Do not commit them. Release archives are produced by scripts after all
checks pass. The current local build is ad-hoc signed; public binary distribution
requires the maintainer's Developer ID signing and Apple notarization. The
private MultitouchSupport path is not suitable for Mac App Store submission.

## 本项目版本管理与命名

- 当前产品名为“桌伴”，桌面源码项目目录可保留原“启动台项目”名称。Swift target / executable `Launch`、Bundle ID
  `com.vinci.Launch` 与 `~/Library/Application Support/Launch` 保持稳定，避免丢失布局和偏好。
- 每个独立源码修改使用独立任务分支和 Worktree；修改前保存可恢复起点，保留无关修改与暂存安排。
- 按风险完成构建和验证后，用中文提交本任务源码；生成物、真实密钥、用户数据与业务数据库不入库。
- 恢复旧版优先创建恢复分支或 Worktree，不重写共享历史，不丢弃未提交改动。
- GitHub 默认为私有仓库偏好；首次上传仍须确认具体账户、仓库和项目授权。有持续授权后正常推送。
- 交付时简述分支、提交标识、验证结果与远程同步状态；本地提交不称为云端备份。

## 本机构建与验收

- 默认构建 Apple Silicon arm64；交付产物放在桌面项目专属目录。
- 编译缓存与 SwiftPM scratch 由 scripts/build-paths.zsh 放在仓库外；
  可用 LAUNCH_BUILD_ROOT 指定持久目录。清理 worktree 时保留该目录。
- 界面验收使用隔离数据目录；有扩展屏时设置
  LAUNCH_ACCEPTANCE_EXTERNAL_DISPLAY=1，并核实实际窗口位于扩展屏。
  LAUNCH_SHOW_ON_START=1 打开启动器，=settings 直接打开设置，均仅用于隔离验收。
- 此融合版本遵循 GPL-3.0-or-later，保留 LICENSES 下的原始许可和
  THIRD_PARTY_NOTICES.md；应用资源与源码交付必须包含这些文件。

## 跨屏边缘整合

- ScreenEdge 源码固定在 7e418d6352b5a839bd01f4b723f54f3f4d5d9e1c，MIT 署名保留；整合应用按 GPL-3.0-or-later 提供。
- Sources/ScreenEdgeBridge 仅调用基本只读边缘查询；禁止调用通用控制管理接口或改变显示器排列。
- 覆盖层必须穿透点击、不可获取键盘焦点。锁屏空间只允许边缘覆盖层，不能包含启动台、设置或窗口截图。
- 空数据、错误、停用、退出必须清除旧覆盖层及计时器。自动通道、手动标记和对端示意保持明确区分。
- ScreenEdge 的配置使用桌伴偏好域；不提供旧应用设置导入或兼容入口。统一登录项和菜单栏，禁止额外创建旧应用的登录项。
- 单端只读查询和注入光标状态测试不能声称完成两台 Mac 的真实通用控制、手势或两端颜色映射实测。

## 当前产品名称

- 产品显示名称为“桌伴”。内部可执行文件 Launch、Bundle ID com.vinci.Launch 与布局数据目录 Launch 保持稳定。
- 用户要求公开仓库 vincilawyer/DeskMate 仅收录当前 1.13.2 最终快照，一个 main 分支、一次初始提交；不迁入旧仓库历史、分支、标签或发布记录。保留许可证和原作者署名。后续变更须由用户明确要求。
- 构建交付为 dist/桌伴.app、桌伴-版本.dmg 和桌伴-版本-source.zip。不要重新生成用户布局或另建产品仓库。
