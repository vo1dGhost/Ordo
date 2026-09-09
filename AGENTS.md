# Ordo 开发协作指南

适用于本仓库及全部子目录。本文面向修改代码、测试与文档的开发者和自动化代理；用户使用说明见 [README](README.md)。

## 工作方式

1. 使用简体中文交流、编写文档和解释性注释；Swift 标识符沿用英文命名。需要 Python 时优先使用 Conda 环境。
2. 开始前检查 `git status`，阅读相关实现、测试和文档。先核实可查事实；需求有实质歧义时说明假设并澄清。
3. 只实现当前需求，采用最小改动；不顺手重构、引入依赖、添加未要求的功能或格式化无关文件。
4. 保留已有未提交改动。未经授权不删除文件；需要保留旧版时先归档并报告位置，项目外文件操作须谨慎评估。
5. 行为修改先用测试复现目标，再实现并验证。交付说明改动、检查结果及尚未验证的部分，不把尝试操作当成完成。

## 项目导航

| 位置 | 职责 |
| --- | --- |
| `Ordo/App` | 生命周期、全局状态、手势协调、预览窗口 |
| `Ordo/Core` | 无权限依赖的模型、状态机和几何计算 |
| `Ordo/System` | AX 窗口控制、事件监听、屏幕适配和文件日志 |
| `Ordo/UI` | 菜单栏、单栏主窗口、权限引导和排布预览 |
| `Ordo/AppIcon.icon`、`Ordo/Resources/Assets.xcassets` | 构建使用的主图标和菜单栏资源 |
| `OrdoTests` | 单元测试、系统协议替身和隔离文件测试 |
| `scripts` | 本机更新、App 生命周期辅助工具及脚本测试 |
| `Artwork` | 图标设计源、候选和预览；不能替代运行资源 |
| `docs` | 带日期的验证证据、已知限制与待验收事项 |

- 工程使用 file-system synchronized groups；新增源码通常无需编辑 `project.pbxproj`，仍须确认 target membership 和实际构建结果。
- 优先通过 `WindowControlling`、`ScreenGeometryProviding`、`EventSource`、`PreviewDisplaying` 注入替身；核心几何和状态机测试不依赖真实辅助功能权限。
- 使用与对外状态写入 [README](README.md)，资源约定见 [图标说明](Artwork/README.md)，验证结果见 [验证记录](docs/VALIDATION.md)。行为或资源约定改变时同步相应文档；验证记录须注明日期与适用范围，测试计数、PID 和本机构建路径只作快照。

## 技术与签名基线

- 原生 macOS 菜单栏 App：Swift 6 严格并发、SwiftUI、AppKit、ApplicationServices、CoreGraphics；最低 macOS 14，Bundle ID 为 `com.ghost7.Ordo`。
- macOS 26 API 使用 `#available(macOS 26.0, *)`，为 macOS 14–25 保留标准 AppKit/SwiftUI 回退，并尊重减少动态效果与减少透明度。
- 保持 `LSUIElement=true`、无 Dock 图标、App Sandbox 关闭、Hardened Runtime 开启。
- App 与测试 target 的 Debug、Release 均保持团队 `ND3SVRRF43` 的 `Apple Development` 手动签名。证书或私钥不可用时明确失败，不回退到临时签名；续期保持同一团队并重新验证权限延续性。
- 未经明确授权，不改签名、Bundle ID、部署目标，不增加第三方依赖、网络服务或遥测。
- 当前更新工具按维护者团队校验，只服务本机开发；不能当作通用安装、分发签名或公证流程。
- 用户已授权独立的公开分发流程：`scripts/package-release.sh` 仅在该次构建关闭开发证书签名，再对分发副本执行 ad-hoc 签名并保留 Hardened Runtime。此例外不改变 App／测试 target 的开发签名，也不允许本机更新脚本回退。

## 必须保留的行为

### 权限与事件

