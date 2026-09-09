# Ordo 图标素材

本目录保存主 App 图标的设计素材、菜单栏图标预览及排布起点标志的外观检查图。应用使用的图标源文件位于 `Ordo/`；构建、更新和验证流程见[项目说明](../README.md)，修改约束见[仓库协作约定](../AGENTS.md)。

## 主 App 图标

最终采用 `02_FocusedSnap` 方向：中央窗口、八向分瓣环与强调瓣。正式图标由 [AppIcon.icon](../Ordo/AppIcon.icon/icon.json) 中的分层 SVG 和 Icon Composer 材质配置组成，保留系统玻璃、透光和高光效果，不以扁平 PNG 替代。

| 目录 | 用途 |
| --- | --- |
| [AppIconConcepts/01_EqualFacets](AppIconConcepts/01_EqualFacets/) | 等权分瓣概念稿，保留为设计过程参考。 |
| [AppIconConcepts/02_FocusedSnap](AppIconConcepts/02_FocusedSnap/) | 已采用方向的概念预览。 |
| [AppIconConcepts/03_OrbitWindows](AppIconConcepts/03_OrbitWindows/) | 环绕窗口概念稿，保留为设计过程参考。 |
| [02_FocusedSnap/IconComposerPreviews](AppIconConcepts/02_FocusedSnap/IconComposerPreviews/) | Icon Composer 的默认、深色、透明、着色外观及小尺寸预览；`compiled-release.png` 用于查看编译产物外观。均为渲染参考，不是图标源。 |
| [AppIconSources](AppIconSources/) | 三层 SVG 设计源副本，当前与 [AppIcon.icon/Assets](../Ordo/AppIcon.icon/Assets/) 下的同名文件逐字节一致。 |

三层分别是 `01_WindowCore.svg`（中央窗口）、`02_OrderRing.svg`（分瓣环）和 `03_ActiveFacet.svg`（强调瓣）。调整几何时同步两处同名 SVG；材质与各外观配置由 `AppIcon.icon/icon.json` 管理。

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

[Demos](Demos/) 保存三个功能的深色示意动画，并非 App 实录。`move.key`、`resize.key`、`snap.key` 分别是自由移动、调整大小和八向排布的可编辑 Keynote 源文件，使用原生对象、“神奇移动”和自动过渡；同名 `.gif` 是项目 README 引用的演示输出。

GIF 统一为 960 × 600、20 fps、无限循环；移动和缩放各 6 秒，排布 12 秒。更新时在 Keynote 中修改对象、神奇移动与自动过渡时序，通过原生“动画 GIF”导出，再统一输出尺寸、帧率与循环设置。复查首尾状态一致、组合键和松键时机，以及缩放时左上角固定、排布选择期间仅预览。
