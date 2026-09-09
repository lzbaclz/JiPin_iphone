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

未使用未授权的第三方照片、插画或品牌素材。若后续引入外部 IP 或可下载字体，需单独补充授权文件后再入库。

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
