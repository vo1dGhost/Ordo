# 本机验证记录 · 2026-10-21（固定分页、文字胶囊与一体底色）

主窗口改为“基础 / 功能 / 关于”，可用内容区固定 **560 × 500 pt**，系统标题栏与工具栏另计。按本轮确认采用 Apple「时钟」方向的纯文字胶囊，标题栏、分页栏和内容共用底色，移除横向分隔线。版本保持 **1.0.1（2）**；源码和产物仅在本机保留，未提交、发布或替换已安装 App。工作区已有的新 Bundle ID 与签名配置继续保留。

- **行为**：静默启动默认关闭并持久化；首次使用、手动冷启动、登录／服务后台启动、启动通知前到达的重开及运行中重开分别处理。隐藏图标后仍可复用同一窗口，重开保留分页。排布固定为越过 **8 pt** 选中、回到 **16/3 pt** 内清除，4 pt 启动和角度迟滞保留；旧距离偏好不再读写。重置仅恢复三组快捷键，并阻断活动手势和旧输入。
- **回归证据**：先执行目标行为红测试，确认旧实现不满足新要求；最终完整隔离 XCTest **267 项通过、0 失败、0 跳过**。覆盖启动策略、首启分页、固定尺寸、窗口复用、旧距离失效、异步捕获路径、重置取消与其他设置保留。分页控件获得焦点后的左右键经过事件到选择回调的测试；没有向系统投递这些按键。
- **布局**：实际 SwiftUI Scene 的三页、关闭与重开，及七种状态的深浅色组合和监听失败均通过内容安全区域、独立页面所需高度和无滚动视图检查。覆盖未授权、快捷键冲突、登录项待批准／失败；全窗口保持同一尺寸。最终渲染记录确认标题栏和页面不再出现分色与分隔线。
- **截图与人工范围**：离屏截图不能完整记录系统玻璃合成层，选中区域可能显示为黑色占位，不能据此确认实际选中文字或玻璃效果。实时截图尝试遇到系统 ScreenCaptureKit 捕获失败；真实玻璃外观、VoiceOver 朗读、系统键盘导航路径、减少透明度／减少动态效果及 macOS 14–26 的实机外观仍待人工确认。现有减少动态效果的动画逻辑回归已通过，不能替代系统外观验收。
- **真实 AX**：未完成测试宿主授权和独立桌面命中条件的确认，显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不计作通过或权限跳过。未运行 Finder、Safari、Xcode、Chrome/Electron、多屏的真实窗口手势用例；本轮没有修改生产 AX 动画实现，独立 AX 动画脚本未重跑。
- **构建与签名**：Debug（arm64）及 Universal 2 Release（arm64、x86_64）构建和全部架构严格验签通过；开发证书链、有效期与团队 `ND3SVRRF43` 核验通过。沿用 `Apple Development`、`com.ghoooooost.Ordo`、Hardened Runtime、`LSUIElement=true`、最低 macOS 14 和无 App Sandbox entitlement。没有回退签名。XCTest 报告无运行时警告；控制台另有 SwiftUI 宿主首次布局的 AppKit 一次性重入提示和状态项 Scene 诊断，所有窗口几何与交互断言通过，原始日志保留。
- **本机交付**：`build/TabbedPreferences-20261021/Debug/Ordo.app`、`Release/Ordo.app`；同目录保留 `UnifiedFinalTests.xcresult`、最终测试摘要、构建／验签日志和 `UnifiedFinalAttachments/`。原始工作区 diff 与源码快照保留在该目录；修改文档前分别归档至 `build/DocumentArchive/20261021-TabbedPreferences/` 和 `20261021-TextTabs/`，原文件与副本 SHA-256 已核对。构建复用同一 DerivedData，未主动删除旧产物；结束时磁盘约余 17 GiB。
- **实时截图尝试的附带状态**：界面工具连接失败后额外启动了 `build/BundleID-20261021.ZGb9E2/DerivedData/Build/Products/Debug/Ordo.app`（PID 59529）。已通过项目生命周期工具按完整路径与 PID 正常退出；原 `/Applications/Ordo.app` 的 PID 48629 保持运行。该副本首次展示建立了新标识偏好域的 `ordo.onboarding.shown=true`，未删除或重置这份真实偏好，也未修改 TCC 或注册登录项。以上 PID 与时间仅为本轮快照。

# 本机验证记录 · 2026-10-21（Bundle ID 更新与独立分发签名）

按用户授权，将当前源码的 App Bundle ID 改为 `com.ghoooooost.Ordo`，测试目标同步为 `com.ghoooooost.OrdoTests`；版本仍为 **v1.0.1 开发版（构建号 2）**。本次使用 02:20 固定的工作区源码快照构建，包含当时已有的未提交改动；后续其他任务的界面与测试修改未追加到该快照。

