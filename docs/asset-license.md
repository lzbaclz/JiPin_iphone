# 极拼首版素材来源与授权清单

首版模板、贴纸、背景和滤镜均为项目原创程序化资源，随安装包提供，不依赖远程下载。

| 类型 | 数量 | 来源 | 分发说明 |
| --- | --- | --- | --- |
| 基础网格与分屏布局 | 46（验收要求 ≥30） | 几何布局定义，无第三方图形 | 可随 App 分发 |
| 海报模板 | 20 | 原创版式与文案占位 | 可随 App 分发 |
| 贴纸与形状 | 60 贴纸 + 10 几何形状（含箭头） | SF Symbols 与原创矢量形状 / 文字徽章 | SF Symbols 按 Apple 人机界面指南随系统字体/符号使用；徽章文案为原创 |
| 背景预设 | 20 | 原创纯色、渐变与轻纹理绘制 | 可随 App 分发 |
| 滤镜预设 | 10 | Core Image 系统滤镜组合 | 系统框架，无额外授权 |
| 字体 | 系统 UI 字体（含圆体、衬线、等宽） | Apple 系统字体 | 首版不做在线字体商店，不内嵌第三方字体文件 |
| 试用插画 | 6 | `Apps/JiPin/StudioPreviews.swift` 原创图形绘制 | 海岸、树林、建筑、沙丘、咖啡与山景；不包含用户照片 |

未使用未授权的第三方照片、插画或品牌素材。若后续引入外部 IP 或可下载字体，需单独补充授权文件后再入库。

模板与素材的可读参数见 [设计目录](design-source/catalog.json)，由 `scripts/export-design-assets.sh` 从当前 Swift 源码导出，用于设计审阅与交接。运行时仍以 `LayoutEngine.swift`、`PosterTemplates.swift` 和 `AssetCatalogs.swift` 为准，修改后应重新导出。海报和贴纸的界面缩略图使用同一渲染器生成。纸纹使用固定种子，重复预览和导出的图案一致。

## App 图标

- 使用文件：`Apps/JiPin/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`。
- 生成方式：内置 imagegen，按极拼的珊瑚橙品牌方向生成照片叠放图案。
- 原始生成文件：`exec-b3feec06-ce2a-456d-b7dc-ae6517550562.png`，保留在生成工具的输出目录。
- 项目资源：1024 × 1024、RGB PNG、无 alpha 通道、嵌入 sRGB 色彩配置；背景铺满方形，圆角交给系统处理。
- 接入方式：沿用现有 `AppIcon` 资源集及 `ASSETCATALOG_COMPILER_APPICON_NAME` 设置，替换原图。
- 图像生成后仅做项目所需的尺寸调整与色彩配置写入，没有使用第三方品牌图标作为输入。

图标尺寸与系统遮罩参考 [Apple App 图标设计说明](https://developer.apple.com/design/human-interface-guidelines/app-icons)。

### 生成提示词

```text
Use case: logo-brand.
Asset type: production iOS app icon for an original photo-collage app named JiPin / 极拼. The name is context only; DO NOT render any letters or words.
Primary request: design one exceptionally attractive, instantly recognizable, premium creative-photo app icon that feels professionally art-directed and is legible at a small iPhone Home Screen size. Replace a rudimentary four-square orange icon with a more memorable photo-collage identity.
Existing brand direction: vivid coral-orange #FF5A36, warm ivory, apricot and a restrained golden highlight. Stay in this coherent warm palette.
Composition: a single large central sculpted collage emblem made from three overlapping rounded photo panels. The main front ivory photo frame contains an elegant asymmetrical mosaic of coral, apricot and golden image-like shapes, with precise, generous ivory separators. A second ivory-backed photo panel peeks out at a slight angle behind it, suggesting gathering multiple photos into one composition. Create a strong clean silhouette and just enough depth and overlap to feel tactile. Keep the motif compact and visually balanced, occupying roughly 72 percent of the square. Use simple broad surfaces that remain clear at 60 pixels, not tiny drawn photographs.
Background: rich luminous coral-orange, a carefully controlled warm gradient with a subtle brighter upper-left glow and slightly deeper red-orange lower-right. Background must extend to ALL four edges and ALL four corners of the square.
Style: polished contemporary iOS icon, precise rounded geometry, premium soft enamel / layered paper finish, restrained dimensional lighting, crisp edges, beautiful warm-white contrast. Sophisticated and friendly, not busy or childish. Clean front view with subtle layering, no scene perspective.
Constraints: exactly one square 1024 x 1024 icon artwork; fully opaque RGB visual; NO transparency, NO baked-in outer rounded square or external frame, NO surrounding white margin, NO device mockup, NO Home Screen, NO text, NO letters, NO watermark, NO sparkles, NO magic wand, NO camera lens, NO existing company logo. iOS applies the outer corner mask itself. Deliver only the finished full-bleed square asset.
```

## V2 风格与研究资料

六套风格参数为本项目原创搭配，使用原有自绘示例插画预览。竞品研究只引用公开功能事实、评分与转述评价，没有将竞品贴图、字体或品牌 IP 放入 App。研究事实快照不包含整批评论正文。

## V3 原创可爱与酷感素材

- 绘制定义：`Packages/JiPinCore/Sources/JiPinCore/OriginalStickerArt.swift` 与 `DecorationFrames.swift`，属于本项目原创代码素材。
- 16 个可爱贴图：软软兔、奶油熊、橘子喵、甜心草莓、樱桃双双、奶糖蝴蝶结、微笑雏菊、棉花云、晚安星月、心动来信、焦糖布丁、珍珠奶茶、水蜜桃桃、雨后彩虹、薄荷糖果、生日小蛋糕。
- 2 个酷感贴图：闪电徽章、星际飞行。
- 6 款画布边框：奶油花边、草莓糖纸、樱花信笺、薄荷格纹、星星梦境、蝴蝶结礼物。
- 素材采用通用动物、食物、植物与几何主题，没有下载或复刻竞品贴纸、字体或授权角色。设计参考仅为成套配色、分类和复用的方法。
- 交付 PNG 为本项目矢量代码生成；单件透明背景，白色描边是贴图自身的一部分。总览文字使用系统字体；App 素材本身不依赖字体。
- 可重新生成文件和实际使用 ID 见 `scripts/export-original-art.sh`、`docs/design-source/catalog.json`。


## V4 动态示例

`LivePhotoSamples.swift` 使用已有原创兔子、奶油熊、云朵、雏菊和彩虹矢量定义绘制短动画，在本机生成原生 Live Photo。示例不依赖外部照片、视频或音频授权，不读取用户图库，也不联网下载。


## V4.0.2 新增原创素材

- 海报：周末出走（4 图）、毛孩子日记（2 图）、城市刊物（3 图）。当前共 23 款，版式与文案均为本项目原创。
- 风格：旅行手帐、宠物日记、黑白刊物。当前共 9 套配色与照片效果参数。
- 酷感贴图：胶片瞬间、随身节拍、流星信号、棋盘浪潮、山野徽章、黑胶时刻，沿用 `OriginalStickerArt.swift` 的原创矢量绘制。当前 16 款可爱、8 款酷感，共 84 个贴纸条目。
- 两份本地 Live 示例由上述已有原创矢量素材预渲染，720×960、3 秒、无声音；成对 JPG/MOV 随 Swift Package 的 `Resources/LiveSamples` 分发。没有加入用户照片或第三方素材。
