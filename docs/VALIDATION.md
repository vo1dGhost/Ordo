# 本机验证记录 · 2026-09-09（1.0.0 发布准备）

本轮将当前单栏主窗口、快捷键重置、本地文件日志及配套文档纳入首发，新增共享 Scheme 和独立 Universal 2 DMG 打包入口。App 与测试 target 的开发签名仍为固定团队的 Apple Development；仅分发副本采用 ad-hoc 签名，不代表 Developer ID 签名或 Apple 公证。

- macOS 26.6.2、Xcode 26.6，在当前 Apple Silicon Mac 执行安全 XCTest：**187 项通过、0 失败、0 跳过**；Debug 构建通过。
- 显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，未将该项真实 AX 操作记为通过；下载后窗口手势另行实机验收。
- 当前源码、main 历史文本及 47 个 PNG 元数据检查未发现凭据或个人绝对路径。提交身份保留维护者明确选择公开的新邮箱，本机归档由 `build/` 忽略规则覆盖。
- 本节记录发布前的源码与测试检查，不代表已完成 Release 下载、全新安装或 Intel／其他 macOS 版本实机验证。

本机证据位于 `build/ReleasePreparation/20260909-185120-703068/`，含工作区及 Git 备份、隐私审计报告、`tests.log`、`Tests.xcresult` 与 `test-summary.json`。备份和证据不随仓库公开。

# 本机验证记录 · 2026-09-09（界面精简与快捷键重置）

菜单文字改为“启用”“打开”“退出”；“手势快捷键”标题右侧新增“重置”，一次恢复并保存缩放 `⌥⇧`、排布 `⌘⌃`、移动 `⌃⇧`。移除手势规则脚注、动画说明与主界面退出按钮，退出仍由菜单栏提供。标题栏采用系统居中工具栏文字项，隐藏重复标题并保留 `NSWindow.title`；标准 Cocoa binding 支持 SwiftUI 后续更新窗口标题。

- 最终安全 XCTest：**187 项通过、0 失败、0 跳过**。新增重置持久化、避免中间冲突/监听重启、保留其他设置、重复重置，以及标题栏配置与重复应用/标题更新测试。明确排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，未运行该项真实 AX 验证。
- 最终 Debug、Release 构建与严格验签通过；保持 Apple Development / `ND3SVRRF43`、`com.ghost7.Ordo`、Hardened Runtime、`LSUIElement=true`、无 App Sandbox。
- 原生界面离屏截图覆盖三种尺寸、7 个状态，共14张顶部/底部截图；重置在标题同行右侧，动画只保留单行，授权态默认窗口可展示全部控制。所有窗口、事件和偏好使用测试替身，没有操作真实用户设置。离屏不能验证真实按钮点击、键盘或 VoiceOver，相关实机交互仍待验收。
- 仅移除工具栏的初版配置未能让本机标题居中，已由原生渲染发现并更正。最终生产代码在 520 / 560 / 780 pt 宽度下，可见标题中心误差均为 **0 pt**；窗口层级、名称和标准窗口按钮保持不变。标题验证没有改动正在运行的 Ordo。

证据目录：`build/InterfacePolishValidation-20260909/`，包含最终 `final-tests.log`、`final-test-summary.json`、`final-release.log`、`final-signature.log`、截图及 `render-report.txt`。最终结果包：`build/TestDerivedData/Logs/Test/Test-Ordo-2026.09.09_12-56-45-+0800.xcresult`。标题几何与截图：`build/NativeTitleValidation-20260909/final.log`、`title-520.png`、`title-560.png`、`title-780.png`。

本轮新版 Release 位于 `build/InterfacePolishValidation-20260909/Products/Ordo.app`。只读运行检查发现用户正在运行上一轮 `build/Verification/Ordo.app`（PID `99017`），因此未覆盖或退出该副本，也未替换固定路径 `build/Ordo.app`。运行检查保存在 `runtime-check.log`；这里只报告新版构建完成，不报告已部署。

# 本机验证记录 · 2026-09-08（main 分支整理）

本轮整理当前窗口管理、主界面、活动日志、图标与开发更新流程，保留既有改动。主界面包含概览、窗口手势和活动日志三页。通用退出等待、权限恢复与监听错误去重测试迁入 `AppControllerLifecycleTests.swift`，断言语义保持一致。

