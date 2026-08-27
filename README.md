# Ordo

Ordo 是一款原生 macOS 菜单栏窗口管理器。它使用修饰键与鼠标移动完成窗口缩放、八向排布和自由移动，不读取普通键盘内容，也不会截断系统输入。

当前版本面向本机开发与使用：没有登录启动、安装包、公证、App Store 发布、网络服务或遥测。

## 功能

| 模式 | 默认组合键 | 操作 |
| --- | --- | --- |
| 调整大小 | `⌥⇧` | 按住组合键并移动鼠标，固定窗口左上角，改变右下角位置 |
| 窗口排布 | `⌘⌃` | 按住组合键向八个方向移动鼠标，预览布局，松开任一必要修饰键后应用 |
| 移动窗口 | `⌃⇧` | 按住组合键并移动鼠标，窗口以相对位移跟随鼠标 |

按下组合键时，Ordo 会锁定鼠标下方的窗口；同一次手势中不会更换目标。移动超过 4 pt 后才会激活、置前窗口并开始写入，因此仅按下再松开不会改变窗口或焦点。

排布手势离起点超过 24 pt 后进入选择，回到 16 pt 内会清除选择。八个方向对应以下布局：

| 方向 | 布局 |
| --- | --- |
| `←` / `→` | 左右半屏 |
| `↑` | 铺满当前屏幕可见区域，不进入原生全屏 Space |
| `↓` | 当前屏幕可见区域宽、高各 60%，居中 |
| `↖` / `↗` / `↘` / `↙` | 对应角落的四分之一屏 |

排布使用手势起点所在屏幕的实时可见区域，自动避开菜单栏、Dock 和刘海。移动与手动缩放可以跨屏。

## 系统要求

- macOS 14 或更高版本
- 包含 macOS 26 SDK 的 Xcode 26 或更高版本（当前使用 Xcode 26.6 验证）
- 辅助功能权限

工程配置关闭了 App Sandbox，并启用 Hardened Runtime。控制其他 App 的窗口依赖 macOS 辅助功能 API，这是预期配置。

macOS 26 或更高版本使用系统 `glassEffect`；macOS 14–25 使用标准 Material 回退。预览和设置界面会尊重“减少动态效果”和“减少透明度”。

## 构建与启动

在项目根目录执行：

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

产物位于 `build/Ordo.app`，启动命令：

```bash
open build/Ordo.app
```

也可以用 Xcode 打开 `Ordo.xcodeproj`，选择 `Ordo` Scheme 和 `My Mac` 后按 `⌘R`。

Ordo 设置了 `LSUIElement`，启动后不会显示 Dock 图标，请从屏幕顶部菜单栏访问它。

## 首次授权

1. 启动 Ordo，打开首次使用引导。
2. 点击“授权辅助功能”。只有这一步会触发系统授权提示。
3. 在“系统设置 → 隐私与安全性 → 辅助功能”中启用 Ordo。
4. 返回 Ordo；应用会自动检查权限并开始监听。

Ordo 只显式申请辅助功能权限，不会单独发起 Input Monitoring、屏幕录制或 Apple Events 授权。菜单栏可用于暂停监听、检查权限、打开设置和退出。

## 快捷键设置

设置页可分别修改三组组合键。每组只能包含 `⌘`、`⌥`、`⌃`、`⇧`，至少选择两个修饰键，且三组不能重复。配置使用 `UserDefaults` 保存在本机。

## 测试

无需辅助功能权限即可运行单元测试：

```bash
xcodebuild test \
  -project Ordo.xcodeproj \
  -scheme Ordo \
  -destination 'platform=macOS' \
  -derivedDataPath "$PWD/build/TestDerivedData"
```

当前 30 个 XCTest 覆盖组合键校验、会话状态、激活死区、八向分类与迟滞、布局与多屏坐标、移动和缩放几何，以及模拟窗口写入失败、取消和松键后的写入边界。真实 AX 权限、Event Tap 和第三方 App 集成仍需人工验收。

## 项目结构

```text
Ordo/
├── App/       应用生命周期、状态协调、手势会话和预览窗口
├── Core/      可测试的手势模型、布局和坐标几何
├── System/    AX 窗口控制、CGEventTap 与屏幕信息
├── UI/        菜单栏、设置、权限引导和排布预览
└── Resources/ Asset Catalog
OrdoTests/     单元测试与系统层模拟测试
```

系统能力通过 `WindowControlling`、`ScreenGeometryProviding` 和 `EventSource` 与核心状态机隔离。AX 元素集中保存在串行 actor 中；鼠标移动事件合并至约 60 Hz。

## 隐私与边界

- 事件监听为 listen-only，只订阅修饰键状态变化和鼠标移动。
- 不采集普通按键内容，不阻断或修改系统输入。
- 不发送网络请求，不包含行为分析或遥测。
- 不支持原生全屏、跨 Space、Split View 或 Stage Manager 私有适配。
- 固定尺寸窗口、原生全屏窗口或拒绝 AX 写入的 App 可能无法管理；Ordo 会安全停止并显示状态。

仓库协作与验证约定见 [`AGENTS.md`](AGENTS.md)。
