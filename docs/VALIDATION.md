# 本机验证记录 · 2026-10-29（v1.0.1 GitHub 发布与下载回验）

- **发布完成**：北京时间 **2026-10-29 13:20:05**，公开 [Ordo 1.0.1](https://github.com/vo1dGhost/Ordo/releases/tag/v1.0.1)，标记为最新版。标签 `v1.0.1` 对应提交 `47629707801b790ad71434d320ebe9624606134b`，App 源码与公证快照一致；上传 `Ordo-1.0.1-universal.dmg` 和 `SHA256SUMS.txt`，GitHub 返回的 DMG SHA-256 与本地一致。保留 v1.0.0、旧标签与附件，没有覆盖或移动。
- **真实下载回验**：从 Chrome 的公开 Release 页面下载 DMG，下载文件与本地候选逐字节一致，SHA-256 为 `0425f1cbf3f5c812afe6f9564b3a80be284b8f2cb1117c3cda33c5d1cbae737f`，存在来源为 Chrome 的 `com.apple.quarantine` 标记，未清除。映像完整性检查通过；只读挂载后，App 全架构严格验签、公证票据验证及 Gatekeeper 再次通过（`accepted / source=Notarized Developer ID`），检查后正常卸载。原始记录在 `build/Notarization-20261029/DMG/` 的 `download-*.log`；本段编辑前文档归档至 `build/DocumentArchive/20261029-GitHubPublished/` 并核对 SHA-256。
- **授权与范围**：用户明确授权官方 GitHub CLI 登录和发布，登录使用系统钥匙串及已有 `repo`、`read:org`、`gist` 范围，没有增加 Actions `workflow` 权限。仅推送 `main` 与 `v1.0.1`。本轮没有安装、启动或替换本机 App，首次打开与辅助功能授权、真实多应用、多屏和旧系统验收仍未完成；下载与 Gatekeeper 检查不能代替上述交互验证。

# 本机验证记录 · 2026-10-29（v1.0.1 公证 App 的 DMG 发布候选）

按用户授权，将上轮已公证的 **1.0.1（2）** Universal 2 App 原样打包为只读 DMG，包含 `Ordo.app`、指向 `/Applications` 的快捷入口和 MIT 许可证。未重新运行原 ad-hoc 打包脚本，以免覆盖 Developer ID 签名；DMG 容器自身未另行签名或公证。

- **映像检查**：`hdiutil verify` 通过；只读挂载后，App 全架构严格验签、公证票据验证及 Gatekeeper 检查均通过，结果为 `accepted / source=Notarized Developer ID`。执行文件与原公证副本逐字节一致，许可证与仓库一致，Applications 链接正确，检查后正常卸载映像。
- **附件**：`Ordo-1.0.1-universal.dmg` 的 SHA-256 为 `0425f1cbf3f5c812afe6f9564b3a80be284b8f2cb1117c3cda33c5d1cbae737f`，附 `SHA256SUMS.txt`。候选、验证日志和校验文件保存在 `build/Notarization-20261029/DMG/`。发布使用独立新标签 `v1.0.1`，保留 v1.0.0 与既有附件；源码须与公证快照一致。
- **范围**：本轮只做分发打包及发布材料准备，不修改 App 行为，不重跑 XCTest 或真实 AX 用例，不替换本机 App。既有 272 项隔离测试是上轮记录，真实多应用、多屏、旧系统及首次授权验收仍待完成。README 与验证文档修改前归档至 `build/DocumentArchive/20261029-GitHubRelease/` 并核对 SHA-256；未删除文件。线上发布状态及下载回验以实际 GitHub Release 和后续证据为准。

# 本机验证记录 · 2026-10-29（Developer ID 分发副本公证）

按用户“进行公证”的授权，为当前工作区源码创建独立快照及 Universal 2 Release 归档，版本保持 **1.0.1（2）**、Bundle ID `com.ghoooooost.Ordo`。快照包含当前未提交的界面、键帽反馈和无色排布圆环实现；归档后逐目录比较 App 源码一致。此次结果仅适用于下列分发副本，不改变历史公开安装包的签名与公证状态。

- **签名与提交**：通过已登录 Xcode 账号，以 `developer-id` / `destination=upload` 完成 Developer ID 云签名及 Apple 公证上传。两种架构均使用 `Developer ID Application: Yifan Cui (ND3SVRRF43)`，安全时间戳为北京时间 **2026-10-29 12:59:28**；工程 App／测试 target 的 Apple Development 配置及既有 ad-hoc 打包脚本保持不变。
- **公证与最终验证**：上传后首次导出返回“processing”，未将上传成功计为公证通过。随后 Apple 公证票据取得并装订成功，`stapler validate` 通过；全部架构严格验签通过，Gatekeeper 返回 **`accepted / source=Notarized Developer ID`**。最终 ZIP 解压后的 App 再次通过上述三项检查。保留 Hardened Runtime、`LSUIElement=true`、最低 macOS 14，entitlements 为空，不含 App Sandbox 或调试 entitlement；分发执行文件未发现本机用户或临时目录路径。
- **交付**：`build/Notarization-20261029/Ordo-1.0.1-DeveloperID-notarized-universal.zip`，SHA-256 为 `cfea1feb0d7c79c2361a5fe09e5899a95d42eb6f19a969d5ee3d9da9cca7dddf`。同目录保存 `SHA256SUMS.txt`、源码快照及哈希、归档、上传和装订日志、两种架构签名证据、Gatekeeper 结果及 ZIP 解压验证副本。未提交或发布到 GitHub，未替换已安装 App。
- **范围与保留**：本轮没有修改 App 行为，未重跑 XCTest 或真实 AX 用例；公证与 Gatekeeper 本机检查不能代替浏览器下载隔离、首次安装授权、多应用、多屏和旧系统实机验收。原验证文档归档至 `build/DocumentArchive/20261029-Notarization/` 并逐字节及 SHA-256 核对；未删除文件，保留全部既有工作区修改，结束时磁盘约剩 6.4 GiB。

# 本机验证记录 · 2026-10-29（无色排布圆环）

后续按用户授权替换 /Applications/Ordo.app：旧版归档至 build/Archive/20261029-NeutralRing-004830/Ordo.app，候选与安装执行文件 SHA-256 一致，安装后严格验签及开发签名配置验证通过，启动 PID 78028 与完整执行路径核验通过。安装日志保存在 build/NeutralRing-20261029/install.log；本记录安装更新前归档至 build/DocumentArchive/20261029-NeutralRing-Installed/ 并核对 SHA-256。以下构建阶段的“未替换”描述仅适用于安装前；实际圆环玻璃效果仍待目视验收。

八向排布起点圆环移除冰蓝／青蓝染色与人工渐变，macOS 26 使用无染色的系统 Liquid Glass，通过中性白色亮度和原有边缘强调选中方向；旧系统保留中性材质，减少透明度时使用不透明灰白。40 pt 画布、八瓣间隙、中央留空和方向映射保持原样。

- **验证**：新增无色像素回归先在旧实现失败，修改后完整隔离 XCTest 272 项通过、0 失败；仅显式排除真实 AX 窗口用例，不计作通过或权限跳过。既有透明边缘、中央留空及选中瓣变化检查通过；像素检查针对不透明回退，不代表系统玻璃合成的实机验收。未改 AX 或动画时序，未重跑独立 AX 动画脚本。
- **构建**：Debug 测试构建与 Universal 2 Release 构建通过，两个 App 全架构严格验签通过；沿用 Apple Development / ND3SVRRF43、Hardened Runtime、LSUIElement=true，Release 无 App Sandbox entitlement。构建与测试记录在 build/NeutralRing-20261029/，Release 候选位于其 Release/Ordo.app；未替换已安装 App、未提交或发布，实际玻璃外观与旧系统仍待目视验收。
- **保留**：修改前 README 与本记录归档至 build/DocumentArchive/20261029-NeutralRing/ 并核对 SHA-256；保留所有既有未提交修改，复用构建缓存，构建后磁盘约剩 9.7 GiB。

# 本机验证记录 · 2026-10-29（无文字功能演示动画）

README 的三份功能示意 APNG 改为无文字暖黑色样式：背景 `#0C0A09`，窗口采用参考网站深色边栏的 `rgba(28,25,23,0.84)`；仅保留空白窗口、光标、键帽和排布预览／固定起点提示。键帽按住时亮起并轻微下沉、缩小，窗口与指针使用起止速度及加速度为零的五次缓动。移动／缩放由 6 秒缩短至 3 秒，排布由 12 秒缩短至 6 秒，松键后的排布提交仍为 0.2 秒。新版共用可编辑矢量时间轴和浏览器预览，原有 Keynote／GIF 保留为历史素材。

- **格式与循环**：三份 APNG 均为 1920 × 1080、sRGB、无限循环；帧数分别为 180、180、360，逐帧时长均精确为 1/60 秒，所有 PNG 块的 CRC 校验通过。每份连续解码三轮，逐帧哈希完全一致，首帧与末帧相同。
- **内容与动作**：全部场景无文字对象；逐帧检查移动尺寸不变且与光标同位移，缩放左上角固定且宽高变化与光标位移一致；三次排布在松键前保持原窗口并显示目标预览，松键后 0.2 秒到达目标。关键帧目视检查及本机浏览器三份实际 APNG 加载检查通过，图片原始尺寸均为 1920 × 1080。
- **范围与保留**：仅修改演示资源、生成源与相应文档，不改 App 行为，不运行 Xcode／真实 AX 测试，不安装或发布。旧 APNG 与 Keynote 已归档并逐份核对 SHA-256；三份文档已按原路径归档并核对 SHA-256，保留全部既有修改。生成与核验证据位于 build/DemoRestyle-20261029/，验证后候选与最终 APNG 的 SHA-256 一致。结束时磁盘约剩 9.5 GiB；未生成大体积影片或逐帧文件组。

# 本机验证记录 · 2026-10-29（重置快捷键移至右下角）

功能页底部重置快捷键按钮改为右对齐，与卡片内部右边距对齐，保留红色文字、原有操作与无障碍提示。窗口内容区继续固定 560 × 476 pt。关于页动效本轮仅提供建议，没有实现。

- **验证**：6 项隔离布局与窗口集成测试通过；Debug 测试构建、Universal 2 Release 构建、两个 App 全架构严格验签和现有候选配置验证通过。仅改对齐，未重跑完整核心手势及真实 AX 用例。
- **安装**：旧版保留至 build/Archive/20261029-ResetTrailing-001012/Ordo.app，新版安装 /Applications/Ordo.app，候选与安装执行文件 SHA-256 一致，启动 PID 73923 与完整路径核验通过。证据位于 build/ResetTrailing-20261029/；文档事先归档至 build/DocumentArchive/20261029-ResetTrailing/ 并核对 SHA-256。保留全部既有修改，未提交或发布，构建期间磁盘约剩 11 GiB。

# 本机验证记录 · 2026-10-29（动画开关上移与紧凑窗口）

排布动画开关移到启用窗口管理正下方，权限缺失时权限整行继续位于开关下方；第二张卡片只保留三组快捷键。内容区保持 560 pt 宽，由 500 pt 收紧至 476 pt 高，系统标准工具栏另计，三页切换、权限及错误状态不改变窗口大小。原有开关绑定、减少动态效果提示、键帽顺序与按住绿色反馈保留。

- **测量与回归**：先记录三页在 504 pt 内宽下的最小尺寸，最高手动权限状态为 420 pt；加上上下各 28 pt 边距，对应 476 pt 内容高度。旧实现针对新尺寸的回归先失败（实际 500 pt、期望 476 pt），修改后最终 271 项隔离 XCTest 通过、0 失败、0 跳过。深浅色三页、未授权与冲突、登录项待批准与失败、监听失败均在 420 pt 内，固定尺寸及无滚动检查通过。三页实测内容高度分别为基础 158–198 pt、功能 367–420 pt、关于 243 pt；顶部按钮与分页继续采用系统布局并通过既有对齐检查。
- **构建与安装**：Debug 测试构建与 Universal 2 Release 构建、两个 App 全架构严格验签通过。旧版保留至 build/Archive/20261029-CompactOptions-000523/Ordo.app；新版安装 /Applications/Ordo.app，候选与安装执行文件 SHA-256 一致，启动核验 PID 73507 与完整路径通过。证据位于 build/CompactOptions-20261029/。
- **范围与保留**：真实 AX 用例继续显式排除，未改动画或手势实现，未重跑独立 AX 动画脚本。自动几何检查不代替玻璃外观、VoiceOver 或旧系统的实机验收。README、AGENTS 与本记录同步新布局，原文事先归档至 build/DocumentArchive/20261029-CompactOptions/ 并核对 SHA-256。保留全部既有修改，未提交或发布，结束时磁盘约剩 12 GiB。

# 本机验证记录 · 2026-10-28（启用窗口管理仅保留开关）

按用户要求，移除启用窗口管理一行中的运行状态图标及文字，包括正在运行、已暂停、等待授权等，仅保留标题和启用开关。清除只用于这些显示的私有计算属性，并同步首次授权说明。保留权限引导、错误和冲突提示、菜单栏图标运行状态及原有控制逻辑。

- **检查**：6 项隔离布局与窗口集成测试通过；Debug 测试构建、Universal 2 Release 构建、两个 App 全架构严格验签和现有候选配置验证通过。仅调整显示，未重跑完整手势或真实 AX 用例。
- **安装**：旧版保留至 build/Archive/20261028-EnabledSwitchOnly-235913/Ordo.app，新版安装到 /Applications/Ordo.app，候选与安装文件的执行文件 SHA-256 一致，启动 PID 72862 与实际路径核验通过。证据位于 build/EnabledSwitchOnly-20261028/；文档改写前归档至 build/DocumentArchive/20261028-EnabledSwitchOnly/ 并核对 SHA-256。保留全部既有改动，未提交或发布，结束时磁盘约剩 11 GiB。

# 本机验证记录 · 2026-10-28（移除登录项未找到提示）

按用户要求，移除基础页中登录项 notFound 对应的文字提示，仅以开机自启开关关闭展示该状态。保留原有系统状态映射、等待批准及注册失败反馈；未操作真实登录项。

- **验证**：28 项布局及控制器生命周期测试通过，包括四种登录项系统状态与开关映射；Debug 测试构建、Universal 2 Release 构建和两个 App 全架构严格验签通过。仅移除显示文本，没有重跑完整手势或真实 AX 测试。测试日志保留既有 AppKit 布局重入提示。
- **安装**：归档旧版至 build/Archive/20261028-LoginNotice-235655/Ordo.app，安装 /Applications/Ordo.app 后再次验证签名与配置；执行文件与候选 SHA-256 一致，启动核验 PID 72525 及实际路径通过。证据位于 build/LoginNotice-20261028/，文档事先归档至 build/DocumentArchive/20261028-LoginNotice/ 并核对 SHA-256。保留既有改动，未提交或发布，结束时磁盘约剩 11 GiB。

# 本机验证记录 · 2026-10-28（功能页修饰键绿色反馈）

功能页获得窗口焦点时，按住 ⇧、⌃、⌥、⌘ 会使三个条目中的对应键帽临时显示绿色，优先于已选蓝色及未选灰色；支持多键同时按住，松开后逐键恢复。退出该页或失焦时清空状态，返回时重新读取当前修饰键。仅观察当前应用内的 flagsChanged 事件并原样返回，不新增权限，不改变全局 Event Tap、快捷键组合或持久化设置，不记录输入。macOS 26 使用玻璃键帽，macOS 14–25 使用标准边框按钮，按住未选键同样绿色。

- **测试**：先添加尚未实现的类型回归测试，编译按预期失败；实现后最终 271 项隔离 XCTest 通过、0 失败、0 跳过。新增三项状态测试覆盖支持键过滤、多键按住及逐个松开、非活动状态与离页清除，以及三组快捷键中按住态覆盖已选和未选态。真实 AX 用例显式排除；没有向系统注入按键。
- **构建与安装**：Debug 测试构建与 Universal 2 Release 构建、两个产物全架构严格验签通过，候选通过既有开发签名与配置校验。旧版保留至 build/Archive/20261028-PressedKeyFeedback-234951/Ordo.app，安装至 /Applications/Ordo.app，候选与安装文件的执行文件 SHA-256 一致，启动 PID 71919 和实际路径核验通过。
- **范围**：证据位于 build/PressedKeyFeedback-20261028/。状态测试不替代真实键盘事件与绿色玻璃外观、窗口失焦恢复、VoiceOver、macOS 14–25 实机验收，以上仍待实机确认。未改 AX 实现，未重跑独立 AX 动画脚本；文档改写前归档至 build/DocumentArchive/20261028-PressedKeyFeedback/ 并核对 SHA-256。保留已有修改，未提交或发布，构建期间磁盘约剩 12 GiB。

# 本机验证记录 · 2026-10-28（键帽位置顺序）

按用户选择，三项功能的键帽从左到右统一改为 ⇧ ⌃ ⌥ ⌘。仅调整界面枚举顺序，保留组合值、逐键配色、校验及辅助功能整行隐藏行为。

- **检查**：6 项隔离布局与窗口集成测试通过；Debug 测试构建与 Universal 2 Release 构建、两个 App 全架构严格验签通过，Release 继续通过生命周期工具的开发签名与配置验证。此为显示顺序调整，未重跑完整核心测试或真实 AX 用例；实际玻璃外观与 VoiceOver 顺序仍待实机确认。
- **安装**：旧版保留至 build/Archive/20261028-KeyboardOrder-234225/Ordo.app，新版安装至 /Applications/Ordo.app，候选及安装文件的执行文件 SHA-256 一致，启动核验 PID 71233 及完整路径通过。证据位于 build/KeyboardOrder-20261028/。文档改写前归档到 build/DocumentArchive/20261028-KeyboardOrder/ 并核对 SHA-256。保留所有既有改动，未提交或发布，结束时磁盘约剩 12 GiB。

# 本机验证记录 · 2026-10-28（移除整行蓝色强调）

用户实机反馈上一轮仍然所有键呈蓝色；此前没有完成最终玻璃外观验收。本次检查发现整行仍保留 tint(.blue)，会向全部键帽传递强调色。现移除整行 tint，逐键依据当前组合设置蓝色或灰色；自定义玻璃样式内部同样明确选中蓝色、未选灰色和默认文字。实际保存的三组组合依次为 10、5、12，即 ⌥⇧、⌘⌃、⌃⇧，每组仅两个键，没有修改用户组合。

- **验证**：268 项隔离测试通过、0 失败、0 跳过；真实 AX 用例显式排除。Debug 测试构建与 Universal 2 Release 构建、全架构严格验签通过。保留辅助功能整行随权限隐藏与恢复。
- **安装**：旧版保留至 build/Archive/20261028-KeyTintFix-233600/Ordo.app；新候选验签后安装到 /Applications/Ordo.app，执行文件与候选 SHA-256 一致，启动核验 PID 70673、路径 /Applications/Ordo.app/Contents/MacOS/Ordo。证据保留在 build/KeyTintFix-20261028/。
- **边界**：界面工具仍将完整安装路径解析为旧应用身份，刷新该路径注册信息后依然未能绑定窗口，因此未将构建、测试或启动核验表述为蓝色玻璃最终外观通过；仍需用户实机目视确认。文档已预先归档到 build/DocumentArchive/20261028-KeyTintFix/ 并核对 SHA-256。

# 本机验证记录 · 2026-10-28（纠正选中键与整行权限隐藏）

本条取代上一轮功能页说明：每项功能当前选中的修饰键明确绘制蓝色键帽底及白色符号，未选键维持普通玻璃；辅助功能已授权时整行与分隔线一并移除，撤权后恢复。窗口仍固定 560 × 500 pt。

- **回归与构建**：先增强权限切换布局回归，旧实现因授权前后高度差 0 pt 而失败；修正后完整隔离 XCTest 268 项通过、0 失败、0 跳过。确认未授权内容比授权状态至少增加一行，恢复授权后回到原高度。Debug 测试构建、独立 Release 构建与两个产物全架构严格验签通过，Release 通过现有生命周期工具的团队、开发签名及配置验证。真实 AX 用例仍显式排除。
- **安装**：正常退出旧进程后，将 /Applications/Ordo.app 归档到 build/Archive/20261028-FeatureKeysCorrection-233119/Ordo.app，再安装独立候选并验签。新旧候选的可执行文件 SHA-256 对比确认安装内容更新；安装文件与本次候选一致。启动核验 PID 70215，实际路径 /Applications/Ordo.app/Contents/MacOS/Ordo。
- **边界与证据**：build/FeatureKeysCorrection-20261028/ 保存红测试、Tests.xcresult、截图、构建和安装日志。离屏截图玻璃层缺失，不能作为最终外观验收；界面工具对当前应用身份存在旧缓存及多副本歧义，未据此操作其他副本。蓝色玻璃实机外观、VoiceOver、旧系统和真实手势仍待目视及交互验收。文档改写前归档并核对 SHA-256；保留所有已有改动、旧版与旧验证记录，未提交或发布；结束时磁盘约剩 12 GiB。

# 本机验证记录 · 2026-10-28（功能页键帽与权限按钮）

已选快捷键键帽显式使用蓝色，未选保持原生中性样式。默认两个修饰键不再通过禁用控件而褪色，原有绑定校验仍阻止无效组合，并补充至少保留两个修饰键的无障碍提示。辅助功能已授权时保留状态、隐藏操作按钮；未授权及撤权后显示重新检查和授权，不自动弹出系统授权提示。

- **验证**：最终隔离 XCTest 268 项通过、0 失败、0 跳过；新增授权、撤权、恢复时固定尺寸和内容高度检查。真实 AX 用例显式排除，不计入通过。Debug 测试构建与 Release 构建通过，两个最终 App 全架构严格验签通过，保持 Apple Development / ND3SVRRF43、Hardened Runtime、LSUIElement=true，且无 App Sandbox entitlement。
- **界面边界**：离屏附件确认已授权行仅留状态、页面未裁切；截图不完整包含系统玻璃合成层，蓝色玻璃外观、VoiceOver 和 macOS 14–25 实机仍待验收。初次无障碍树断言无法读取 SwiftUI 控件，已改为权限切换布局回归，该次诊断失败不作为行为复现证据。未修改手势或 AX 实现，独立 AX 动画回归未重跑。
- **证据与保留**：build/FeatureKeys-20261028/ 保存 FinalTests.xcresult、FinalAttachments、构建及签名日志，Release/Ordo.app 为独立候选。文档原件归档至 build/DocumentArchive/20261028-FeatureKeys/ 并核对 SHA-256。复用现有缓存，结束时可用空间约 12 GiB；保留已有改动，未提交、安装或发布。

# 本机验证记录 · 2026-10-28（深色底与九块纯白扁平图标）

按新要求试用扁平设计：默认与深色背景均为 `#121212`，九个块均为纯白，保留八向轮廓、224 × 224 的中心块及其圆角。三层关闭玻璃、高光、透光与投影，移除折射；SVG 不包含渐变。Icon Composer 的底板外缘仍有系统合成反光，当前没有将其误记为完全无光照的平面输出。菜单栏资源和应用行为未修改。

- **检查**：确认恰好九块、三份设计 SVG 与运行资源逐字节一致，JSON 解析及 diff 空白检查通过。默认／深色 512 px、32 px、Design Generation 26 及系统着色预览已重新生成；系统着色主题仍可重新赋色。资源变更未运行 XCTest 或真实 AX 测试。
- **构建**：独立 Universal 2 Release 构建成功，所有架构严格验签通过，保留团队 `ND3SVRRF43` 的 Apple Development、Bundle ID、Hardened Runtime、`LSUIElement=true` 与无 App Sandbox entitlement。产物与日志在 `build/IconFlat-20261028/`；未安装、提交或发布。
- **归档**：上一版黑白玻璃图标和八张预览保存在 `build/IconFlat-20261028/Original/`；三份文档归档至 `build/DocumentArchive/20261028-IconFlat/` 并核对 SHA-256。无效的底板试验 SVG 也移入本轮构建目录保留，未删除文件。既有界面与测试未提交改动均保留；磁盘剩余约 13 GiB。真实桌面和旧系统外观未验收。

# 本机验证记录 · 2026-10-28（黑白底玻璃主图标）

主图标沿用 Icon Composer 分层 SVG：背景改为默认纯白、深色纯黑，移除蓝色渐变与强调瓣色差；保留八向轮廓，中央圆角块从 300 × 300 缩为 224 × 224，圆角从 72 缩为 54（1024 画布）。块面使用无彩色填充、系统高光、90% 透光及中性阴影，新一代配置启用折射；SVG 本身无渐变或烘焙光影。菜单栏、手势与主窗口实现未在本轮修改。

- **渲染检查**：Apple Icon Composer 导出默认／深色 512 px、32 px、Design Generation 26 默认／深色和系统着色外观共八张预览，检查八瓣分离、缩小后的中心及高光边缘。26 渲染外观仅为兼容参考，不代表旧系统实机验证；系统着色可按用户主题重新赋色。预览位于 `Artwork/AppIconPreviews/`，README 改用本轮默认预览。纯白背景上的透明玻璃对比较低，小尺寸可辨识度仍需用户实际观察。
- **构建与签名**：独立 Universal 2 Release（arm64、x86_64）构建成功，全部架构严格验签通过；Apple Development 团队 `ND3SVRRF43`、Bundle ID `com.ghoooooost.Ordo`、Hardened Runtime、`LSUIElement=true` 与无 App Sandbox entitlement 保留。初次受限验签无法取得系统信任链，获得系统访问后严格验证通过。构建仅有未依赖 AppIntents 的元数据提取提示。
- **范围**：本轮为图标资源修改，未运行 XCTest、真实 AX 或桌面交互测试；未安装、提交或发布。当前工作区此前已有界面与文档改动，均保留。构建产物 `build/IconGlass-20261028/Release/Ordo.app` 包含该工作区状态，不能视作本轮单独功能验证。
- **保留与检查**：旧主图标完整保存在 `build/IconGlass-20261028/Original/AppIcon.icon`；三份文档修改前归档到 `build/DocumentArchive/20261028-IconGlass/` 并核对 SHA-256。JSON 解析、无渐变配置、三份 SVG 设计源与运行资源逐字节同步、diff 空白检查均通过。磁盘可用空间约 13 GiB；未清理或删除文件。实际桌面动态图标光照、深色主题选择与旧系统外观待实机确认。

# 本机验证记录 · 2026-10-23（参考日历的分页高度与窗口按钮对齐）

只读观察本机 macOS 日历的分页按钮与左上角窗口控制按钮后，将 AppKit 和 SwiftUI 场景的工具栏从紧凑样式改为标准 `unified`，继续隐藏标题。原生控件负责高度、留白与系统按钮位置，没有手动移动窗口控制按钮。当前 macOS 27.0.1 实测分页胶囊高 **36 pt**、工具栏高 **52 pt**、上下各 **8 pt** 留白；三个窗口控制按钮与分页中心线一致。可用内容区仍为 **560 × 500 pt**，整个窗口固定为 560 × 552 pt；不恢复独立的“Ordo”标题行。尺寸是当前系统快照，旧系统仍由原生样式布局。

- **回归**：旧紧凑配置先在两项窗口测试中产生 2 处预期失败；同步调整两层工具栏配置后，完整隔离 XCTest **267 项通过、0 失败、0 跳过**。三页及错误状态、深浅色、关闭重开均检查标准高度、上下留白和三个窗口按钮的中心线（误差最多 1 pt），同时保留固定内容区、无滚动、窗口复用与键盘切页检查。实际 SwiftUI Scene 的四次几何记录均为分页 `(163, 508, 234, 36)`、关闭按钮 `(19, 519, 14, 14)`，单位为窗口坐标 pt。
- **构建与签名**：Debug（arm64）和 Universal 2 Release（arm64、x86_64）构建、全部架构严格验签与开发证书链核验通过。沿用 Apple Development / `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`、当前 Bundle ID、最低 macOS 14 和无 App Sandbox entitlement。构建缓存旧产物路径及既有 AppKit 布局提示保留在日志中。
- **验收边界**：日历参考只观察工具栏，没有操作日历设置或内容。Ordo 的检查使用隔离测试宿主和几何记录；离屏截图仍不完整包含玻璃合成层，实际玻璃外观、VoiceOver、辅助功能外观和旧版 macOS 实机验证仍待人工确认。真实 AX 用例继续显式排除，不计作通过或权限跳过；未改动手势或 AX 实现，独立 AX 动画脚本未重跑。
- **本机证据**：`build/ToolbarHeight-20261023/` 保存修改前基线、红测试、`Tests.xcresult`、测试摘要、几何与截图附件、构建和验签日志，产物位于其 `Debug/Ordo.app` 与 `Release/Ordo.app`。文档修改前归档至 `build/DocumentArchive/20261023-ToolbarHeight/` 并核对 SHA-256；复用已有构建缓存，保留此前未提交修改及验证产物，未提交、发布或替换已安装 App。

# 本机验证记录 · 2026-10-23（移除独立标题行）

按本轮要求移除单独显示“Ordo”的标题行，窗口控制按钮与纯文字分页胶囊共用一行。AppKit 使用 `unifiedCompact` 并隐藏标题，SwiftUI 场景同步使用 `.unifiedCompact(showsTitle: false)`，避免场景更新恢复标题。窗口名称仍为“Ordo”，供系统识别与无障碍使用；可用内容区仍固定 **560 × 500 pt**，现有分组卡片、玻璃控件与设置行为保留。未提交、发布或替换已安装 App。

- **测试先行**：调整现有窗口回归后，旧实现的两项测试产生 3 处预期失败。仅修改 AppKit 后，真实 SwiftUI Scene 在三页和重开时仍恢复标题，产生 4 处失败；同步场景配置后，完整隔离 XCTest **267 项通过、0 失败、0 跳过**。
- **布局验证**：三页切换、关闭重开、七种状态的深浅色组合及监听失败均检查标题隐藏、单行工具栏、分页与关闭按钮在同一窗口坐标中的垂直对齐（误差不超过 4 pt）；继续检查 560 × 500 pt 可用内容、页面高度、无滚动视图及窗口复用。最终截图确认没有独立标题行。离屏截图仍不能完整记录系统玻璃合成，不能作为真实玻璃材质与选中态的验收。
- **构建与签名**：独立 Debug（arm64）和 Universal 2 Release（arm64、x86_64）构建、全部架构严格验签及开发证书链核验通过。保持团队 `ND3SVRRF43` 的 Apple Development、`com.ghoooooost.Ordo`、Hardened Runtime、`LSUIElement=true`、最低 macOS 14 和无 App Sandbox entitlement。测试报告无运行时警告；控制台既有的一次性 AppKit 布局重入提示与构建缓存旧路径提示已留存，没有因提示降低检查要求。
- **范围**：显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不计作通过或权限跳过。未改动生产手势或 AX 实现，未重跑独立 AX 动画脚本；真实玻璃合成、VoiceOver、系统辅助功能外观及旧系统实机兼容仍待人工验收。
- **本机证据**：`build/SingleHeader-20261023/` 保留修改前基线、红测试、`FinalTests.xcresult`、测试摘要、截图、构建和验签日志，独立产物位于其 `Debug/Ordo.app` 与 `Release/Ordo.app`。修改文档前归档至 `build/DocumentArchive/20261023-SingleHeader/` 并核对 SHA-256；沿用已有 DerivedData，没有清理旧文件或覆盖已有验证产物。

# 本机验证记录 · 2026-10-21（Liquid Glass 分组卡片与玻璃控件）

主窗口三页改为不透明分组卡片承载内容，玻璃只用于导航与可交互控件：快捷键键帽在 macOS 26+ 共用 `GlassEffectContainer`，选中为强调色玻璃，未选中为普通玻璃；“重新检查”“授权”“打开登录项设置”“GitHub 项目”改为系统玻璃按钮。macOS 14–25 回退为标准按钮。行为、偏好键、无障碍标识、固定 **560 × 500 pt** 内容区与分页工具栏均未改变；排布预览、起点标志和菜单栏未修改。版本保持 **1.0.1（2）**，未提交、发布或替换已安装 App。

- **回归证据**：改动前主窗口布局、窗口行为与集成测试共 32 项基线通过；改动后完整隔离 XCTest **267 项通过、0 失败、0 跳过**。七种状态 × 深浅色及监听失败仍满足内容安全区域、页面所需高度 ≤ 444 pt 和无滚动视图检查。
- **离屏截图发现**：独立放置的 `.glassProminent`“授权”按钮会使 `cacheDisplay` 离屏截图整页缺失（仅未授权状态，已用对照实验确认）。改为与“重新检查”共用 `GlassEffectContainer` 后七种状态均完整捕获。这只证明离屏捕获恢复，不能代表实际合成效果。
- **截图与人工范围**：离屏截图不包含玻璃合成层，按钮底、键帽选中着色及深色模式下玻璃上的文字颜色均无法据此判断。真实玻璃外观、键帽选中／禁用态对比、减少透明度、VoiceOver 读出键帽选中状态、键盘 Tab 路径，以及 macOS 14–25 回退外观仍待人工确认；本机为 macOS 27，未实测旧系统。
- **真实 AX**：本轮未改动 AX 与手势代码，显式排除 `AXWindowCompatibilityTests.testCurrentProcessSwiftUIWindowCanBeCapturedRaisedMovedAndResized`，不计作通过或权限跳过；独立 AX 动画脚本未重跑。
- **构建与签名**：Debug 与 Release 构建通过，UI 源文件无编译警告；Release 产物严格验签通过，团队 `ND3SVRRF43`、Hardened Runtime、`LSUIElement=true`，无 App Sandbox entitlement。
- **本机证据**：`build/LiquidGlassValidation-20261021/`（完整测试与构建日志、基线／对照／最终截图附件）；产物位于 `build/Verification/Debug`、`build/Verification/Release`。修改前的文档归档于 `build/DocumentArchive/20261021-LiquidGlassCards/`，原文件与副本 SHA-256 已核对。

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
