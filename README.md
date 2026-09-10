# 极拼 JiPin

<img src="Apps/JiPin/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="88" alt="极拼 App 图标">

把多张照片拼在一起，也让 Live Photo 的回忆一起动起来。

极拼是一款面向 iPhone 的本地拼图 App，支持模板、自由拼图、海报和横竖长图，以及原生 Live Photo 混合拼图。使用 Swift / SwiftUI 开发，最低支持 **iOS 17**。

**当前版本：4.0.1（构建 5）** · [快速开始](#快速开始) · [构建与签名](docs/BUILD.md) · [测试记录](docs/TEST-RECORD.md) · [已知边界](docs/KNOWN-ISSUES.md)

## 功能

| 拼图模式 | 照片数量 | 主要用途 |
| --- | --- | --- |
| 模板拼图 | 2–16 张 | 网格、分屏、少裁切布局推荐与分隔线调整 |
| 自由拼图 | 1–16 张 | 自由摆放、叠放照片，搭配文字和装饰 |
| 海报拼图 | 1–9 张 | 主题版式、标题与多图海报 |
| 长图拼接 | 2–20 张 | 横向、纵向拼接及静态分页导出 |

四种模式共用裁切、缩放、旋转、翻转、滤镜、调色、背景、边框、文字、贴纸、涂鸦、马赛克和图层编辑；支持最多 50 步撤销/重做、多份草稿与跨模式复制。

- **布局与风格**：46 个布局、20 个海报模板、6 套风格搭配；可收藏布局并保存个人风格。
- **贴纸与边框**：78 个贴纸，包含 16 个原创可爱贴图、2 个酷感贴图，以及 6 款画布装饰边框。贴纸册支持分类、搜索和收藏。
- **静态导出**：JPEG / PNG、标准与高清尺寸、相册保存、系统分享和存储到文件；自由与海报模式支持透明 PNG，长图支持分页。
- **草稿**：自动保存、重命名、复制、删除；图片和动态资源按引用共享，保存失败时保留已有草稿。

### Live Photo 拼图

从系统选择器选入 Live Photo，保留照片和动态视频，与普通照片混排后生成 **原生 Live Photo**。保存到苹果相册后可长按播放。

| 项目 | 支持范围 |
| --- | --- |
| 动态来源 | 每份作品最多 9 个不同 Live 来源，总照片数仍受所选模式限制 |
| 时长 | 1.5 / 2 / 3 秒；短片段在首尾保持画面，普通照片保持静止 |
| 声音 | 默认静音，可保留其中一张 Live 的原声 |
| 输出 | 最长边 1080 / 1440、30 fps，SDR JPEG + H.264 MOV 配对资源 |
| 编辑效果 | 沿用布局、裁切、旋转、滤镜、文字、贴纸和边框 |
| 其他输出 | 可选择静态图片导出，或以 MOV 视频进行分享 |

动态资源随草稿保存，重开、复制和撤销后仍能继续编辑。生成结果会先通过苹果 PhotoKit 的原生加载检查，再提供保存。技术方案见 [V4 Live Photo 方案](docs/v4-live-photo-plan.md)。

### 手势与精细调整

4.0.1 改进了画布操作：

- 拖动调整照片位置或格内画面，双指围绕触点中心缩放和旋转。
- 增减手指时保持当前位置；一次手势对应一次撤销和保存。
- **长按约半秒后拖动**，将照片与另一格交换。
- 在「调整」中使用 ±1°、±5% 微调和构图复位。
- 操作时复用图片缓存，持续显示预览，暂停推荐缩略图刷新和自动保存；松手后恢复高清预览并保存。

### 从系统相册进入

在苹果「照片」中多选 **2–9 张**，点击分享，在操作区选择「极拼」，即可使用 Action Extension 快速拼图。

扩展支持模板、横竖拼接、排序、裁切、背景和间距。选择「保存草稿」后，可回主 App 的草稿页继续完整编辑。扩展收到完整 Live 资源时会保留动态草稿，**Live 合成与导出在主 App 完成**；扩展内直接保存/分享图片输出静态图。

## 界面与素材

以下为仓库内使用原创示例素材的功能截图：

<p>
  <img src="docs/version-screenshots/v4-live-saved-iphone16e.png" width="230" alt="Live Photo 预览与保存到相册">
  <img src="docs/version-screenshots/v3-cute-stickers-iphone16e.png" width="230" alt="原创可爱贴纸册">
</p>

[贴图总览](docs/design-source/originals/v3-sticker-board.png) · [边框总览](docs/design-source/originals/v3-frame-board.png) · [素材来源与授权记录](docs/asset-license.md)

## 快速开始

### 环境

- macOS 与完整 Xcode；本项目已在 Xcode 26.3、iOS 26.3 模拟器上验证。
- Xcode 中安装可用的 iOS 模拟器运行时。
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)，用于从 `project.yml` 生成工程。

```sh
git clone https://github.com/lzbaclz/JiPin_iphone.git
cd JiPin_iphone

# 使用 Homebrew 安装工程生成工具
brew install xcodegen

# 若 Xcode 安装在其他位置，按实际路径修改
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
open JiPin.xcodeproj
```

在 Xcode 中选择 **JiPin** scheme 和一个 iPhone 模拟器，运行 App。首页可直接选择「用示例插画体验」或「试试动态示例」，无需准备个人照片。

