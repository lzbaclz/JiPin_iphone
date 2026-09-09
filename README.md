# 极拼 JiPin

面向 iPhone 的多功能拼图 App。最低系统 iOS 17，使用 Swift / SwiftUI。

- 四种模式：模板（2–16 张）、自由（1–16 张）、海报（1–9 张）、长图（2–20 张横竖拼）
- 共用编辑：裁切旋转、背景、边框、文字、贴纸与几何形状、10 个滤镜、调色、涂鸦、马赛克、图层、50 步撤销、多份草稿
- 系统相册 Action Extension：2–9 张快拼与草稿交接
- 本地处理：无默认水印，导出不复制 GPS

V2.0 增加少裁切布局推荐与实图预览、可调分隔线、六套一键风格与个人风格保存、整组色调同步，以及横竖长图分页导出。个人风格只保存搭配参数；照片、文字和布局仍保存在草稿中。

产品取舍和竞品证据见 [拼图产品研究](docs/research/collage-market-review.md)。开发者资格审核期间使用模拟器开发；版本完成不代表已通过真机或 TestFlight 验收。

共享模块见 `Packages/JiPinCore`。构建步骤见 [docs/BUILD.md](docs/BUILD.md)，范围见 [docs/iphone-photo-collage-project-plan.md](docs/iphone-photo-collage-project-plan.md)，上架文案见 [docs/store-listing.md](docs/store-listing.md)。
