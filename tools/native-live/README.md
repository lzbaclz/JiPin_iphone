# 中国山水 Live 样片生成

这些资源用于官网展示。摄影风格原图由内置 image_gen 生成；不是实地拍摄，不包含地理定位。完整原始提示词与图像校验值见 `assets/shanhe/prompts.json`。

`Generator.swift` 在 iOS 模拟器中使用极拼现有的 `JiPinCore`，对应主项目提交 `57f6443`（App 4.0.4）。它是独立的临时素材生成 App，不修改或发布极拼 App。

## 输入与过程

1. 把 `assets/shanhe/originals/` 的三张 PNG 作为资源加入独立 iOS App，入口使用 `Generator.swift`，链接主工程的本地 Swift Package `Packages/JiPinCore`。
2. 每张源图生成 3 秒、30 fps、720×900 的动态：轻微循环镜头运动；漓江水面增加受遮罩限制的细微波纹，岸线和山体不局部变形。黄山、三峡的动态是镜头轻移，不声称是实地拍摄的云水运动。
3. 使用 `LivePhotoWriter` 写出含同一内容标识符的 JPEG / QuickTime MOV，封面取编码后的中间帧。MOV 同时写入 `com.apple.quicktime.still-image-time` 定时元数据。
4. 用 `LivePhotoMedia.request` 调用 PhotoKit 识别每一对资源，再经 `LivePhotoMedia.importPhoto` 导入。
5. 将三张 Live 交给真实的 `ProjectFactory`、`LivePhotoExporter` 与 `CollageRenderer`。采用 `g3-left-one`、6:5 画布，得到 1440×1200 的原生 Live 拼图；再次通过 PhotoKit 识别。
6. 四种静态玩法成品同样由极拼渲染器生成，不用网页示意替代 App 的排版结果。

输出在生成 App 的 `Documents/Shanhe-Web/`。`SUCCESS.txt` 只在全部完成后写入；`validation.json` 保留原生识别结果和资源标识符。

## 网站输出

- 原生资源：`assets/shanhe/live-photos/*.jpg` + 同名 `*.mov`。
- 网站视频：从 MOV 的视频轨转码为 H.264 MP4，静音、3 秒、快速起播；这是网页预览格式。
- 封面与成品：从原生配对 JPEG 转码为 WebP，完整 PNG 原图仍保留。
- 浏览器不原生导入 JPEG/MOV 配对；网页没有宣称点击即可把浏览器视频存成 Live。

原生配对须保持同名、同时导入支持的照片管理工具；只保存 JPEG 会得到静态图。素材包内的说明提供导入步骤。


## 可爱日常与四种动态玩法

`MixedExamples.swift` 使用主 App 4.0.6 的 `JiPinCore`（代码 a5738f6），读取内置兔子、小熊原生 Live 和已存在的山水 Live。通过 `ProjectFactory` 和 `LivePhotoExporter` 为每种主题生成模板、自由、海报、长图八份原生成品，逐一使用 PhotoKit 识别完整照片尺寸。临时生成 App 的资源目录需要显式标记 `buildPhase: resources`。

照片封面和动态视频完整保留在 `assets/examples/cute-live.zip` 与 `shanhe-live.zip`，网页 WebP/MP4 从对应资源转码，ZIP 提供完整配对。原生验证记录为 `assets/examples/validation.json`，网页视频的抽帧验证记录为 `playback-validation.json`。可爱角色沿用 App 已有原创素材，没有引入用户照片。