- **标识同步**：App／测试目标的 Debug、Release 配置、本机生命周期工具、日志与性能标记、输入线程和队列使用新前缀。公开打包脚本改为从指定提交读取 Bundle ID，再核对产物，因此仍支持旧标识的历史源码。README 与协作指南同步当前标识；下方历史验证记录保留当时的旧标识。
- **开发构建**：Debug（arm64）和 Release（arm64、x86_64）归档成功，均通过严格验签。四组 target 配置仍是团队 `ND3SVRRF43` 的手动 `Apple Development` 签名；本机生命周期工具接受新标识的 Debug／Release App，并拒绝有效签名但使用旧标识的 App，以及 Developer ID 分发副本。
- **针对性测试**：新标识的 XCTest 宿主加载成功，启动与生命周期测试 **31 项通过、0 失败、0 跳过、无运行时警告**；更新脚本 **11 项隔离场景通过**。新旧源码的打包标识读取及脚本语法检查通过。本轮未重跑完整 XCTest、AX 动画回归或真实桌面交互，不能将这些范围计作通过。
- **独立分发副本**：通过已登录的 Xcode 账号，将归档以 `developer-id`、`destination=export` 导出。两种架构均为 `Developer ID Application: Yifan Cui (ND3SVRRF43)`，签名标识 `com.ghoooooost.Ordo`，安全时间戳为 **2026-10-21 02:21:59（北京时间）**。Hardened Runtime、`LSUIElement=true`、最低 macOS 14 均已核对，无 App Sandbox 或调试 entitlement；ZIP 解压后的全部架构严格验签通过。
- **公证状态**：没有提交 Apple 公证。Gatekeeper 实测返回 `rejected / source=Unnotarized Developer ID`，不能将有效 Developer ID 签名描述为已公证。既有公开 DMG 和发布脚本的 ad-hoc 流程未升级为 Developer ID 流程，本次 ZIP 未公开发布。
- **迁移边界**：新标识使用独立的偏好域和系统应用身份，首次使用需重新配置偏好、辅助功能授权和登录自启。本轮未安装或启动分发副本，未修改旧 App、用户偏好、登录项或 TCC 授权；权限延续与安装交互尚未验收。
- **本机证据**：`build/BundleID-20261021.ZGb9E2/` 保存源码快照与 SHA-256、原始改动、构建日志、`IdentityTests.xcresult`、测试摘要、签名和生命周期核验日志；分发包为其 `SignedOnly/Ordo-1.0.1-DeveloperID-universal.zip`，附 `SHA256SUMS.txt`。文档修改前归档至 `build/DocumentArchive/20261021-021948-BundleID/` 并核对 SHA-256。验证结束时磁盘约余 12 GiB，未删除旧产物。本次涉及文件的 diff 空白检查通过；全仓检查仍报告既有 `GestureCoordinatorTests.swift` 的末尾空行，未修改该范围外内容。

# 本机验证记录 · 2026-10-08（排布动画逐帧状态校验）

修复代码审查确认的排布动画中途进入全屏后仍继续写入问题，保留已有未提交改动。版本仍为 **v1.0.1 开发版（构建号 2）**，未提交、发布或替换运行中的 App。

- **修复**：每个中间帧在休眠返回后，重新通过 `validatedWindow` 检查权限、窗口身份、角色与原生全屏状态，再写入当前验证过的窗口。校验失败立即退出动画，不补写中间帧或最终几何；现有兼容设置租约沿错误路径恢复，撤权时保留权限恢复后的重试。插值进度按校验完成后的时间计算，慢 AX 校验跨过动画终点时直接进入最终精确提交。
- **生产代码回归**：新增 [AX 动画隔离回归脚本](../scripts/tests/ax-window-animation-tests.sh)，将生产控制器与内存 AX 接口替身编译为独立测试程序，不属于 App／XCTest target。9 项场景覆盖正常动画、立即排布、开始前与首帧后全屏、撤权、窗口失效、校验超时、取消、慢校验。修复前 **4 项通过、5 项失败**；修复后 **9 项全部通过**，不允许操作后的几何写入尝试均为零。兼容设置恢复、最终写入顺序与慢校验跳帧也已验证；协作指南补充对应回归命令。
- **完整隔离测试**：XCTest **258 项通过、0 失败、0 跳过，结果报告无运行时警告**。显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不计作通过；未安装真实全局监听或向外部窗口写入，未修改系统登录项。
- **构建与签名**：Debug（arm64）和 Universal 2 Release（arm64、x86_64）构建及全部架构严格验签通过。保持 Apple Development / `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`、Bundle ID `com.ghost7.Ordo`、最低 macOS 14 与无 App Sandbox entitlement。App Intents 元数据与复用缓存的旧产物路径提示不影响构建结果。
- **本机证据**：`build/AnimationStateFix-20261008/` 保存改动前源码、红测试与通过日志、`Tests.xcresult`、`test-summary.json`、构建及验签结果；候选位于其 `Debug/Ordo.app` 与 `Release/Ordo.app`。独立 AX 回归的编译产物保留在 `build/AXAnimationTests/` 各次运行目录。构建复用既有 DerivedData，验证结束时磁盘约余 14 GiB；改写本文及协作指南前已归档并核对 SHA-256，下方历史记录完整保留。

本轮验证了隔离状态切换下的写入门控，没有执行真实 App 进入全屏时的交互验收；新增 AX 校验对不同目标应用的实际耗时、动画流畅度和多屏行为仍待实机验证，不能由上述测试推断达到 120 fps。

# 本机验证记录 · 2026-10-08（捕获失败后的下一轮手势）

修复上一轮代码审查确认的捕获失败恢复问题，保留已有未提交改动。版本仍为 **v1.0.1 开发版（构建号 2）**，未提交、发布或替换运行中的 App。