- 只申请辅助功能权限，不新增 Input Monitoring、屏幕录制、Apple Events 等权限。系统授权提示仅由用户点击授权入口触发。
- 首启与日常控制共用主窗口，沿用 `ordo.onboarding.shown`；不新增权限窗口，不向升级用户重复弹出首启界面。
- `InputEventTap` 保持 `.listenOnly`，仅订阅 `flagsChanged`、`mouseMoved`；不采集普通按键内容，不吞掉或修改输入。
- C 回调仅做轻量记录，耗时查询、窗口写入和 UI 更新在回调外处理。
- 保留事件 epoch、暂停与撤权门控、约 60 Hz 鼠标合并。松键前交付最后位置；松键后禁止旧事件继续写窗口。

### AX 隔离与窗口写入

- `AXUIElement` 仅保存在 `AXWindowController` actor 内，不跨隔离域暴露或共享。
- 整个 `AXWindowController` 保持 `MainActor.sharedUnownedExecutor`：同进程 AX 会同步重入 AppKit/SwiftUI，后台 executor 会触发主线程断言，不能只让个别 AX 调用切回主线程。
- UI、`NSScreen`、手势协调状态保持在 `@MainActor`；不使用宽泛的 `@unchecked Sendable`、`nonisolated(unsafe)`、`@preconcurrency` 绕过检查，已有事件中继例外须完整加锁。
- 捕获前检查位置与尺寸是否可写；AX 失败、超时、窗口消失或撤权须可恢复，不能崩溃。多步操作间检查取消；取消后停止几何写入并释放已跟踪引用。
- 动画中间帧按“尺寸 → 位置”写入；最终精确提交与立即排布按“尺寸 → 位置 → 尺寸 → 读回验证”，frame 容差为 2 pt。
- 唯一允许的 AX 未公开属性例外是 `AXEnhancedUserInterface`：原值严格为 `true` 时，排布期间才可暂设 `false`；同 PID 重叠操作共享租约，在成功、错误、取消、撤权和退出路径尽力恢复。缺失或不可读写时无错误降级，不增加应用身份白名单。

### 单窗口前置

- 按下组合键即锁定目标，一次手势不重新命中其他窗口。4 pt 同时作为手势启动、前置和几何写入阈值；死区内按下再松开不得改变焦点、层级或几何。
- 越过阈值后，仅对目标执行一次 `AXRaise`。成功后按可写性设置 `AXMain`、`AXFocused`，并以 AX 对象身份读回确认目标。
- 身份确认后，通过隔离的公开旧接口 `SetFrontProcessWithOptions`，使用 `kSetFrontProcessFrontWindowOnly | kSetFrontProcessCausedByUser` 激活单前窗；前置流程结束后才可写几何。
- 禁止整 App 激活兜底、写入 `AXFrontmost` 或应用级 `AXFocusedWindow`、主动重排同 App 其他窗口。
- `AXRaise` 返回 `attributeUnsupported`、`actionUnsupported`、`notImplemented`、`cannotComplete`，或无法确认身份时，不重试、不激活进程，继续几何操作；撤权、窗口失效等硬错误则终止并释放引用。
- 前置各步骤间检查取消与权限，同步 AX 后保留调度让步。激活接口返回成功不能代替真实层级与键盘焦点验收。

### 手势与布局

- 默认缩放 `⌥⇧`、排布 `⌘⌃`、移动 `⌃⇧`；组合仅用 `⌘⌥⌃⇧`、至少两个修饰键、三组不重复。
- 缩放固定左上角，按相对位移改变右下角；移动也使用相对位移，不能产生起始跳变。
- 径向选择保留 24 pt 进入、16 pt 清除、八个 45° 扇区的角度迟滞；松开任一必要修饰键才提交。
- 排布屏幕在手势开始时锁定，以 `NSScreen.visibleFrame` 为基准；移动与手动缩放允许跨屏。
- 所有 AppKit 与 AX/Quartz 坐标转换集中到 `ScreenCoordinateConverter`。
- 八向映射固定为：左右半屏、向上铺满可见区、向下宽高各 75% 居中、四个斜向对应四角四分之一屏。

