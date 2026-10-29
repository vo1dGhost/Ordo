# Ordo 图标素材

本目录保存主 App 图标的设计素材、菜单栏图标预览及排布起点标志的外观检查图。应用使用的图标源文件位于 `Ordo/`；构建、更新和验证流程见[项目说明](../README.md)，修改约束见[仓库协作约定](../AGENTS.md)。

## 品牌与视觉字标

正式品牌名为 **Ordo**，视觉字标写作 **ØRDO**，延续 Ø / 空集的视觉语言。字标适用于 Logo、海报、宣传封面等品牌展示；文档正文、图片替代文本和无障碍标签使用 Ordo，便于阅读与检索。

宣传素材使用“Ordo — Window Manager for Mac”或“Ordo — Mac 窗口管理与快捷布局”，标语使用“Every window, in its place.”或“让每个窗口，各得其所。”。中文辅助名“格序 / 窗序”仍为候选；完整规则见[品牌命名规范](../docs/BRANDING.md)。

本节约定字标与文案的使用方式。当前主图标、菜单栏图标和排布起点标志仍使用下述资源；本轮仅更新文档，尚未制作独立字标文件或重制演示素材。

## 主 App 图标

沿用 `02_FocusedSnap` 的中央窗口与八向分瓣轮廓，当前试用深色底与九个纯白块的扁平设计：默认与深色外观均使用 `#121212` 背景，九个块均为 `#FFFFFF`，不区分强调瓣。中央块保留 224 × 224、圆角 54（1024 画布）。正式图标由 [AppIcon.icon](../Ordo/AppIcon.icon/icon.json) 中的分层 SVG 和配置组成；各层关闭玻璃、高光、透光与投影，移除折射配置。系统仍可能在图标底板外缘合成轻微反光。

| 目录 | 用途 |
| --- | --- |
| [AppIconConcepts/01_EqualFacets](AppIconConcepts/01_EqualFacets/) | 等权分瓣概念稿，保留为设计过程参考。 |
| [AppIconConcepts/02_FocusedSnap](AppIconConcepts/02_FocusedSnap/) | 已采用方向的概念预览。 |
| [AppIconConcepts/03_OrbitWindows](AppIconConcepts/03_OrbitWindows/) | 环绕窗口概念稿，保留为设计过程参考。 |
| [02_FocusedSnap/IconComposerPreviews](AppIconConcepts/02_FocusedSnap/IconComposerPreviews/) | Icon Composer 的默认、深色、透明、着色外观及小尺寸预览；`compiled-release.png` 用于查看编译产物外观。均为渲染参考，不是图标源。 |
| [AppIconSources](AppIconSources/) | 三层 SVG 设计源副本，当前与 [AppIcon.icon/Assets](../Ordo/AppIcon.icon/Assets/) 下的同名文件逐字节一致。 |

三层分别是 `01_WindowCore.svg`（中央窗口）、`02_OrderRing.svg`（分瓣环）和 `03_ActiveFacet.svg`（强调瓣）。调整几何时同步两处同名 SVG；材质与各外观配置由 `AppIcon.icon/icon.json` 管理。

[AppIconPreviews](AppIconPreviews/) 保存当前扁平版的 Apple Icon Composer 渲染预览：默认／深色 512 px、32 px、Design Generation 26 和系统着色外观。系统着色模式可根据主题重新赋色。此前概念目录下的蓝色预览保留为历史参考，上一版黑白玻璃图标及预览已归档于本机构建目录。`03_ActiveFacet.svg` 仍沿用原文件名，但与其余七瓣均为纯白。

## 菜单栏图标

菜单栏采用独立为小尺寸绘制的单色八向分瓣环与中央窗口，不直接缩小主 App 图标。两份源文件均为 18 × 18 pt，透明背景；外环相同，运行态中心实心，未运行态中心空心。

- [MenuBarIconActive.svg](../Ordo/Resources/Assets.xcassets/MenuBarIconActive.imageset/MenuBarIconActive.svg)：`controller.isOperational` 为 `true` 时使用，无障碍标签为“Ordo 正在运行”。
- [MenuBarIconInactive.svg](../Ordo/Resources/Assets.xcassets/MenuBarIconInactive.imageset/MenuBarIconInactive.svg)：`controller.isOperational` 为 `false` 时使用，无障碍标签为“Ordo 未运行”。

两个 imageset 的 `Contents.json` 均启用 `template-rendering-intent: template` 与 `preserves-vector-representation: true`。继续保留 SVG 矢量与系统模板着色，不烘焙阴影、背景或菜单栏前景颜色；浅色、深色及菜单展开高亮由系统处理。