- 安全 XCTest：**164 项通过、0 项失败、0 项跳过**；Debug 构建与 Swift 6 检查通过。
- 显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，未运行该项真实 AX 兼容性验证，未计作跳过或通过。
- 独立 Release 构建通过；Debug、Release 产物均通过严格验签，保持 Apple Development / `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`、`com.ghost7.Ordo` 与无 App Sandbox entitlement。
- 更新脚本 **11 个隔离场景全部通过**，只操作假 App。本轮未替换或启动正式 App。
- 源码拆分相对完整快照逐文件核对，无关源码与资源保持字节一致；`git diff --check` 通过。
- 本轮未执行真实全局窗口手势、权限延续、菜单栏目视、多屏或 macOS 14–25 验收，既有人工验收事项继续适用。

证据目录：`build/ToolsBranchSplit-20260908/`，含 `Snapshot/`、`snapshot-manifest.json`、`main-split-audit.json`、`main-tests.log`、`main-tests.xcresult`、`main-test-summary.json`、`main-release.log`、`main-debug-signature.log`、`main-release-signature.log` 和 `updater-tests.log`。独立产物位于 `MainDebug/` 与 `MainReleaseProducts/`。

---

# 历史验证记录的适用范围

以下记录保留分支拆分前的本机验证历史。测试计数覆盖当时的完整工作区，不能作为当前 `main` 分支的测试计数或验证结论。各历史记录中的运行 PID、部署路径与验收结论仅适用于其对应轮次。

# 本机验证记录 · 2026-09-08（起点标志中央留空）

按用户要求移除起点标志的中央深色窗口及描边、阴影，只保留八瓣外环。40 pt 尺寸、外环路径、玻璃材质、方向高亮、120 ms 过渡与手势生命周期保持原有实现；主 App 图标和菜单栏图标未修改。

- 更新既有渲染测试，检查默认及八方向在 1×／2× 下完整 8 × 8 pt 中心区域透明；旧实现实际断言失败，移除中心图形后通过。原单瓣高亮与几何间隙检查仍通过。
- 最终 `xcresult` 汇总为 **213 项通过、0 项失败、0 项跳过**。继续显式排除已知可能操作外部窗口的 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，该项不在本次 213 项中。
- Debug 随 XCTest 构建通过；Release 经现有更新脚本构建、验签、归档替换并启动。独立严格验签、Apple Development / `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`、无 App Sandbox entitlement 及实际执行路径核验通过。
- 已重新导出并目视检查 [1× 对照图](../Artwork/OriginMarker/opaque-preview-1x.png) 和 2× 预览，中心透明、八瓣独立且方向高亮保留；这些图仅代表减少透明度回退。本轮未重新执行真实全局手势、原生玻璃截图及睡眠唤醒验收。
- 独立只读复核按本轮基线确认改动范围；`git diff --check` 通过，未暂存或提交。旧代码和预览保留于本轮 `Baseline/`，此前验证快照保留在下文。

证据目录为 `build/OriginMarkerOpenCenterValidation-20260908/`，含 `red.log`、`tests.log`、`render.log`、`update.log`、`RenderMarker.swift` 和 `Baseline/`。结果包为 `build/TestDerivedData/Logs/Test/Test-Ordo-2026.09.08_12-32-01-+0800.xcresult`。Release 构建日志位于 `build/Updates/20260908-123322.WacPiC/build.log`；旧版归档为 `build/Archive/20260908-123322.WacPiC/Ordo.app`。更新后 PID `27310`，启动于 2026-09-08 12:33:36，实际路径为 `build/Ordo.app/Contents/MacOS/Ordo`；均为本轮快照。

# 本机验证记录 · 2026-09-08（八瓣玻璃起点标志）

排布起点标志更新为 40 × 40 pt 的冰蓝八瓣玻璃环，中央窗口 8 pt；选中方向使用青蓝高亮和加强描边，回到清除区后恢复等亮。方向变化沿用现有布局选择结果与迟滞，使用 120 ms 明暗过渡；系统减少动态效果时即时更新，减少透明度时使用不透明回退。

## 本轮结果与边界

