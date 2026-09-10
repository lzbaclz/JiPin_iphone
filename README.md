# 极拼 JiPin

面向 iPhone 的多功能拼图 App。当前 V4.0.1，最低系统 iOS 17，使用 Swift / SwiftUI。

- 四种模式：模板（2–16 张）、自由（1–16 张）、海报（1–9 张）、长图（2–20 张横竖拼）
- 共用编辑：裁切旋转、背景、边框、文字、贴纸与几何形状、10 个滤镜、调色、涂鸦、马赛克、图层、50 步撤销、多份草稿
- 系统相册 Action Extension：2–9 张快拼与草稿交接
- 本地处理：无默认水印，导出不复制 GPS

V4.0 支持原生 **Live Photo 拼图**：最多 9 张 Live 与普通照片混拼，四种模式沿用裁切、滤镜、文字、贴图与边框；可选 1.5 / 2 / 3 秒、静音或一张照片的原声，生成 1080 / 1440 长边的动态成品，保存后在苹果相册长按播放。首页提供原创动态示例。相册扩展保留 Live 草稿，到主 App 完成动态导出。详见 [V4 方案](docs/v4-live-photo-plan.md)。

V4.0.1 修复画布手势：双指围绕触点中心缩放/旋转，增减手指保持当前位置；普通拖动调整画面，长按后拖动交换照片。预览缓存复用图片像素，操作中暂停缩略图和自动保存，松手恢复高清预览。「调整」增加角度与缩放微调、构图复位。

V2.0 增加少裁切布局推荐与实图预览、可调分隔线、六套一键风格与个人风格保存、整组色调同步，以及横竖长图分页导出。个人风格只保存搭配参数；照片、文字和布局仍保存在草稿中。


V3.0 增加 16 个可爱贴图、2 个酷感贴图和 6 款可爱画布边框。首页可直接试用，贴纸册支持搜索与收藏，贴图可移动、缩放、旋转、翻转和调整透明度；装饰可随草稿保存、撤销和导出。

[贴图总览](docs/design-source/originals/v3-sticker-board.png) · [边框总览](docs/design-source/originals/v3-frame-board.png)

产品取舍和竞品证据见 [拼图产品研究](docs/research/collage-market-review.md)。开发者资格已通过，已完成开发签名构建、正式归档与 App Store Connect 分发包导出；V3 已由用户上传 TestFlight；V4 的真机实拍素材、iCloud 和完整宿主扩展验收另行进行。

共享模块见 `Packages/JiPinCore`。构建步骤见 [docs/BUILD.md](docs/BUILD.md)，范围见 [docs/iphone-photo-collage-project-plan.md](docs/iphone-photo-collage-project-plan.md)，上架文案见 [docs/store-listing.md](docs/store-listing.md)。

归档并导出 TestFlight 分发包：`./scripts/archive-testflight.sh`。签名与首次设备登记说明见 [构建说明](docs/BUILD.md)。
