# Ordo 仓库协作约定

本文件适用于仓库根目录及全部子目录。修改代码前先阅读相关实现和测试；只做当前任务需要的改动，不顺手重构无关代码。

## 项目基线

- 原生 macOS 菜单栏 App，使用 Swift 6 严格并发语义、SwiftUI、AppKit、ApplicationServices 和 CoreGraphics。
- 最低系统版本为 macOS 14，Bundle ID 为 `com.ghost7.Ordo`。
- macOS 26 API 必须使用 `#available(macOS 26.0, *)`；macOS 14–25 保留标准 AppKit/SwiftUI 回退，并尊重“减少动态效果”和“减少透明度”。
- 不引入第三方依赖、网络服务或遥测，除非用户明确扩大范围。
- `LSUIElement` 必须保持启用，App 不显示 Dock 图标。
- App Sandbox 必须保持关闭，Hardened Runtime 必须保持启用。未经明确授权，不修改签名、Bundle ID 或部署目标。
- App 与测试 target 的 Debug、Release 保持团队 `ND3SVRRF43` 的 `Apple Development` 手动签名；开发证书或私钥不可用时明确失败，不允许回退到临时签名。续期保持同一团队的开发签名，并重新验证权限延续性。
- 用户可见文案、文档和解释性注释使用简体中文；Swift 标识符遵循现有英文命名风格。

## 不可破坏的行为约束

### 权限与输入

- 只申请辅助功能权限。不得新增 Input Monitoring、屏幕录制、Apple Events 或其他权限。
- 系统授权提示只能由用户点击授权入口后触发，不能在启动时主动弹出。
- 窗口手势使用的 `InputEventTap` 必须保持 `.listenOnly`，只订阅 `flagsChanged` 和 `mouseMoved`；不得采集普通按键内容，不得吞掉或修改普通系统输入。
- Event Tap 回调只做轻量记录。耗时查询、窗口写入和 UI 更新不得放进 C 回调。
- 保留事件 epoch、暂停/撤权门控和约 60 Hz 鼠标合并；松键前必须交付最后一个鼠标位置，松键后禁止旧事件继续写窗口。

### 窗口控制与并发

- `AXUIElement` 只能保存在 `AXWindowController` actor 内，不跨隔离域暴露或共享。
- `AXWindowController` 必须继续使用 `MainActor.sharedUnownedExecutor`：同进程 AX 会同步重入 Ordo 自己的 AppKit/SwiftUI，后台 executor 会触发主线程断言。不得只给个别 AX 调用局部切换 executor。
- UI、`NSScreen` 和手势协调状态保持在 `@MainActor`。不要用宽泛的 `@unchecked Sendable`、`nonisolated(unsafe)` 或 `@preconcurrency` 绕过并发检查；现有事件中继例外必须继续由锁完整保护。
- 捕获目标前检查对应位置、尺寸属性是否可写；AX 失败、超时、窗口消失或权限撤销必须转为可恢复状态，不能崩溃。
- 多步 AX 操作之间保留取消检查。会话取消后不得继续位置或尺寸写入，但必须释放已跟踪的 AX 引用。
- 自动排布动画的中间帧使用“尺寸 → 位置”；最终精确提交与立即排布保持“尺寸 → 位置 → 尺寸 → 读回验证”，frame 容差为 2 pt。
- Finder 兼容的唯一 AX 未公开属性例外是 `AXEnhancedUserInterface`：仅当目标应用原值严格为 `true` 时，才可在排布操作期间临时设为 `false`；同一 PID 的重叠操作必须共享租约，成功、错误、取消、撤权和退出路径均 best-effort 恢复原值。属性缺失、不可读或不可写时必须无错误降级，且不得增加应用身份白名单。
- 目标窗口在组合键按下时锁定；一次手势中不得随鼠标重新命中其他窗口。
- 普通窗口手势越过 4 pt 后，只允许对命中窗口执行一次 `AXRaise`。成功后可按可写性设置该窗口的 `AXMain`、`AXFocused`，以 AX 对象身份读回确认目标，再通过隔离的公开旧接口 `SetFrontProcessWithOptions`，使用 `kSetFrontProcessFrontWindowOnly | kSetFrontProcessCausedByUser` 激活单个前窗，使目标获得键盘焦点；前置流程结束后才可写入几何。不得使用普通整 App 激活兜底，不得写入 `AXFrontmost` 或应用级 `AXFocusedWindow`，不得主动重排同 App 的其他窗口。
- 单窗口前置仍受目标 App 与系统兼容性约束：`AXRaise` 返回 `attributeUnsupported`、`actionUnsupported`、`notImplemented` 或 `cannotComplete`，或无法确认目标身份时，不得重试或激活进程，应继续几何操作；权限撤销、窗口失效等硬错误必须终止本次会话并释放引用。前置各步骤之间保留取消、权限检查与同步 AX 后的调度让步；不能将激活接口返回成功等同于真实层级和键盘焦点验收通过。
- 4 pt 作为手势启动、单窗口置前及移动/缩放写入阈值；死区内按下再松开不得改变焦点、层级或窗口几何。