- **问题与修复**：旧窗口捕获尚未返回时，用户已完整松键并开始逐键按下下一轮组合；若旧捕获随后失败，清理逻辑会丢掉完整松键记录，误将下一轮按键视为旧手势残留。现在先保留已观察到的松键边界，再清理捕获状态；尚未完整松键时仍等待全部释放。
- **测试先行**：新增 2 项回归测试，覆盖修饰键事件和鼠标 flags 提供完整松键边界，以及全部按住、仅部分松键时的保护与恢复。修复前专项 11 项中有 1 项失败，产生 14 处断言失败；修复后完整隔离 XCTest **258 项通过、0 失败、0 跳过，结果报告无运行时警告**。验证下一轮缩放准确提交一次、失败的旧手势不写几何。
- **构建与签名**：Debug（arm64）和 Universal 2 Release（arm64、x86_64）构建及全部架构严格验签通过；保持 Apple Development / `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`、Bundle ID `com.ghost7.Ordo`、最低 macOS 14 和无 App Sandbox entitlement。构建中的 App Intents 元数据与复用缓存的旧产物路径提示不影响结果。
- **验证范围**：显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不计作通过；本轮未评估真实桌面命中条件，也未启动真实全局监听或向外部窗口写入。实际 AX 捕获失败后的连续手势仍待实机验收。
- **本机证据**：`build/CaptureFailureFix-20261008/` 保留改动前源码、红测试、`Tests.xcresult`、`test-summary.json`、构建日志和 `build-verification.json`，独立候选位于其 `Debug/Ordo.app` 与 `Release/Ordo.app`。复用已有 DerivedData，验证结束磁盘约余 13 GiB。修改本文前已归档并核对 SHA-256，下方历史记录完整保留。

# 本机验证记录 · 2026-10-06（代码审查问题修复）

修复本轮审查确认的四项问题，保留已有未提交改动。当前仍为 **v1.0.1 开发版（构建号 2）**，未提交、发布或替换运行中的 App。

- **真实 AX 测试保护**：捕获窗口的 PID 不属于测试宿主时，在任何前置、移动或缩放之前抛出失败，并释放引用；写入失败也会释放引用。使用内存替身验证误命中零写入、正确命中正常执行及错误路径只释放一次。
- **监听中断**：Event Tap 被系统停用后，在重新启用或重建监听前同步取消旧捕获、连续移动／缩放、前置及最终提交任务。即使后续没有新输入，也不能继续写入；恢复后等待实际观察到全部修饰键松开，重复取消不能用中断前的空 flags 提前解除保护。
- **连续手势**：上一轮异步捕获未返回时，完整松键后开始的新手势可以取代旧捕获；迟到的旧窗口仅释放。仅松开部分修饰键不开始下一轮；旧捕获在新组合键尚未按齐时返回，也保留已经观察到的完整松键边界。
- **启动阈值**：异步捕获期间同步记录是否曾越过 4 pt，越界后追加修饰键或回到起点均不替换原手势；恰好 4 pt 的死区边界仍允许切换到较长精确组合。修饰键事件与鼠标携带的 flags 均覆盖。
- **测试先行与结果**：首次专项红测试在修复前出现 **26 处断言失败**；复查补充的重复取消与逐键按下边界分别先出现 **1、3 处断言失败**，随后修正。共新增 **14 项回归测试**；最终完整隔离 XCTest **256 项通过、0 失败、0 跳过，结果报告无运行时警告**。
- **明确排除**：本轮未评估真实桌面命中条件，继续显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不计作通过。测试使用替身与隔离偏好，没有通过真实全局监听向外部窗口写入，也未更改系统登录项。PID 防护已验证不等于真实 AX 交互验收通过。
- **构建与签名**：最终 Debug（arm64）与 Universal 2 Release（arm64、x86_64）均构建成功，并通过 `codesign --verify --deep --strict --all-architectures`。保持 Apple Development / `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`、Bundle ID `com.ghost7.Ordo`、最低 macOS 14 和无 App Sandbox entitlement。沙盒内信任校验受限后，使用系统钥匙串上下文完成验签，没有降级签名；App Intents 元数据与复用缓存的旧产物路径提示不影响构建。
- **本机证据**：`build/ReviewFix-20261006/` 保留改动前源码、红测试、最终 `FinalTests.xcresult`、`final-test-summary.json`、构建日志和 `build-verification.json`；最终候选位于其 `Debug/Ordo.app` 与 `Release/Ordo.app`。为节省磁盘复用前轮 `build/CodeReview-20261006/DerivedData`。修改三份文档前已归档并逐份核对 SHA-256，下方历史记录保持完整。

真实系统停用／恢复 Event Tap、Finder／Safari／Xcode／Chrome/Electron 的窗口前置和连续手势、多屏及旧版 macOS 仍待实机验收；本轮自动化结果不代替这些交互验证。

# 文档核验记录 · 2026-09-28（Ordo 品牌命名）

本轮按命名方案更新 [README](../README.md)、[协作指南](../AGENTS.md) 和[素材说明](../Artwork/README.md)，新增[品牌命名规范](BRANDING.md)，并保留既有未提交改动及下方历史记录。