[MenuBarIcon](MenuBarIcon/) 下的 PNG 是从真实 App bundle 的图像资源渲染得到的检查产物：`active-18px.png`、`inactive-18px.png` 对应 1×，`active-36px.png`、`inactive-36px.png` 对应 2×；[preview.png](MenuBarIcon/preview.png) 汇总浅色、深色、状态和放大对照。它们是模拟预览，不是真机菜单栏截图，也不能回灌为图标源。

修改菜单栏资源后，检查 18/36 px 的分瓣间隙、中央空心与裁切，以及真实菜单栏的模板着色、高亮和状态切换；预览不能替代实机视觉验收。

## 排布起点标志

排布手势的定位标志以 SwiftUI 矢量绘制，正式实现位于 [SnapPreviewView.swift](../Ordo/UI/SnapPreviewView.swift)。40 × 40 pt 画布内只保留约 32 pt 的八向圆角梯形环，中央保持透明；默认冰蓝等亮，当前布局方向使用青蓝高亮和加强描边。

`SnapOriginMarkerView` 读取系统辅助功能设置，`SnapOriginMarkerArtwork` 绘制外观，`SnapOriginMarkerFacet` 定义每瓣路径。macOS 26 使用系统玻璃，macOS 14–25 使用 Material；“减少透明度”启用时使用不透明配色。主图标、菜单栏 SVG 与起点标志各自维护。

[OriginMarker](OriginMarker/) 中的 `marker-方向-1x.png` 和 `marker-方向-2x.png` 为正式绘制代码导出的 40/80 px **减少透明度外观**。[对照图](OriginMarker/opaque-preview-2x.png) 展示明暗、复杂背景、八向状态与 3× 放大检查。这些 PNG 用于核验，不作为 App 运行资源。

系统玻璃需要在原生宿主窗口中观察。本机 `ImageRenderer` 导出玻璃时出现与原生窗口不符的圆形背景，不能据此判断最终材质；因此此目录仅保留可核验的不透明回退导出。实际手势中的固定起点、方向过渡、背景适应和系统中断恢复需单列实机验收。

## 功能演示动画

[Demos](Demos/) 保存三个功能的深色示意动画，并非 App 实录。同名 `.apng` 是项目 README 引用的当前输出。新版矢量场景与时间轴统一写在 [demo-scene.mjs](Demos/demo-scene.mjs)，[preview.html](Demos/preview.html) 可通过本地 HTTP 服务预览。`move.key`、`resize.key`、`snap.key` 与 `.gif` 保留为旧版历史素材，未同步本轮样式，不再作为当前 APNG 的生成源。

APNG 统一为 **1920 × 1080、60 fps、sRGB、无限循环**，每帧时长精确为 1/60 秒；移动和缩放各 **3 秒（180 帧）**，排布 **6 秒（360 帧）**，均为旧版时长的一半。场景原生采用 16:9 构图，README 展示宽度仍为 800 px，窄屏等比例缩小。

画面不含标题、品牌、状态说明或窗口内文字，仅保留空白窗口、光标、组合键键帽与排布预览／起点提示。组合键顺序采用 ⇧⌃、⇧⌥、⌃⌘。按住时键帽平滑亮起并轻微下沉、缩小；松开恢复。窗口、光标和预览采用五次缓动，起止速度及加速度为零，首尾保留相同静止画面。

配色采样于[参考网站](https://115.191.33.180/blog/chinese-copywriting-guidelines)的深色模式（2026-10-29）：背景 `#0C0A09`，边栏 `rgba(28,25,23,0.84)`。窗口沿用该边栏填充与透明度，键帽及预览使用同组暖灰与米白。

更新时运行 `node scripts/render-demos.mjs [输出目录]`，使用本机已有的 Sharp 与 FFmpeg 逐帧渲染矢量场景并补写 sRGB 标记；不安装依赖、不生成大体积中间影片，默认输出至已忽略的构建目录。`NODE_PATH` 可指向已有 Sharp 安装位置。核验后再替换 README 使用的三份 APNG，替换前归档旧资源并核对 SHA-256。

交付前核对 APNG 的帧数、1/60 秒帧时序和无限循环标记，连续解码三轮并比较首尾画面；复查组合键和松键时机、缩放时左上角固定，以及排布选择期间仅预览、松键后用 0.2 秒应用布局。渲染源与浏览器预览共用时间轴；示意动画不代替真实 App 的交互或性能验收。
