# Ordo 仓库协作约定

本文件适用于仓库根目录及全部子目录。修改代码前先阅读相关实现和测试；只做当前任务需要的改动，不顺手重构无关代码。

## 项目基线

- 原生 macOS 菜单栏 App，使用 Swift 6 严格并发语义、SwiftUI、AppKit、ApplicationServices 和 CoreGraphics。
- 最低系统版本为 macOS 14，Bundle ID 为 `com.ghost7.Ordo`。
- macOS 26 API 必须使用 `#available(macOS 26.0, *)`；macOS 14–25 保留标准 AppKit/SwiftUI 回退，并尊重“减少动态效果”和“减少透明度”。
- 不引入第三方依赖、网络服务或遥测，除非用户明确扩大范围。
- `LSUIElement` 必须保持启用，App 不显示 Dock 图标。
- App Sandbox 必须保持关闭，Hardened Runtime 必须保持启用。未经明确授权，不修改签名、Bundle ID 或部署目标。
- 用户可见文案、文档和解释性注释使用简体中文；Swift 标识符遵循现有英文命名风格。

## 不可破坏的行为约束

### 权限与输入

- 只申请辅助功能权限。不得新增 Input Monitoring、屏幕录制、Apple Events 或其他权限。
- 系统授权提示只能由用户点击授权入口后触发，不能在启动时主动弹出。
- `CGEventTap` 必须保持 `.listenOnly`，只订阅 `flagsChanged` 和 `mouseMoved`；不得采集普通按键内容，不得吞掉或修改普通系统输入。
- Event Tap 回调只做轻量记录。耗时查询、窗口写入和 UI 更新不得放进 C 回调。
- 保留事件 epoch、暂停/撤权门控和约 60 Hz 鼠标合并；松键前必须交付最后一个鼠标位置，松键后禁止旧事件继续写窗口。

### 窗口控制与并发

- `AXUIElement` 只能保存在 `AXWindowController` actor 内，不跨隔离域暴露或共享。
- UI、`NSScreen` 和手势协调状态保持在 `@MainActor`。不要用宽泛的 `@unchecked Sendable`、`nonisolated(unsafe)` 或 `@preconcurrency` 绕过并发检查；现有事件中继例外必须继续由锁完整保护。
- 捕获目标前检查对应位置、尺寸属性是否可写；AX 失败、超时、窗口消失或权限撤销必须转为可恢复状态，不能崩溃。
- 多步 AX 操作之间保留取消检查。会话取消后不得继续位置或尺寸写入，但必须释放已跟踪的 AX 引用。
- 自动排布保持“尺寸 → 位置 → 尺寸 → 读回验证”的写入顺序，frame 容差为 2 pt。
- 目标窗口在组合键按下时锁定；一次手势中不得随鼠标重新命中其他窗口。
- 只有移动超过 4 pt 才能置前目标 App 和窗口。死区内按下再松开不得改变焦点或窗口。

### 手势与几何

- 默认组合键保持：缩放 `⌥⇧`、排布 `⌘⌃`、移动 `⌃⇧`。组合只能由 `⌘⌥⌃⇧` 构成，至少两个修饰键，三组不可重复。
- 缩放固定窗口左上角并按相对位移改变右下角；移动保持相对位移，不引入起始跳变。
- 径向排布保持 24 pt 进入、16 pt 清除和八个 45° 扇区的角度迟滞；松开任一必要修饰键才提交。
- 排布屏幕在手势开始时锁定，基于 `NSScreen.visibleFrame`；移动和手动缩放允许跨屏。
- AppKit 与 AX/Quartz 坐标转换必须集中在 `ScreenCoordinateConverter`，不要在 UI 或 AX 调用点散落 Y 轴翻转逻辑。
- 布局映射保持：左右半屏、向上最大化可见区、向下 60% 居中、四个斜向对应四角四分之一屏。

## 目录职责

- `Ordo/App`：应用生命周期、全局状态、手势协调和预览窗口。
- `Ordo/Core`：无系统权限依赖的模型、状态机与纯几何计算。
- `Ordo/System`：AX、CGEventTap、屏幕枚举与系统坐标适配。
- `Ordo/UI`：菜单栏、设置、权限引导和预览视图。
- `OrdoTests`：核心单元测试和系统协议的模拟测试。

优先通过 `WindowControlling`、`ScreenGeometryProviding`、`EventSource` 与 `PreviewDisplaying` 注入替身。不要让几何和状态机测试依赖真实辅助功能权限。

工程使用 file-system synchronized groups；在 `Ordo/` 或 `OrdoTests/` 新增源码时通常无需手工修改 `project.pbxproj`，但仍需确认 target membership 和实际构建结果。

## 开发与验证

修改行为前先添加或调整能复现目标的测试，再实现最小改动。以下变化必须配套测试：

- 组合键识别、冲突或持久化规则。
- 会话开始、替换、提交、取消和松键边界。
- 4 pt 激活阈值、24/16 pt 径向死区、扇区边界或迟滞。
- 布局、相对移动/缩放或多屏坐标换算。
- AX 不可写、失效、超时、尺寸夹紧、撤权和事件合并路径。

在仓库根目录运行完整测试：

```bash
xcodebuild test \
  -project Ordo.xcodeproj \
  -scheme Ordo \
  -destination 'platform=macOS' \
  -derivedDataPath "$PWD/build/TestDerivedData"
```

生成项目内 Release App：

```bash
xcodebuild \
  -project Ordo.xcodeproj \
  -scheme Ordo \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$PWD/build/DerivedData" \
  CONFIGURATION_BUILD_DIR="$PWD/build" \
  build
```

交付前按风险执行：

1. 完整单元测试。
2. Debug 和 Release 构建。
3. `codesign --verify --deep --strict build/Ordo.app`。
4. 核对 `LSUIElement=true`，并确认签名 entitlement 中没有 `com.apple.security.app-sandbox`。
5. 涉及真实 AX 行为时，单列 Finder、Safari、Xcode、Chrome/Electron、固定尺寸窗口和多屏人工验收；自动化测试不能替代这一步。

## Git 与产物

- 不提交 `.DS_Store`、`.build/`、`build/`、DerivedData、`.xcresult`、`.dSYM` 或 Xcode 用户状态。
- 不删除、覆盖或格式化无关文件；保留用户已有改动，不擅自 stage 或 commit 任务范围外内容。
- 提交前检查 `git diff --check`、暂存 diff 和 `git status`，确保每一处变化都能追溯到当前任务。

## v1 范围外

除非用户明确要求，不实现原生全屏、跨 Space、Split View、Stage Manager 私有适配、全局 Escape、撤销历史、窗口间隙、自定义布局映射、登录启动、安装包、公证或 App Store 发布。