### 手势与几何

- 默认组合键保持：缩放 `⌥⇧`、排布 `⌘⌃`、移动 `⌃⇧`。组合只能由 `⌘⌥⌃⇧` 构成，至少两个修饰键，三组不可重复。
- 缩放固定窗口左上角并按相对位移改变右下角；移动保持相对位移，不引入起始跳变。
- 径向排布保持 24 pt 进入、16 pt 清除和八个 45° 扇区的角度迟滞；松开任一必要修饰键才提交。
- 排布屏幕在手势开始时锁定，基于 `NSScreen.visibleFrame`；移动和手动缩放允许跨屏。
- AppKit 与 AX/Quartz 坐标转换必须集中在 `ScreenCoordinateConverter`，不要在 UI 或 AX 调用点散落 Y 轴翻转逻辑。
- 布局映射保持：左右半屏、向上最大化可见区、向下宽高各 75% 居中、四个斜向对应四角四分之一屏。

### 图标

- 菜单栏图标使用 `MenuBarIconActive`、`MenuBarIconInactive` 两份单色 SVG：八块圆角梯形组成等重外环，中央窗口分别为实心、空心；由 `controller.isOperational` 选择，保留“Ordo 正在运行／Ordo 未运行”的无障碍标签。
- SVG 画布保持 18 × 18 pt，有效外形约 16 pt，中央窗口约 4 pt，未运行态描边 1 pt。外环形状与位置在两态保持一致，背景透明；Asset Catalog 必须同时启用 `template-rendering-intent: template` 和 `preserves-vector-representation: true`，由系统处理深浅及选中着色。
- 主 App 图标继续使用 `Ordo/AppIcon.icon` 中的分层 SVG 与 Icon Composer 配置，保留系统 Liquid Glass。菜单栏图标按小尺寸独立绘制，修改菜单栏资源不应改变主 App 图标。

## 目录职责

- `Ordo/App`：应用生命周期、全局状态、手势协调和预览窗口。
- `Ordo/Core`：无系统权限依赖的模型、状态机与纯几何计算。
- `Ordo/System`：AX、CGEventTap、屏幕枚举与系统坐标适配。
- `Ordo/UI`：菜单栏、设置、权限引导和预览视图。
- `Ordo/Resources/Assets.xcassets`：App 使用的图像资源及模板、矢量保留配置，含菜单栏运行／未运行图标。
- `Ordo/AppIcon.icon`：参与构建的主 App 图标分层资源与 Icon Composer 配置。
- `OrdoTests`：核心单元测试和系统协议的模拟测试。
- `Artwork`：图标设计源文件、候选方案和预览；`Artwork/MenuBarIcon` 保存菜单栏图标 18/36 px 及深浅背景对照，预览不替代运行时资源。
- `scripts`：项目内构建更新、App 生命周期辅助工具及隔离脚本测试。
- `docs`：带日期的验证结果与待验收事项；测试计数、运行 PID 和本机构建路径只作快照记录，不作为长期行为约定。

优先通过 `WindowControlling`、`ScreenGeometryProviding`、`EventSource` 与 `PreviewDisplaying` 注入替身。不要让几何和状态机测试依赖真实辅助功能权限。

工程使用 file-system synchronized groups；在 `Ordo/` 或 `OrdoTests/` 新增源码时通常无需手工修改 `project.pbxproj`，但仍需确认 target membership 和实际构建结果。

用户使用说明见 [README](README.md)，图标源与预览用途见 [Artwork/README](Artwork/README.md)，近期验证结果及已知未通过项见 [docs/VALIDATION](docs/VALIDATION.md)。行为或资源约定变化时同步相关说明，验证快照须注明日期与适用范围。

## 开发与验证

修改行为前先添加或调整能复现目标的测试，再实现最小改动。以下变化必须配套测试：