### 主窗口、图标与日志

- 主窗口采用一个纵向滚动区域，按运行、权限、手势、动画排列；默认 560 × 680 pt，最小 520 × 500 pt，不使用分页或侧栏。原生标题栏居中显示“Ordo”，主界面无退出按钮，菜单保持“启用”“打开”“退出”。
- “手势快捷键”标题右侧的“重置”一次恢复并保存三组默认值，不产生中间冲突、不改启用或动画设置；不在界面展示手势规则说明和动画小字，实际校验与减少动态效果行为仍有效。
- 普通成功活动只写日志；异常与快捷键冲突原位提示，界面不提供日志列表或文件入口。
- 菜单栏使用 `MenuBarIconActive` / `MenuBarIconInactive` 单色 SVG，由 `controller.isOperational` 选择；八块圆角梯形外环等重、两态一致，中心分别实心和空心，无障碍标签保持“Ordo 正在运行／Ordo 未运行”。
- 菜单栏画布为 18 × 18 pt，外形约 16 pt，中心约 4 pt，未运行描边 1 pt，背景透明；同时启用 `template-rendering-intent: template` 和 `preserves-vector-representation: true`，由系统着色。
- 主图标继续使用 `Ordo/AppIcon.icon` 分层 SVG 与 Icon Composer 配置，保留系统 Liquid Glass；修改菜单栏图标不改变主图标。
- 文件日志为 `~/Library/Logs/Ordo/ordo.log`，UTF-8、按发生顺序追加；单份最多 2 MiB，最多四份历史 `ordo.1.log` 至 `ordo.4.log`。既有授权仅允许对此固定文件组自动轮替并移除最旧记录，不清理无关文件。
- 日志同步入队、单一后台消费者写入，持有非阻塞排他文件锁；正常退出等待排空、同步、关闭。写入或锁定失败只向系统日志报告一次，不影响手势。
- 日志排除窗口/App 身份、几何和输入内容。XCTest 宿主禁用真实用户目录日志，控制器测试注入替身，文件测试使用隔离目录。

## 构建与验证

以下命令均在仓库根目录运行。仅改文档时检查内容、链接和 diff；涉及行为时先补回归测试，再执行相应构建与测试。

### 测试要求

必须覆盖发生变化的边界：

- 组合键识别、冲突、持久化，以及会话开始、替换、提交、取消和松键。
- 4 pt 启动、24/16 pt 死区、扇区与迟滞，布局、相对移动/缩放和多屏坐标。
- AX 不可写、失效、超时、尺寸夹紧、撤权、事件合并，以及前置身份、聚焦、激活门控、软失败和等待前置期间的松键/取消/撤权。
- 首启主窗口复用、已有用户标记兼容、仅显式点击触发授权。
- 日志格式、顺序、追加、轮替容量、锁定、写入失败、退出排空，以及不记录输入/窗口身份。

**真实 AX 用例需要先评估桌面条件。** `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized` 依赖测试宿主授权、可用桌面和自身测试窗口确实被命中。PID 的 `XCTAssertEqual` 失败不会中断后续操作，可能继续写外部窗口；误命中后保留证据，重新评估前不自动重试。缺权限跳过、误命中失败、显式排除须分别报告，均不能计作通过。

确认条件后运行完整测试：

```bash
xcodebuild test \
  -project Ordo.xcodeproj \
  -scheme Ordo \
  -destination 'platform=macOS' \
  -derivedDataPath "$PWD/build/TestDerivedData"
```

### 仅构建验证

使用独立目录，避免覆盖运行中的 App：

```bash
xcodebuild \
  -project Ordo.xcodeproj \
  -scheme Ordo \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$PWD/build/VerificationDerivedData" \
  CONFIGURATION_BUILD_DIR="$PWD/build/Verification" \
  build
```