- 正式名称统一为 **Ordo**，视觉字标为 **ØRDO**；产品定位与标语使用约定的中英文文案。
- **格序 / 窗序** 保留为中文辅助名候选；模块与版本名称仅为命名建议，不表示新增功能或已发布版本。
- 修改前已归档四份原有文档并逐份核对 SHA-256；本轮仅涉及文档，没有修改代码、工程配置、运行图标或演示素材。
- 检查通过：五份文档的 55 处本地链接与资源引用、代码围栏、命名一致性及 `git diff --check`；131 份文档范围外文件的 SHA-256 与修改前一致，下方历史记录完整保留。未重新运行 XCTest、构建、签名、安装或真实手势验收，不更新历史验证结论。

# 本机验证记录 · 2026-09-17（v1.0.1 慢窗口缩放输入积压）

用户反馈 Chrome 等较重窗口在缩放期间持续落后于鼠标。本轮先保留运行现场，确认仍为上轮独立候选 PID `17752`；收集已有耗时标记和日志后才切换版本。版本仍为 **1.0.1（构建号 2）开发版**，全部改动未提交，未覆盖已安装副本或发布。

- **已复现的缺陷**：输入线程虽然每约 8.33 ms 合并鼠标位置，后续 `AsyncStream<InputEvent>` 仍逐条缓存，主执行器被同步 AX 占用后会逐个处理旧位置并补写尺寸。使用内存事件和同步窗口替身，在一次尺寸写入期间记录一串新位置，旧实现实际写出宽度 `[420, 440, 500, 520, …, 780, 800]`；到达最终 `800` 前额外写入 **16 个过期尺寸**。红测试留下 1 处明确断言失败；这是真实生产输入中继与手势协调器的隔离复现，不是 Chrome 帧率测试。
- **修复**：改用可追加的 `InputEventBatch`，消费者真正恢复到主执行器后才同步取出整批并处理，再允许几何任务执行。相同用例现在只写 `[420, 800]`；慢调用期间松键时，只保留先前已执行的写入及一次最终提交。批次保留修饰键边界、4 pt 越界路径和径向迟滞，未用“只留下一个鼠标点”替代完整手势判断。停止或新 epoch 使尚未取出的旧批次失效。缓存上限为 1,024 条采样，超限转为取消并等待修饰键全部释放，不执行残缺输入。120 Hz 采样目标、AX 检查、主执行器隔离和最终读回保持原行为。
- **现场耗时**：旧候选在 17:53:48–17:53:56 留下以下完整区间。标记不包含目标 App 身份，因此不能把整段结果归为 Chrome，也不能把调用耗时当作窗口呈现帧率。相同时间的活动日志另记录了 1 次“验证目标窗口”超时。

  | 区间 | 次数 | 中位耗时 | P95 | 最大耗时 | 超过 8.33 ms 的次数 |
  | --- | ---: | ---: | ---: | ---: | ---: |
  | 窗口校验 | 336 | 0.565 ms | 23.208 ms | 351.089 ms | 114 |
  | 尺寸写入 | 167 | 9.168 ms | 21.434 ms | 37.311 ms | 99 |

  该记录证明同步调用会超过单帧预算，队列修复不能保证重应用达到 120 fps；未将两项 P95 相加，也没有声称目标应用本身的响应耗时已下降。
- **回归**：专项 92 项通过，补充超限取消与恢复覆盖后，完整隔离 XCTest **242 项通过、0 失败、0 跳过、0 运行时警告**。覆盖慢调用后直接采用最新尺寸、阻塞期间松键、消费者恢复前新增事件、超过旧队列容量仍保留修饰键及路径、旧批次失效、有界取消、4 pt 越界后回到死区、径向迟滞，以及原有跨桌面、登录项和窗口生命周期用例。继续显式排除可能误操作外部窗口的 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不计作通过。测试未安装真实输入监听、未写外部窗口、未修改用户偏好或系统登录项。
- **构建与启动**：Debug（arm64）、Release（arm64 + x86_64）构建与全部架构严格验签通过；项目生命周期工具再次核验 Apple Development / `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`、无 Sandbox、最低 macOS 14。正常退出旧候选并等待清理后，于 **18:11:42** 启动 `build/V1.0.1-ResizeLatency/Release/Ordo.app`，PID `20291`，唯一实例的实际执行路径已核对，日志确认辅助功能已授权、监听已启动。旧候选仍保留在原目录，已安装副本未修改。
- 证据保存在 `build/V1.0.1-ResizeLatency/`：修改前源码与工作区 diff、红测试、专项和完整测试结果、源码哈希、Debug／Release 构建及签名摘要、`BeforeSignposts.ndjson` 和 `BeforeTimingSummary.json`、切换前后进程记录与启动日志。README、协作指南和本文改写前已归档并核对 SHA-256。复用同一 DerivedData，构建期间磁盘约余 12 GiB，未删除用户文件或旧产物。构建中的 App Intents 元数据提示、旧产物路径提示和既有测试弱引用声明警告不属于运行时警告。

**待实机验收**：新候选在用户原 Chrome 窗口上的缩放跟手程度、松键终态及长时稳定性；Finder、Safari、Xcode、其他 Electron 窗口和多屏回归。当前仅确认队列缺陷已通过隔离测试修复及候选已启动，尚未测得优化后端到端延迟或真实显示帧率；原有登录启动、隐藏图标重开、多桌面和旧系统待验收事项继续适用。

# 本机验证记录 · 2026-09-17（v1.0.1 独立输入线程与连续手势兼容）

按照开源实现比较后的建议继续尝试改善跟手性，保留之前全部未提交改动；版本仍为 **1.0.1（构建号 2）开发版**。本轮独立构建并启动候选，未覆盖已安装副本、提交、打标签或发布，公开下载仍为 v1.0.0。