| 检查 | 结果与边界 |
| --- | --- |
| 旧实现复现 | 尺寸用例 1 项、方向与下一次手势清理用例 2 项实际断言失败；不是编译失败。首次沙箱执行无法访问签名证书，随后保持现有签名配置在可访问钥匙串的环境运行 |
| 最终安全单元测试 | 213 项通过、0 项失败；本轮新增 12 项，覆盖八向绘制、阈值和迟滞到标志的同步、宿主复用、清除与重建、1×／2× 边缘和单瓣高亮；此前 28／40 pt 不一致用例现已通过 |
| 真实 AX 用例 | 显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，未计作通过，也未自动重试其桌面操作 |
| 原生材质观察 | 通过 Computer Use 查看生产绘制代码的独立原生宿主窗口，检查默认与八方向、浅色／深色／复杂背景、减少透明度及放大外观；八瓣分离、中央窗口和方向高亮可辨。该窗口未使用实际全局手势或操作其他 App |
| 1×／2× 渲染 | 不透明回退的 40／80 px 导出与像素测试通过，画布边缘透明且只改变选中一瓣；[对照图](../Artwork/OriginMarker/opaque-preview-2x.png) 标明其适用外观 |
| Debug / Release | Debug 随最终 XCTest 构建通过；Release 通过现有更新脚本独立构建、验签、归档替换与启动 |
| 签名与配置 | 严格验签通过；Apple Development / `ND3SVRRF43`，Hardened Runtime 开启，`LSUIElement=true`，无 App Sandbox entitlement；本机 arm64 产物 |
| 实机待验收 | 正式 App 在不同应用窗口上的按住组合键、连续换向、松键与合盖唤醒效果，以及权限延续性仍待人工确认；macOS 14–25 的 Material 回退已按 availability 隔离，但本机没有旧系统运行验收 |

本机 `ImageRenderer` 在导出玻璃材质时出现额外圆形背景，`NSHostingView.cacheDisplay` 也未正确捕获全部绘制内容；这些导出不能代表原生运行效果。异常候选保留在本轮 `build/` 验证目录，正式 `Artwork/OriginMarker/` 仅保存可复核的不透明回退。原生玻璃外观另由本任务中的 Computer Use 截图核验。

本轮保留工作区已有及同时进行的编辑，包括向下排布 75% 的实现和文案；本次生产改动集中在标志绘制及预览控制器状态同步，没有调整布局比例、输入权限、主图标或菜单栏资源。最终套件与 Release 均覆盖更新时的整个工作区。`git diff --check` 通过，未暂存或提交。

## 本轮证据位置

- 改动前文件副本、红测试及初步验证：`build/OriginMarkerValidation-20260908/Baseline/`、`red-size-authorized.log`、`red-state.log`、`focused-tests.log`、`tests.log`。
- 最终测试：`build/OriginMarkerValidation-20260908/final-tests.log`；结果包为 `build/TestDerivedData/Logs/Test/Test-Ordo-2026.09.08_12-15-11-+0800.xcresult`。
- 原生外观验证与导出程序：`build/OriginMarkerValidation-20260908/RenderMarker.swift`；该程序编译时直接使用生产 `SnapPreviewView.swift` 与核心类型，未申请隐私权限，验证进程已结束。
- 更新日志：`build/OriginMarkerValidation-20260908/update.log`；Release 构建日志为 `build/Updates/20260908-121612.w09t6z/build.log`。
- 更新后运行快照：PID `25436`，启动于 2026-09-08 12:16:27，`ps` 与 `lsof` 核对实际执行路径为 `build/Ordo.app/Contents/MacOS/Ordo`。
- 旧版归档：`build/Archive/20260908-121612.w09t6z/Ordo.app`。

# 本机验证记录 · 2026-09-08（向下排布 75%）

向下排布改为手势起点所在屏幕可见区域的宽、高各 75%，保持居中。预览与最终提交共用同一布局计算；同步预览无障碍文案、活动日志、README 和仓库约定。