`project.yml` 是工程配置源。调整版本号、Target、签名和能力后，重新运行 `xcodegen generate`。

### 命令行构建与测试

以下命令在仓库根目录执行。设备名称以 `xcrun simctl list devices available` 的结果为准。

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# 模拟器构建
xcodebuild build -project JiPin.xcodeproj -scheme JiPin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO

# 核心测试
xcodebuild test -project JiPin.xcodeproj -scheme JiPin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:JiPinTests

# 界面测试
xcodebuild test -project JiPin.xcodeproj -scheme JiPin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:JiPinUITests
```

当前包含 144 项核心用例和 34 条界面用例，涵盖布局、导出、草稿、Live、手势、异常与兼容性。原生相册保存后回读的专项需要额外测试图库授权，常规运行可能跳过；启用方法及分轮验证结果见 [构建说明](docs/BUILD.md) 和 [测试记录](docs/TEST-RECORD.md)。

常用开发启动参数可配置到 Xcode scheme 的 **Arguments Passed On Launch**：

| 参数 | 用途 |
| --- | --- |
| `-sampleEditor -sampleMode template -sampleLayout g4-grid` | 打开四分格示例，复现缩放与旋转场景 |
| `-sampleEditor -sampleMode freeform` | 打开自由拼图示例 |
| `-sampleLiveEditor` | 打开可编辑的 Live 示例 |
| `-quickCollage` / `-quickLiveCollage` | 演示扩展快拼或 Live 草稿交接界面 |

## 真机与 TestFlight

工程预设了本项目的开发团队、Bundle ID 和 App Group。使用其他开发者账号时，需要同步配置 `project.yml`、核心模块中的 `JiPin.appGroupID` 和 `scripts/ExportOptions-TestFlight.plist`。主 App 与扩展使用同一团队，并配置相同的 App Group。

签名准备完成后，运行：

```sh
./scripts/archive-testflight.sh
```

默认产物位于 `build/TestFlight/<时间>/`：

```text
JiPin.xcarchive
Export/JiPin.ipa
```

该脚本完成本地签名归档和 IPA 导出。之后通过 Xcode Organizer 或 Transporter 上传，并在 App Store Connect 的 TestFlight 中配置构建和测试组。

4.0.1（5）的本机验证产物位于 `build/TestFlight/JiPin-4.0.1-5/`。构建产物被 Git 忽略，新克隆的仓库需自行构建。设备登记、签名故障及真实相册扩展验收步骤见 [构建与签名说明](docs/BUILD.md)。

## 项目结构

```text
Apps/
  JiPin/                  主 App、完整编辑器、导出和示例素材
  JiPinAction/            系统相册操作扩展与快拼界面
  JiPinUITests/           用户流程与手势测试
Packages/
  JiPinCore/              Swift Package：模型、布局、渲染、Live、草稿与核心测试
scripts/                  工程素材导出、截图与签名归档脚本
docs/                     方案、竞品研究、构建说明、验证记录与素材清单
project.yml               XcodeGen 工程配置
```

主要使用 SwiftUI / UIKit 构建界面与交互，PhotosUI / PhotoKit 处理选图和相册，AVFoundation 处理动态视频，Core Image / Core Graphics / ImageIO 处理图像。

## 数据与当前边界

核心编辑在本机完成，不接入账号、广告或第三方行为分析；照片导入完成后可离线编辑。系统选图只读取用户选择的项目，保存时申请添加照片权限。

静态工作图会去除元数据；Live 的本机动态工作副本可能包含原始元数据和声音，生成的成品不继承 GPS。草稿与工作副本排除云备份，清理导出缓存保留草稿和相册成品。iCloud 原图下载与用户主动分享由相应系统服务处理。

当前 Live 输出采用 SDR，不提供 HDR 保真、GIF、通用视频导入或动态壁纸功能。真实 iCloud 场景、系统相册宿主、低内存设备与连续操作性能仍需真机验收；模拟器的测试耗时不代表实际 iPhone 帧率。具体边界见 [待验证事项](docs/KNOWN-ISSUES.md)，草稿存储与兼容性见 [草稿格式](docs/draft-format.md)。

## 版本演进

| 版本 | 主要变化 |
| --- | --- |
| V1.0 | 四种拼图模式、完整编辑器、相册扩展与草稿 |
| V2.0 | 布局推荐、可调分隔线、个人风格和长图分页 |
| V3.0 | 原创可爱/酷感贴图、贴纸册与装饰边框 |
| V4.0 | 原生 Live Photo 导入、混拼、预览、导出和动态草稿 |
| V4.0.1 | 手势焦点与撤销修复、预览性能优化、微调和复位 |

## 项目文档

- [最初项目计划](docs/iphone-photo-collage-project-plan.md)
- [拼图产品研究与取舍](docs/research/collage-market-review.md)
- [V4 Live Photo 方案](docs/v4-live-photo-plan.md)
- [构建、签名与测试](docs/BUILD.md)
- [本机验证记录](docs/TEST-RECORD.md)
- [已知边界与待验证项](docs/KNOWN-ISSUES.md)
- [草稿格式与版本兼容](docs/draft-format.md)
- [素材来源](docs/asset-license.md)与[设计目录](docs/design-source/catalog.json)
- [App Store 文案与审核说明](docs/store-listing.md)