- **输入线程**：参考 [Loop 的独立 RunLoop](https://github.com/MrKai77/Loop/blob/df26d565e07c82e156b8f1c361bdcf428f32e3a4/Loop/Utilities/Event%20Monitoring/EventTapThread.swift)，将 Tap 的接收、安装、重启、销毁移到专用线程；C 回调仍只记录修饰键与鼠标位置，保持 listen-only、120 Hz 合并和原有 epoch 门控。停止先拒绝输入，再等待线程上的旧回调结束；销毁期间仍保留回调中继。系统禁用通知带原 epoch，停止或重启后的旧通知不再重启新会话。AX actor 继续绑定主执行器。
- **每次校验仍读取最新状态**：采用 Apple 的 [AXUIElementCopyMultipleAttributeValues](https://developer.apple.com/documentation/applicationservices/axuielementcopymultipleattributevalues(_:_:_:_:)) 合并窗口角色与原生全屏读取，没有缓存窗口有效性或全屏结果。逐属性 AX 错误与 CFNull 分别处理，硬错误不重试；目标不支持批量 API 时回退原逐项路径，并仅对该次捕获缓存“不支持批量”的能力。常规稳定连续更新由 3 次 AX 属性 API 调用降为 2 次（一次批量读取、一次写入），权限查询及首次手势准备另计；这是源码调用数，不是 IPC 耗时或实际帧率提升比例。
- **连续手势兼容**：移动／缩放越过 4 pt 并完成前置后才调用 `beginContinuousInteraction`，对原值严格为 true 的 `AXEnhancedUserInterface` 获取一次临时抑制租约，最终读回后释放。死区、排布方向选择期间不提前处理；缺失或不可写时无错误降级。复用同 PID 重叠租约，在取消、失败、撤权和退出时尽力恢复，并在恢复暂时失败时保留既有重试机制。未采用 Rectangle 按应用名单长期关闭 Enhanced UI 的策略。
- **可测量性**：增加 Instruments Points of Interest 区间 `AX validation`、`AX position write`、`AX size write`，不记录目标身份、几何或输入内容。候选启动后的 17:39:52–17:40:17 真实交互产生 3,070 对完整区间（无缺失配对）；包含移动、缩放和排布，不能按目标应用区分，也没有优化前基线。

  | 区间 | 次数 | 中位耗时 | P95 | 最大耗时 | 超过 8.33 ms 的次数 |
  | --- | ---: | ---: | ---: | ---: | ---: |
  | 窗口校验（含权限与批量属性读取） | 1,642 | 0.414 ms | 7.606 ms | 46.706 ms | 44 |
  | 尺寸写入 | 1,141 | 3.308 ms | 8.351 ms | 36.248 ms | 58 |
  | 位置写入 | 287 | 0.979 ms | 10.323 ms | 17.126 ms | 38 |

  这些是 Ordo 同步调用区间的耗时，不能代表目标窗口呈现帧率或单独的连续缩放结果。慢调用仍会超出 120 Hz 预算；未确认稳定 120 fps，也不将各项 P95 相加当作一次更新的 P95。
- **回归**：手势准备与停止后禁用通知的两项新增测试，在修复前实际触发 7 处断言失败；批量读取用例也在逐项读取版本上实际失败。修复后专项 **79 项通过**，补充线程销毁时仍有任务在执行的生命周期用例后，完整隔离 XCTest **233 项通过、0 失败、0 跳过、0 运行时警告**。覆盖最新全屏值、批量能力回退、逐属性错误、主线程阻塞时输入线程执行、回调中继保活、停止与旧 epoch、连续手势准备与最终释放、准备失败／准备后取消不写几何；保留跨桌面和已有功能回归。
- 继续显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不计作通过。新增测试未安装真实 Event Tap、未向外部窗口发送事件或写入几何，未修改系统登录项或用户授权。
- **环境与构建**：本次本机为 macOS **27.0（26A428）**、Xcode **27.0（27A266a）**。Debug（arm64）与 Release（arm64 + x86_64）通过；严格验签保持 **Apple Development / ND3SVRRF43**、Hardened Runtime、`LSUIElement=true`、无 App Sandbox，最低部署版本仍为 macOS 14。受限环境中的首次验签无法读取正常证书信任状态，使用系统正常信任服务重新核验后两份产物均通过；未更改签名或证书信任设置。
- 候选为 `build/V1.0.1-InputPipeline/Release/Ordo.app`。确认没有其他 Ordo 实例后，于 17:39:42 从该独立目录启动，实际执行路径和 PID `17752` 已核对；自身日志记录监听启动及后续移动、缩放、排布成功，未操作已安装副本。日志不能说明目标应用身份或流畅度。
- 该证据目录保留两轮红测试、专项／完整测试结果、构建日志、验签及配置摘要、启动路径、`Signposts.ndjson` 与 `TimingSummary.json`、改动前源码和文档归档清单。文档改写前已逐份核对 SHA-256。构建前磁盘约剩 15 GiB，验签时约剩 13 GiB；本轮复用同一 DerivedData 完成 Debug／Release，未清理用户文件或旧产物。

**待实机验收**：真实 Event Tap 的停止、睡眠恢复和长时稳定性；Finder、Safari、Xcode、Chrome/Electron 的逐项连续移动／缩放验收、同 PID 重叠操作后的 Enhanced UI 恢复、固定尺寸窗口与跨屏行为；实际 120 Hz 显示器上的跟手延迟和掉帧。macOS 14–26 与 Intel 真机仍未在本轮实测。自动测试、启动和调用耗时记录不能代替这些验收。

# 本机验证记录 · 2026-09-16（v1.0.1 连续移动与缩放开销）

用户反馈提高输入频率后仍然卡顿。本轮先核对运行现场：实际运行的是上一轮 `build/V1.0.1-120Hz/Release/Ordo.app`，版本 1.0.1（2），PID `22181`，18:36:11 启动；没有先退出、重启或覆盖该实例。

- **连续手势读回**：移动与缩放原先每次写入都会再次读取位置和尺寸，返回值在连续手势中被丢弃。新增 `updatePosition`／`updateSize`，共用原有写入前检查及写入实现，连续更新省略这两次读回；正常松键仍通过原 `setPosition`／`setSize` 提交并读回最终结果。按源码调用序列统计，常规连续更新的 AX 属性访问由每次 5 次降为 3 次，权限查询另计；这不是实际帧率或耗时提升比例。
- **无变化状态刷新**：权限轮询每 0.5 秒都会给 `@Published monitoringActive` 赋相同值。现于发布前去重，正常运行、未授权及监听失败时不重复发布；权限变化、停止、恢复仍及时通知。5 秒只读进程采样看到了菜单栏绘制和 SwiftUI 更新，但没有捕获活动手势的 AX 栈，因此不能据此认定全部卡顿原因。
- **测试先行**：三项手势回归在旧实现上实际触发 6 处读回次数断言失败；两项状态发布回归在旧实现上触发 4 处断言失败。修复后窗口更新专项 **53 项通过**，完整隔离 XCTest **220 项通过、0 失败、0 跳过**，包含输入合并、取消与撤权、最终提交、窗口生命周期及跨桌面回归。
- 继续显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不计作通过。未向外部窗口写入几何，也未修改用户设置或系统登录项；状态测试使用隔离替身。AX 仍绑定主执行器，窗口有效性、原生全屏、权限和取消检查未删减；排布动画及 `AXEnhancedUserInterface` 的使用范围不变。
- Debug 和 Universal 2 Release 构建通过；版本仍为 **1.0.1（构建号 2）开发版**。严格验签与配置核对结果保存在下述证据目录的 `BuildVerification.json`；维持原开发签名、Hardened Runtime、`LSUIElement=true` 和无 App Sandbox 的基线。
- 新候选位于 `build/V1.0.1-MotionPerformance/Release/Ordo.app`。同目录保留原日志快照、`RuntimeSample.txt`、改动前源码、两轮红测试、专项和完整测试结果、构建及验签日志。文档修改前已归档并核对 SHA-256，全部代码仍未提交，未替换正在运行或已安装的 App。
- **尚未证明卡顿已消除**：本轮确认并消除了两处额外开销，没有测得外部目标窗口的实际帧时间；仍需用新候选在用户发生卡顿的 App 上进行真实移动／缩放验收。上一轮内存输入中继约 112 次/秒的结果不能替代此项，也不能代表窗口达到 120 fps。原有登录自启、Finder／Spotlight 重开、多桌面及旧系统待验收事项继续适用。

# 本机验证记录 · 2026-09-16（v1.0.1 目标 120 Hz）

将鼠标位置合并及排布动画的目标间隔统一为 **8,333,334 ns（约 120 Hz）**。首个位置立即进入异步处理队列，后续只等待当前周期的剩余时间，调度延迟时只交付最新位置；松键先交付最后位置，停止、重启及松键后的旧回调不能提前交付新一轮输入。排布动画保持 200 ms，继续跳过错过的采样并执行最终精确提交。AX executor、权限、几何校验和窗口写入顺序保持原有实现。

- 测试先行：120 Hz 动画预期在原 60 Hz 实现上实际触发 11 处断言失败，覆盖默认间隔、采样时间与中间帧数量。最终专项回归 **50 项通过**；完整隔离 XCTest **215 项通过、0 失败、0 跳过，报告无运行时警告**，包括原有跨桌面回归。
- 新增确定性输入测试覆盖首个位置、空闲后响应、高频合并、延迟调度、松键顺序和 epoch 更换；理想 1,000 Hz 输入的一秒内得到 120 次位置交付。测试只构造内存 CGEvent，没有安装真实事件监听或向系统发送输入。
- 单独运行新旧生产中继的真实计时对比，各执行 3 轮、每轮 2 秒，输入目标约 1,000 次/秒。旧实现平均 **58.89 次/秒**，交付间隔中位数约 **16.98 ms**；新实现平均 **111.97 次/秒**，中位数约 **8.99 ms**，第 95 百分位间隔为 **9.15–9.21 ms**。这是本机中继调度的测量，未包含真实 Event Tap、AX 写入或目标应用重绘；不能计作外部窗口达到 120 fps。调度误差仍使实测值低于 120 Hz。
- 显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不计作通过；本轮没有操作外部窗口来测试流畅度。
- Debug 与 Universal 2 Release 构建及严格验签通过；保持 **1.0.1（构建号 2）**、Apple Development / `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`、最低 macOS 14、无 App Sandbox entitlement。构建日志的 App Intents 元数据及旧产物路径提示不影响构建；旧候选继续保留。
- 候选位于 `build/V1.0.1-120Hz/Release/Ordo.app`。证据位于 `build/V1.0.1-120Hz/`，包含红测试、专项与完整测试结果包、`TestSummary.json`、`BuildVerification.json`、构建和验签日志，以及基准程序和 `BenchmarkSummary.json`。文档修改前已归档并核对 SHA-256；保留全部既有未提交改动，没有提交、发布或覆盖已安装 App。
- 120 Hz 显示器上真实移动、缩放、排布的帧时间和主观流畅度仍待验收；目标应用响应、系统调度和输入设备可能限制实际频率。登录自启、隐藏后 Finder／Spotlight 重开及多桌面等既有实机待验收事项继续适用。

# 本机验证记录 · 2026-09-16（v1.0.1 滑条与菜单图标修正）

修复排布距离滑条下方的密集刻度横线，并明确显示菜单“打开”“退出”左侧的窗口和电源图标。版本仍为 **1.0.1（构建号 2）开发版**；保留此前未提交改动，未替换已安装 App。

- 原因：macOS 新版 SwiftUI 会为带 `step` 的滑条自动绘制刻度；8–200 pt、1 pt 步进形成的密集刻度看起来像一条横线。改用连续滑条并在写回时取整，方向键和无障碍增减动作按 1 pt 调节并限制边界。依据见 [Apple 的控件设计说明](https://developer.apple.com/videos/play/wwdc2025/323/)。距离默认值、范围、持久化和下一次手势生效的行为不变。
- 已导出并目视检查隔离宿主的真实 SwiftUI 窗口截图，滑条下方不再出现刻度横线。最初尝试的 `tick: { _ in nil }` 仍显示刻度，未用于最终实现；验证未依赖将 SwiftUI 控件强制转换为 `NSSlider`。
- 菜单项明确应用 `.titleAndIcon`；新增 `NSHostingMenu` 测试，在外层只显示文字的样式下仍得到“打开”“退出”两个带图标、无快捷键的原生菜单项。未点击退出或操作已安装实例。
- 完整隔离 XCTest **208 项通过、0 失败、0 跳过，报告无运行时警告**。继续显式排除可能误操作外部窗口的 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，该项不计作通过。控制器、手势距离、统一重置与跨桌面回归覆盖保持通过。
- Debug 和 Universal 2 Release 构建、严格验签通过；保持 Apple Development / `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`，无 App Sandbox entitlement。Release 日志中的旧产物路径提示来自复用构建缓存，旧候选未删除；App Intents 元数据提示不影响此 App 构建。
- 当前候选：`build/V1.0.1-UIFix/Release/Ordo.app`；证据：同目录的 `Tests.xcresult`、`TestSummary.json`、`Attachments/`、构建和验签日志。修改文档前已归档并核对 SHA-256。
- 真实鼠标拖动、键盘和 VoiceOver 交互，以及已安装路径下的菜单目视、登录自启、多桌面和旧版 macOS 验收仍需单列执行；宿主渲染和原生菜单结构测试不能替代这些实机验收。

# 本机验证记录 · 2026-09-16（v1.0.1 开发版）

本轮在现有跨桌面预览恢复改动上，加入登录自启、菜单栏图标隐藏、排布触发距离设置和统一手势重置，并将菜单精简为“打开”“退出”。App 和测试 target 的版本均为 **1.0.1（构建号 2）**；代码保持未提交，未打标签、推送或公开发布，未覆盖已安装的 App。公开安装包仍为 v1.0.0。

## 自动化验证

- 环境：macOS **27.0（26A428）**、Xcode **27.0（27A266a）**、macOS 27 SDK；最低部署目标仍为 macOS 14。当前运行测试为 Apple Silicon，不代表 macOS 14–26 或 Intel 真机已验收。
- 两项回归测试在旧实现上实际失败：持久化的自定义距离未影响触发／取消，快捷键重置未恢复距离。修复后相关定向组 **98 项通过**。
- 窗口集成测试进一步发现 `MenuBarExtra` 回写相同值导致 SwiftUI 更新循环，以及窗口场景未观察 delegate 的重开请求。修复采用发布前去重和独立、显式观察 delegate 的主窗口场景。最终宿主内实测隐藏图标、关闭窗口、应用重开和重复重开均通过，保留同一个主窗口，图标偏好仍为隐藏。
- 最终 XCTest：**207 项通过、0 失败、0 跳过，测试报告无运行时警告**。覆盖登录项注册／注销／待批准／错误／系统外部状态刷新，图标与距离持久化和无效数据回退，8–200 pt 的八向触发与比例取消、异步捕获前参数锁定、统一重置保留其他设置及阻断旧输入；包含原有跨桌面修复测试。
- 另用独立的测试启动配置，将图标在进程启动前即设为隐藏，后台不弹主窗口与后续重开两项集成测试均通过。此配置仅通过命令行偏好影响隔离宿主，不修改用户设置，也不代表真实系统登录已验收。
- 显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不计作通过。控制器使用替身；窗口集成用例只展示和关闭 XCTest 宿主自身窗口，共享控制器使用隔离偏好并禁止真实全局手势监听，未修改系统登录项或真实辅助功能授权。
- 已导出并目视检查宿主窗口截图：主窗口的自启和图标开关、距离滑块与数值、滚动内容底部红色“重置手势设置”均正常。截图中的未授权／未找到登录项属于隔离测试宿主状态，不能作为已安装 App 的权限或登录项状态。
- 已核对菜单源码只保留“打开”“退出”，两项快捷键绑定均已移除。真实菜单栏深浅背景、高亮与外部用户操作仍按下方清单验收。

## 构建与签名

- Debug 随 XCTest 构建通过；Release 独立构建通过，包含 **arm64 和 x86_64** 两种架构。
- Debug 与 Release 均通过 `codesign --verify --deep --strict --all-architectures`。Release 为 **Apple Development / ND3SVRRF43**，Hardened Runtime 开启，`LSUIElement=true`，无 App Sandbox entitlement；Bundle ID 和开发签名设置保持原值。
- Release 候选位于 `build/V1.0.1/Release/Ordo.app`。这是本地开发签名候选，不是公开分发或公证产物。
- 证据位于 `build/V1.0.1/`：`Red.xcresult`、`Focused.xcresult`、窗口集成诊断与 `WindowScene.xcresult`、`HiddenColdStart.xcresult`、最终 `Acceptance.xcresult` 和 `AcceptanceSummary.json`、`Attachments/`、构建与验签日志。文档修改前已核对归档 SHA-256。

## 待实机验收

- 在实际安装位置切换登录自启，核对系统登录项、待批准提示及真实注销／重新登录后的后台启动。替身测试不代表这项已完成；本轮未注销当前用户或重启系统。
- 通过 Finder／Spotlight 操作实际安装的候选，核对隐藏状态下的冷启动与重开、主窗口焦点、图标恢复，以及菜单仅有两项且无快捷键显示。宿主重开集成测试不能替代完整安装路径的验收。
- 真实桌面 1／2／3、多显示器、Finder／Safari／Xcode／Chrome 等应用的手势与跨桌面预览恢复；辅助功能权限延续性和最低支持系统运行验证。

# 本机验证记录 · 2026-09-10（跨桌面预览恢复）

修复普通桌面切换后八向预览和定位标志只在部分桌面显示的问题。活动 Space 变化会取消旧手势、推进输入 epoch 并销毁两个预览面板；复用面板前另外检查 `isOnActiveSpace`，不再仅依赖 `isVisible`。当前桌面恢复不扩展目标窗口的跨 Space 搬移功能。

- 现场只读对照确认：同一个 Ordo 进程、同一对面板，在两次成功排布中分别出现 `onscreen=false` 与 `onscreen=true`；没有改动运行实例来制造复现。最早触发异常的系统事件无法从现有日志还原。
- 三个新增回归测试在旧实现上均实际断言失败；修复后预览与生命周期测试组 **28 项通过**。
- 最终 XCTest：**190 项通过、0 失败、0 跳过**。新增覆盖可见／已隐藏但不在当前 Space 的预览面板、下一次手势的起点面板重建、仅有标记／已有方向时切换桌面、旧 epoch 事件不能提交、后续手势恢复与退出后停止响应通知。
- 显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不将该项计作通过。新增测试使用替身和进程内通知，没有切换系统桌面或向外部窗口写入几何。
- Debug 随 XCTest 构建通过；Release 为 Universal 2，严格验签和维护者团队验证通过，保持 Apple Development / `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`、无 App Sandbox。
- 用户明确确认后，已正常退出旧实例并更新 `/Applications/Ordo.app`，旧版保留在 `build/Archive/20260910-PreviewSpacesFix/Ordo.app`。安装副本与已验签候选的二进制哈希一致，旧版哈希与诊断时一致；新进程 PID `43193`，于 10:58:03 启动，实际执行路径核对通过。
- 当前安装从临时签名切换为开发签名，尚待重新授予辅助功能权限，以及真实桌面 1／2／3 的预览与定位标志验收；安装、签名和启动通过不能代替交互通过。

本轮证据位于 `build/PreviewSpacesFix-20260910/`，包含 `Red.xcresult`、`Focused.xcresult`、`Tests.xcresult`、测试和构建日志。诊断证据位于 `build/Diagnostics/20260910-PreviewSpaces/`。文档修改前已按 SHA-256 核对本机归档，代码未暂存或提交。

# 本机验证记录 · 2026-09-09（1.0.0 发布准备）

本轮将当前单栏主窗口、快捷键重置、本地文件日志及配套文档纳入首发，新增共享 Scheme 和独立 Universal 2 DMG 打包入口。App 与测试 target 的开发签名仍为固定团队的 Apple Development；仅分发副本采用 ad-hoc 签名，不代表 Developer ID 签名或 Apple 公证。

- macOS 26.6.2、Xcode 26.6，在当前 Apple Silicon Mac 执行安全 XCTest：**187 项通过、0 失败、0 跳过**；Debug 构建通过。
- 显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，未将该项真实 AX 操作记为通过；下载后窗口手势另行实机验收。
- 当前源码、main 历史文本及 47 个 PNG 元数据检查未发现凭据或个人绝对路径。提交身份保留维护者明确选择公开的新邮箱，本机归档由 `build/` 忽略规则覆盖。
- 首个 Universal 2 候选的调试索引包含本机源码路径，产物审计拦截后未上传。分发流程现于签名前剥离调试符号，并对 staging 与 DMG 内的可执行文件检查用户及临时目录路径；原始候选保留供本机复核。
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