- 回归验证：先将八向布局测试的向下预期改为 75%；旧实现实际触发 4 处几何断言失败，修改后布局与坐标测试 5 项全部通过。
- 单元测试套件：运行 201 项，200 项通过、1 项失败。失败项为 `PreviewPanelControllerTests.testOriginMarkerUsesUnclampedConvertedPointAndExpectedPanelConfiguration`，当前起点标记为 28 × 28 pt，既有测试仍预期 40 × 40 pt；本轮没有修改起点标记尺寸或该测试，未将整套测试记为通过。
- 显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，原因是其命中外部窗口后仍可能继续写入几何；本轮未运行该真实 AX 用例。
- Debug 随 XCTest 构建通过；Release 经 `scripts/dev-update.sh` 构建、验签、归档替换与启动检查通过。最终 `build/Ordo.app` 严格验签和配置核验通过，保持 Apple Development / `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`，无 App Sandbox entitlement。
- 本机运行快照：PID `23755`，启动于 2026-09-08 11:59:01，路径为 `build/Ordo.app/Contents/MacOS/Ordo`。Finder、Safari、Xcode、Chrome/Electron、固定尺寸窗口及多屏的真实手势效果与权限延续性未重新验收。

本轮证据：`build/BottomLayout75Validation-20260908.2HOahG/` 内的 `red.log`、`tests.log`、`update.log` 和 `Baseline/`；完整测试结果包为 `build/TestDerivedData/Logs/Test/Test-Ordo-2026.09.08_11-57-28-+0800.xcresult`。Release 构建日志位于 `build/Updates/20260908-115848.m7VFdf/build.log`，旧版保留于 `build/Archive/20260908-115848.m7VFdf/Ordo.app`。

# 本机验证记录 · 2026-09-08（二次修复）

用户确认首次修复仍有如下问题：“从菜单栏打开 → 关闭主窗口 → 点击其他 App → 再从菜单栏打开”，Ordo 会出现在其他 App 窗口下方。上一轮的重复打开测试将 Ordo 始终设为 active，未覆盖切换 App 后激活未获批准的情况；其 198 项通过不能证明该真实问题已解决。

## 本次修复与验证

