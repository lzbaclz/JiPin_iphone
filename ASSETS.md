# 官网素材与原生 Live 样片

## 山水系列（Web V2）

以中国山川河流的景观特征为灵感，使用 **内置 image_gen** 生成三张写实原图，每张一次生成。素材不是实地摄影，也不对应经过验证的具体拍摄地点。页面可见位置标注“AI 生成山水素材”。

| 素材 | 景观特征 | 文件 |
| --- | --- | --- |
| 漓江山色 | 广西喀斯特群峰、河面倒影、晨光 | `assets/shanhe/originals/lijiang-karst.png` |
| 黄山云海 | 安徽花岗岩、山松、层叠云海 | `assets/shanhe/originals/huangshan-clouds.png` |
| 三峡江流 | 长江峡谷、江湾、山体层次 | `assets/shanhe/originals/three-gorges-river.png` |

原图均为 1122×1402 PNG。完整提示词、生成方式与 SHA-256 见 [prompts.json](assets/shanhe/prompts.json)。网页另有响应式 WebP 衍生文件，原图不删除。

动态由生成原图制作：轻微镜头运动，漓江水面加入细微波纹。不是 AI 视频模型生成的实拍影片，也不把虚构景观当作地理纪实。三张源 Live 和一张拼图成品均由极拼原生 Live 写入器生成，并调用 Apple PhotoKit 识别；原生资源、验证结果与合成工程保存在 `assets/shanhe/live-photos/`。

首页主视觉和四种模式成品经极拼 `JiPinCore` 渲染；网页 H.264 MP4 用于预览。原生 JPEG / MOV 配对与网页 MP4 分开保存，浏览器播放能力不等同于苹果相册原生 Live 播放。生成源代码见 [tools/native-live](tools/native-live/README.md)。

## 保留素材

| 素材 | 来源与用途 |
| --- | --- |
| `assets/app-icon.png` / `brand-icon.webp` | 极拼 App 图标，沿用原有品牌和社交预览元数据 |
| `assets/screens/*.webp` | 主项目 4.0.1 的真实模拟器界面，弹窗明确标注版本；当前操作说明在支持页维护 |
| `assets/stickers/*.webp` | 极拼原创贴纸，界面按可爱与酷风分组 |
| `assets/testflight-qr.png` | 极拼公开 TestFlight 邀请 `https://testflight.apple.com/join/1NqZxpgX` 的二维码 |
| `assets/scenes/`、`assets/video/` | 旧版插画与小兔、小熊演示保留，未删除 |
| `archive/2026-09-11-v1/` | 改版前完整官网及所有原始依赖的独立快照 |

二维码通过随站点托管的 MIT 开源库 `qrcode-generator` 2.0.4 在浏览器本地生成。来源、许可见 `assets/vendor/qrcode-generator/`。图片、视频、字体和二维码不依赖第三方素材服务；视频由用户主动播放，无自动播放。