- 组合键识别、冲突或持久化规则。
- 会话开始、替换、提交、取消和松键边界。
- 4 pt 手势启动阈值、24/16 pt 径向死区、扇区边界或迟滞。
- 布局、相对移动/缩放或多屏坐标换算。
- AX 不可写、失效、超时、尺寸夹紧、撤权和事件合并路径。
- 单窗口前置的目标身份核验、聚焦与激活门控、软失败降级，以及等待前置期间松键、取消和撤权的边界。
- 活动日志容量、顺序、清除、复制格式和不记录输入/窗口身份的边界。

完整测试包含 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`：该用例依赖测试宿主的辅助功能授权、可用桌面及自身测试窗口确实位于命中位置。当前 PID 的 `XCTAssertEqual` 失败不会中断后续置前、移动和缩放，命中外部窗口时仍可能写入其几何。运行前先评估桌面条件；遇到外部 PID 命中失败时保留记录，在评估前不得反复自动重试。缺少权限导致的跳过、捕获错误目标导致的失败必须分别报告，不能计作通过；若显式排除此用例，也必须注明未运行该项真实 AX 验证。

确认上述条件后，在仓库根目录运行完整测试：

```bash
xcodebuild test \
  -project Ordo.xcodeproj \
  -scheme Ordo \
  -destination 'platform=macOS' \
  -derivedDataPath "$PWD/build/TestDerivedData"
```

日常构建、更新并启动项目内 Release App：

```bash
./scripts/dev-update.sh
```

修改更新脚本时运行 `./scripts/tests/dev-update-tests.sh`，验证隔离的故障恢复与并发场景；测试不得操作真实 App 或系统权限。

脚本在 `build/Updates/` 独立构建并验签后，请求固定路径 `build/Ordo.app` 的旧实例正常退出，等待既有清理完成，再归档旧版、替换并通过 Launch Services 启动，核对 PID 和实际执行路径。旧版保留在 `build/Archive/` 下带时间戳的目录，失败候选与日志保留在 `build/Updates/`。构建或验签失败不影响运行中的旧版；退出超时不替换、不强杀。替换或启动失败时尝试安全恢复旧版，无法恢复时报告需处理的路径。

更新脚本禁止并发运行，不自动清理遗留锁；先确认原更新进程已经结束，再将锁目录移走归档。发现其他路径运行的 Ordo 时停止并提示位置，不退出该副本。Xcode Run 使用另一产物路径，运行前先正常退出同 Bundle ID 的其他实例，日常使用保持 `build/Ordo.app` 固定路径。脚本不重复运行完整测试，不重置 TCC，不修改系统权限数据库。

首次从临时签名迁移时，可能需要用户在系统设置中移除旧条目并重新授权一次；随后连续更新两次，实际验证移动、缩放和排布无需重新操作权限条目。构建、签名、启动和真实权限验收分别报告。

仅构建验证时使用独立产物目录，避免覆盖运行中的 App：

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

交付前按风险执行：

1. 完整单元测试。
2. Debug 和 Release 构建。
3. `codesign --verify --deep --strict build/Ordo.app`。
4. 核对 `LSUIElement=true`，并确认签名 entitlement 中没有 `com.apple.security.app-sandbox`。
5. 涉及真实 AX 行为时，单列 Finder、Safari、Xcode、Chrome/Electron、固定尺寸窗口和多屏人工验收；自动化测试不能替代这一步。
6. 涉及菜单栏图标时，检查两态在 18/36 px 下八瓣分离、空心中心可辨、无裁切且尺寸一致；核对构建资源实际载入为 18 × 18 pt、模板属性有效，并验证深浅菜单栏、菜单展开高亮和运行状态切换。模拟预览及资源加载通过不代表实机界面验收通过；自动化无法读取菜单栏项时，明确记录待人工目视验收。

## Git 与产物

- 不提交 `.DS_Store`、`.build/`、`build/`、DerivedData、`.xcresult`、`.dSYM` 或 Xcode 用户状态。
- 不删除、覆盖或格式化无关文件；保留用户已有改动，不擅自 stage 或 commit 任务范围外内容。
- 提交前检查 `git diff --check`、暂存 diff 和 `git status`，确保每一处变化都能追溯到当前任务。

## v1 范围外

除非用户明确要求，不实现原生全屏、跨 Space、Split View、Stage Manager 私有适配、全局 Escape、撤销历史、窗口间隙、自定义布局映射、登录启动、安装包、公证或 App Store 发布。