- 在主窗口的 `makeKeyAndOrderFront` 之后，按本次显式打开请求调用一次 `orderFrontRegardless()`，随后请求应用激活；每步之间继续检查取消、窗口身份和展示阶段。
- 一次性排序保持窗口的普通层级，不修改 `level`，不在后续无关激活时反复执行。该接口不负责键盘焦点，焦点仍由激活及其收尾流程处理。[Apple 官方说明](https://developer.apple.com/documentation/appkit/nswindow/orderfrontregardless%28%29)
- 按用户四步流程加入模拟测试，区分“窗口可见”和“跨 App 前置”。在 Ordo inactive 且激活请求未获批准的条件下，旧代码在前置断言实际失败；修复后通过。测试不显示真实窗口或操作其他 App。

| 检查 | 结果与边界 |
| --- | --- |
| 新复现测试验证旧版 | 1 项运行失败，失败点为窗口已可见却未前置；并非编译失败 |
| 修复后单元测试 | 201 项通过、0 项失败，包含 23 项主窗口测试 |
| 重新激活后的非置顶边界 | 测试改为真实 active 状态后单独复验通过，后续激活不额外排序主窗口 |
| 真实 AX 用例 | 继续显式排除已知可能误操作外部窗口的 1 项用例；未将其计作通过 |
| Debug / Release | Debug 随测试构建通过；Release 构建、严格验签、更新及启动检查通过 |
| 签名与运行配置 | Apple Development / `ND3SVRRF43`，Hardened Runtime 开启，`LSUIElement=true`，无 App Sandbox entitlement |
| 独立复核 | 实际生产变更仅为前置调用、取消检查及解释性注释；未发现阻断问题，`git diff --check` 通过 |
| 实机四步流程 | 已请用户在新版本上复验，当前等待结果；菜单栏自动读取超时，Finder 的窗口级读取成功但不足以完成该流程 |

## 本轮证据位置

- 红测试：`build/MainWindowReopenValidation-20260908/red.log`。
- 全套安全单元测试：`build/MainWindowReopenValidation-20260908/tests.log`；结果包：`build/TestDerivedData/Logs/Test/Test-Ordo-2026.09.08_00-28-44-+0800.xcresult`。
- 后续激活边界复验：`build/MainWindowReopenValidation-20260908/switching.log`。
- Release 构建：`build/Updates/20260908-003113.PuoROd/build.log`；更新日志：`build/MainWindowReopenValidation-20260908/update.log`。
- 更新后实际运行路径：`build/Ordo.app/Contents/MacOS/Ordo`，PID `8849`，启动时间 2026-09-08 00:31:35；均为本轮快照。
- 旧版归档：`build/Archive/20260908-003113.PuoROd/Ordo.app`；本轮改动前文件备份：`build/MainWindowReopenValidation-20260908/Baseline/`。

# 本机验证记录 · 2026-09-08（首次修复）

本轮修复菜单栏“打开 Ordo…”有时未前置主窗口的问题。以下结果仅覆盖本轮代码和本机 arm64 环境，既有手势、图标与权限验收记录保留在后文。

## 改动与验证

- 菜单动作在主 RunLoop 默认模式执行；主窗口注册后显式恢复最小化、请求前置和应用激活，激活完成后只补做本次请求的前置。
- 通过弱引用识别主窗口，视图脱离时按对象身份注销；支持同一窗口关闭后复用及 SwiftUI 延迟创建替代窗口。
- 激活补做限定在开始打开后的 2 秒内；关闭、应用失去激活或退出会取消已开始的请求。菜单收尾阶段失去激活或等待较长时间不会丢弃排队的打开动作。
- 主窗口保持普通层级，未引入悬浮窗口、额外权限、Dock 图标或其他 App 的激活流程变更。

| 检查 | 结果与边界 |
| --- | --- |
| 主窗口展示回归 | 20 项通过；使用替身窗口和确定性队列，不激活 App 或显示真实测试窗口 |
| 单元测试套件 | 198 项通过、0 项失败；显式排除下述 1 项真实 AX 用例，不能记为完整真实 AX 验证通过 |
| Debug 构建 | 随 XCTest 编译与运行通过，Swift 6 严格并发检查通过 |
| Release 构建与部署 | `scripts/dev-update.sh` 构建、验签、正常退出旧版、归档替换与启动检查通过 |
| 最终产物签名与配置 | 严格验签通过；Apple Development / `ND3SVRRF43`，Hardened Runtime 开启，`LSUIElement=true`，无 App Sandbox entitlement |
| 独立静态复核及 diff 检查 | 未发现阻止交付的新缺陷；`git diff --check` 通过 |
| 真实菜单点击与焦点 | Computer Use 读取固定路径的新旧 App 均超时，尚未完成实机验收 |

排除的用例是 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`：它在命中外部 PID 后仍可能继续写入窗口几何，详见 2026-09-05 的失败记录。本轮不修改该测试，也没有自动重试其桌面操作。辅助功能权限延续性和真实窗口手势未重新验收。

实机待验收：其他 App 在前台时，从菜单栏首次打开、重复打开被遮挡的主窗口、关闭后重开、最小化后重开；确认窗口在普通窗口前方且能获得键盘焦点，随后切换其他 App 不会再次抢回焦点。多屏、Space 与系统浮动面板场景仍需单列确认。

## 本轮证据位置

- 环境：Xcode 26.6（17F113）、macOS 26.6.2（25G83），本机 arm64。
- 测试日志：`build/MainWindowPresentationValidation-20260908/tests.log`；结果包：`build/TestDerivedData/Logs/Test/Test-Ordo-2026.09.08_00-18-07-+0800.xcresult`。
- Release 构建：`build/Updates/20260908-001924.PTtcFg/build.log`；更新日志：`build/MainWindowPresentationValidation-20260908/update.log`。
- 当前运行路径：`build/Ordo.app/Contents/MacOS/Ordo`，更新后核验 PID `7457`，启动时间为 2026-09-08 00:19:43；仅作本轮快照。
- 旧版归档：`build/Archive/20260908-001924.PTtcFg/Ordo.app`。改动前相关文件备份位于 `build/MainWindowPresentationValidation-20260908/Baseline/`。
- 沙箱内独立验签返回 `CSSMERR_TP_NOT_TRUSTED`；在可访问系统信任服务的环境重新执行严格验签通过，与更新器验证一致。

# 本机验证记录 · 2026-09-05

本记录覆盖稳定签名、一键更新和八向菜单栏图标两轮改动，依据当日保存的构建日志、测试结果和资源检查。结果是该时点的快照；后续改动需要重新验证。本次文档同步没有重新运行测试、构建或部署。

## 环境与交付

- 验证环境：Xcode 26.6（17F113）、macOS 26.6.2（25G83），本机 arm64。
- App 目标保持 macOS 14、Bundle ID `com.ghost7.Ordo`、`LSUIElement=true`、Hardened Runtime 开启、App Sandbox 关闭。
- App 与测试 target 的 Debug/Release 均采用团队 `ND3SVRRF43` 的 Apple Development 手动签名。
- 当日核验的有效开发证书到期时间为 2027-07-28；后续构建仍以钥匙串实际有效身份为准。
- 最新图标版本通过 `scripts/dev-update.sh` 更新到 `build/Ordo.app`。脚本已确认新进程及实际执行路径，旧版归档在 `build/Archive/20260905-093124.v98FHV/Ordo.app`。

## 已完成的检查

| 项目 | 结果与适用范围 |
| --- | --- |
| 稳定签名改造后的完整 XCTest | 180 项通过，0 项失败，1 项真实 AX 测试因未授权跳过 |
| 更新脚本隔离场景 | 11 项通过；使用假 App 和替身命令验证，不操作真实权限或进程 |
| 菜单栏图标改动后的完整 XCTest | 180 项通过，1 项真实 AX 窗口测试失败，0 项跳过；本轮完整套件未通过 |
| Debug/Release 构建 | 图标资源随两种配置成功编译；当前交付只验证本机 arm64，不代表 Universal 2 或发行构建 |
| 签名验证 | Release 严格签名验证通过；更新器接受开发证书版本、拒绝归档的旧临时签名版本 |
| 前后构建身份 | 稳定签名改造时，内容不同的 Debug/Release 产物具有相同 designated requirement，双向身份验证通过 |
| 菜单栏原生资源 | 两资源从真实 Debug/Release Bundle 加载均为 18 × 18 pt，`isTemplate=true`，保留 SVG 矢量表示 |
| 菜单栏像素检查 | 18/36 px 均八瓣分离、外环逐像素一致、中心实心/空心不同、边缘透明 |
| Release 更新与启动 | 两轮更新均通过正常退出、归档替换和新 PID/执行路径检查；不等同于真实手势验收 |

更新脚本的 11 个隔离场景分别为：构建失败、完整签名拒绝、签名身份拒绝、正常更新、退出超时、其他路径实例拒绝、替换失败恢复、启动失败恢复、候选退出失败、旧版原先未运行、并发拒绝。

## 未通过的真实 AX 测试

失败项：`AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized()`。

测试在创建自身窗口后，通过屏幕坐标捕获目标；返回 PID 为 `74332`，预期测试宿主 PID 为 `25424`，触发 `XCTAssertEqual` 失败。此次权限检查和窗口捕获均已成功，不是因未授权而跳过。

窗口遮挡或并行测试的桌面干扰是候选原因，现有证据不足以确定具体遮挡窗口。菜单栏改动没有涉及捕获逻辑。该测试的现有 PID 断言失败后仍会继续执行置前及几何写入，可能操作误命中的外部窗口；此问题尚未修复。

保留失败记录，不将其解释为通过，也没有反复自动重跑。后续复验应先评估目标身份失配后继续写入的问题，并确保桌面条件受控；需要重跑时优先串行执行该目标测试。仅一次复验通过不能证明已经消除了桌面干扰。

## 待实机验收

- 稳定签名首次迁移可能需要用户重新授权一次；授权后连续两次修改、更新，确认移动、缩放和排布无需重建权限条目。当前没有足够的人工交互证据将权限延续性判为已验收。
- 菜单栏及系统菜单栏的自动化读取超时。真实菜单展开高亮、运行/暂停状态切换、深浅背景下显示和 VoiceOver 标签仍需实机确认。
- Finder、Safari、Xcode、Chrome/Electron、固定尺寸窗口和多屏真实行为仍按 [README](../README.md) 与 [AGENTS](../AGENTS.md) 中的场景验收；单元测试不能替代这些结果。

[菜单栏对照图](../Artwork/MenuBarIcon/preview.png) 来自实际编译资源的模拟渲染，不是系统菜单栏截图。

## 当日本机证据位置

以下路径相对仓库根目录，均为被 Git 忽略的本机构建产物，不随文档提交；目录归档或清理后可能不再存在。

- 稳定签名测试：`build/UpdaterVerification/tests.log`；结果包 `build/TestDerivedData/Logs/Test/Test-Ordo-2026.09.05_08-18-09-+0800.xcresult`。
- 更新脚本隔离测试：`build/UpdaterTests.qIDvmD/`。
- 图标完整测试：`build/MenuBarIconValidation/tests.log`；结果包 `build/TestDerivedData/Logs/Test/Test-Ordo-2026.09.05_09-28-07-+0800.xcresult`。
- 最新 Release 构建：`build/Updates/20260905-093124.v98FHV/build.log`；更新过程：`build/MenuBarIconValidation/update.log`。
- 图标原生检查辅助程序：`build/MenuBarIconValidation/validate.swift` 与同目录 `validate`，属于当次验证产物，不是仓库长期维护的测试入口。

日常构建和测试入口见 [README](../README.md)，资产维护见 [Artwork/README](../Artwork/README.md)。
# 2026-09-09：单栏主界面与后台文件日志

当前 `main` 工作树将运行、权限、三组手势、动画和退出集中到一个纵向滚动窗口，首启复用主窗口；移除日志界面，改为 UTF-8 本地文件日志和固定文件组轮替。默认窗口 560 × 680 pt，最小 520 × 500 pt。窗口手势、AX 和菜单栏图标资源未改变。

## 自动验证

- 安全测试集 **182 项通过、0 失败、0 跳过**。明确排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，未运行该项真实 AX 操作验证；其目标 PID 断言失败后仍可能写入外部窗口，本次不使用它验收界面重排。
- 覆盖首启仅请求一次主窗口、已有用户标记兼容、仅显式授权发起提示、错误去重及恢复、暂停/未授权时修正快捷键冲突、退出同时等待 AX 清理和日志完成。新红测复现了退出期间权限刷新重新开启监听，增加退出门控后通过。
- 文件测试覆盖中文单行格式、顺序排空、跨启动追加、容量与单条超限、四份轮替、无关文件保留、锁竞争、不可写与轮替失败、一次报错停写、重复结束及结束后忽略记录。文件测试保留在本次证据目录的 `FileLogTests/` 中。
- XCTest 默认工厂确认使用静默日志；整套测试前后，真实 `~/Library/Logs/Ordo` 均不存在，测试宿主未创建用户日志目录。
- Debug（测试构建）及独立 Release 构建通过；两者严格签名验证通过。Release 核对 `com.ghost7.Ordo`、团队 `ND3SVRRF43`、Apple Development 签名、Hardened Runtime、`LSUIElement=true`，无 App Sandbox entitlement。受限环境不能访问私钥/信任服务，构建和验签在正常授权环境完成，未回退签名。

测试结果包：`build/TestDerivedData/Logs/Test/Test-Ordo-2026.09.09_12-28-03-+0800.xcresult`。独立 Release 产物：`build/Verification/Ordo.app`。证据目录：`build/SingleInterfaceValidation-20260909/`，包括 `red-authorized.log`、`focused-tests.log`（退出门控红测）、`tests.log`、`test-summary.json`、`release.log`、`signature.log` 和 `update.log`。

## 原生界面渲染与验收边界

使用项目内 Swift/AppKit 渲染程序、系统协议替身和静默日志，生成 7 组状态、14 张顶部/底部截图，覆盖 560 × 680、520 × 500、640 × 800，深浅色以及已授权、未授权、暂停、快捷键冲突和监听失败。所有离屏窗口均保持不可见；每组只存在一个 `NSScrollView`，最小窗口可滚动至动画及退出，未发现横向溢出或文字布局缺失。程序及 `render-report.txt` 位于同一证据目录。

离屏截图不能证明实际键盘操作或 VoiceOver；离屏无障碍树为空。系统“减少动态效果”和“减少透明度”当时均关闭，本次未改动系统设置；控制器减少动态效果由注入测试覆盖，实际 UI 切换仍待验收。首次冷启动的菜单栏标签任务、真实主窗口前置和设置交互也仍需实机核对。

## 本地更新状态

已调用 `./scripts/dev-update.sh`，但在检查阶段安全停止：正在运行的副本为 PID `43453`，路径 `build/MainBuild-20260908.nqd1mN/Products/Ordo.app/Contents/MacOS/Ordo`，并非固定路径 `build/Ordo.app`。未退出该副本，未替换固定路径 App；此次检查目录为 `build/Updates/20260909-123031.9Jor5N/`。

需要先正常退出该运行副本，再重跑更新脚本；更新后还需核对新 PID、固定执行路径、真实日志落盘和主界面。当前仅可报告实现、测试、独立构建与签名完成，不能报告已部署或运行权限已验收。