功能改动按风险完成完整单元测试及 Debug、Release 构建；对实际待交付产物进行严格验签，并核对 `LSUIElement=true`、Hardened Runtime 和无 `com.apple.security.app-sandbox` entitlement。本机固定路径产物的验签命令为：

```bash
codesign --verify --deep --strict build/Ordo.app
```

### 更新本机开发 App

```bash
./scripts/dev-update.sh
```

- 在 `build/Updates/` 独立构建验签，正常退出旧实例并等待清理，再归档、替换 `build/Ordo.app`，通过 Launch Services 启动，核对 PID 和实际执行路径。
- 旧版保留在 `build/Archive/` 的时间戳目录，失败候选和日志留在 `build/Updates/`。构建/验签失败不影响旧版；退出超时不替换、不强杀；替换/启动失败尝试恢复旧版，恢复失败明确报告路径。
- 禁止并发更新，不自动清除遗留锁；先确认原进程结束，再将锁移走归档。发现其他路径运行的副本时停止并提示位置，不退出该副本。
- Xcode Run 前先正常退出同 Bundle ID 的其他实例；日常使用保持固定路径。更新脚本不重复完整测试、不重置 TCC、不修改权限数据库。
- 从临时签名迁移可能需手动移除旧权限条目并重新授权一次，随后连续更新两次，实际验证移动、缩放和排布无需再次操作权限条目。
- 修改更新脚本后运行 `./scripts/tests/dev-update-tests.sh`，覆盖隔离的故障恢复与并发场景，不操作真实 App 或系统权限。

### 实机验收

- AX 行为单列 Finder、Safari、Xcode、Chrome/Electron、固定尺寸窗口、多屏验收，自动化不能替代。
- 菜单栏图标检查 18/36 px 的八瓣分离、空心中心、无裁切、两态尺寸一致；核对产物资源为 18 × 18 pt 且模板有效，再观察深浅菜单栏、展开高亮和运行状态切换。模拟预览或资源加载不能计作实机通过；无法读取菜单栏项时标记待人工目视验收。
- 构建、签名、启动、真实权限与交互验收分别报告；未运行、跳过、失败和待人工确认保持区分。

### 公开分发

- 用 `./scripts/package-release.sh <Git 提交或标签>` 从已提交源码独立构建 Universal 2 DMG；默认使用 `HEAD`，工作区未提交改动不参与打包。构建、签名和映像验证结果保留在已忽略的独立目录。
- DMG 包含 App、Applications 快捷入口和 MIT 许可证，并附 SHA-256 校验文件；不包含开发证书、私钥、调试材料或本机日志。发布说明必须注明 ad-hoc 签名、未公证及实机验证范围。
- 只推送明确指定的分支与版本标签，不使用 `--all` 或 `--mirror`。公开后不静默替换附件或移动版本标签。
- 安装验收从浏览器下载 Release 附件、检查校验值及下载隔离标记，再按系统流程打开与授权；不得清除隔离标记来代替首次打开验证。卸载、清空用户数据或重置授权须有用户针对该次验证的明确授权，发布脚本不自动执行这些操作。

## 交付与范围

- 不提交 `.DS_Store`、`.build/`、`build/`、DerivedData、`.xcresult`、`.dSYM` 或 Xcode 用户状态。
- 不擅自暂存或提交任务范围外内容。提交前检查 `git diff --check`、暂存 diff 和 `git status`，确保每处变化属于本次任务。
- 文档归档沿用 `build/DocumentArchive/<时间戳>/`，先核对原文件与副本的 SHA-256，再改写；归档仅本机保留，不在公开文档链接它。
- 除非用户明确要求，v1 不扩展原生全屏、跨 Space、Split View、Stage Manager 私有适配、全局 Escape、撤销历史、窗口间隙、自定义布局映射、登录启动、安装包、公证或 App Store 发布。
