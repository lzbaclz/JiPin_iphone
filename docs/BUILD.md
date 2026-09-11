# 极拼 JiPin 构建说明

## 环境

- Xcode 26 或更高版本（当前工程按 Xcode 26.3 / iOS 17+ 编写）
- 最低运行系统：iOS 17
- 本机若 `xcode-select` 仍指向 Command Line Tools，构建前设置：

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## 生成 Xcode 工程

仓库使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 维护 `project.yml`：

```sh
cd /Users/liziqing/Programs/myself/jipin_iphone
xcodegen generate
open JiPin.xcodeproj
```

## 模拟器构建

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project JiPin.xcodeproj -scheme JiPin -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

## 测试

单元测试（JiPinTests）与 UI 测试（JiPinUITests）都挂在 `JiPin` scheme 上：

```sh
xcodebuild test -project JiPin.xcodeproj -scheme JiPin -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

只跑核心单测：

```sh
xcodebuild test -project JiPin.xcodeproj -scheme JiPin -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO -only-testing:JiPinTests
```

UI 测试通过 `-sampleEditor` 打开四种模式，验证首帧预览、比例重算、单击选图、模式复制后导出、相册快拼和可用按钮。试用插画由 `StudioPreviews.swift` 原创绘制。

测试记录与未关闭项见 `docs/TEST-RECORD.md`、`docs/KNOWN-ISSUES.md`。商店文案、年龄分级与审核说明见 `docs/store-listing.md`。按商店尺寸导出截图：

```sh
./scripts/export-store-screenshots.sh
```

导出模板与素材设计参数：

```sh
./scripts/export-design-assets.sh
```

输出为 `docs/design-source/catalog.json`，用于设计审阅和交接；App 运行时仍使用对应 Swift 目录定义。

未签名设备 Release 编译：

```sh
xcodebuild build -project JiPin.xcodeproj -scheme JiPin -destination 'generic/platform=iOS' -configuration Release CODE_SIGNING_ALLOWED=NO
```

## 真机与扩展

当前付费开发团队 `MFLYL78RAN` 已写入 `project.yml` 的公共构建设置，主 App、扩展和测试 Target 使用同一团队。XcodeGen 重新生成工程后该设置仍保留。

### 首次签名：先登记开发设备

会员开通不等于已存在开发描述文件。`Communication with Apple failed` 下的详细原因若为 `Your team has no devices`，是团队没有登记开发设备，不代表账号审核失败或网络断开。

首次需要开发签名时，连接/配对 iPhone，选择该设备执行一次 **Build 或 Run**，让 Xcode 登记设备并生成主 App 和扩展的开发描述文件。Archive 会使用通用设备目标；只做 Archive 或在没有具体设备目标时点 Try Again，不能替代首次设备登记。

命令行可用以下形式（`DEVICE_UDID` 替换为实际设备 UDID）：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project JiPin.xcodeproj -scheme JiPin -configuration Debug \
  -destination 'platform=iOS,id=DEVICE_UDID' \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

若完全没有可用设备，可配置 App Store Connect 分发描述文件与分发签名；分发描述文件不包含测试设备列表。不能把“TestFlight 不需要登记测试者设备”理解为“开发描述文件也不需要设备”。

### TestFlight 归档与分发包

本项目已于 2026-09-10 验证：开发签名构建成功，正式归档成功，App Store Connect 分发 IPA 导出成功。主 App 与扩展的分发包均使用 Apple Distribution 签名，`get-task-allow=false`、`beta-reports-active=true`，App Group 一致。

已登录 Xcode 开发者账号并完成签名准备后运行：

```sh
./scripts/archive-testflight.sh
```

脚本根据 `project.yml` 生成工程，在 `build/TestFlight/<时间>/` 下归档并导出 IPA。`ExportOptions-TestFlight.plist` 使用 `app-store-connect`、自动签名、`destination=export`，可用于后续内测或外测。此命令只导出本地文件；不会上传构建、提交 Beta 审核或发送测试邀请。

打开 `.xcarchive` 后，在 Xcode Organizer 中选择 **Distribute App → TestFlight & App Store** 上传；或者用 Transporter 上传导出的 `JiPin.ipa`。App Store Connect 中需有与 `com.jipin.JiPin` 对应的 App 记录。重复上传同一版本时递增 `project.yml` 中的构建号，并保持主 App 与扩展一致。

2026-09-10 的已验证产物位于 `build/TestFlight/JiPin-3.0.0-3.xcarchive` 与 `build/TestFlight/Export/JiPin.ipa`，均为本机文件，不随 Git 提交。签名完成不代表真实相册扩展流程或 TestFlight 审核已通过。

### 相册扩展验收

相册操作扩展必须在真机上验收（计划 A10）。模拟器与单元测试不能替代下列步骤。

1. 在 Xcode 中为 `JiPin` 与 `JiPinAction` 选择**同一个 Development Team**，并启用 App Group `group.com.jipin.JiPin`。
2. 将 App 装到 iPhone。不必先打开主 App。
3. 打开系统「照片」，多选 2 张、再试 9 张，点分享 → **操作区**「极拼」（不是相册原生工具栏）。扩展声明最多 9 张图片；不足 2 张时会提示改用主 App。
4. 在扩展里切换模板/长图、调整间距与裁切后：**保存到相册**、点「更多」**保存草稿**、**系统分享**、**取消**。分享会自行生成 JPEG，不必先保存到相册。若拒绝添加照片权限，应仍能保存草稿或使用系统分享，且已有草稿不被破坏。
5. 拒绝「添加照片」权限后，确认草稿仍可保存，已有草稿不被破坏。
6. 打开极拼 → 草稿，应看到「来自相册」条目并可继续完整编辑。若宿主仍传入超过 9 张或部分失败的数据，扩展必须先明确提示并让用户确认，才能继续。

快速编辑默认不自动建立草稿，取消不会修改已有草稿。缺少可用 App Group 时，实际扩展会拒绝草稿交接；模拟器中主 App 的快拼演示可以保存到自身沙盒，但不能据此认定真实交接已通过。

主 App 与扩展的添加照片权限是分开的。

## 模块

- `Packages/JiPinCore`：项目模型、布局、海报模板、素材目录、草稿存储、渲染与导出
- `Apps/JiPin`：主 App（创作、草稿、设置、完整编辑器）
- `Apps/JiPinAction`：系统相册操作扩展（2–9 张快拼与草稿交接）

## V3 原创素材交付

运行 `./scripts/export-original-art.sh` 导出 18 张 768×768 透明 PNG 贴图、6 张 768×1024 镂空边框和两张素材总览，输出到 `docs/design-source/originals/`。脚本直接编译 App 使用的 CoreGraphics 绘制定义；App 本身使用矢量源渲染，不会加载交付 PNG 放大。

V2/V3 的界面截图见 `docs/version-screenshots/`。版本号由 `project.yml` 统一生成主 App 与扩展的 Info.plist；当前 V4.0.1 / build 5。


## V4 Live Photo 开发与验证

从首页选择「试试动态示例」可直接编辑两个原创 Live；无须用户照片或全相册读取权限。开发启动参数 `-sampleLiveEditor` 和 `-quickLiveCollage` 分别打开动态编辑器和扩展交接演示。用例 `LivePhotoTests` 覆盖配对元数据、帧变化、静态混拼、音轨、草稿、取消和大图准备；`LivePhotoUITests` 覆盖原生预览、设置、保存、静态导出与草稿重开。

```sh
xcodebuild test -project JiPin.xcodeproj -scheme JiPin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:JiPinTests/LivePhotoTests -only-testing:JiPinUITests/LivePhotoUITests
```

正式 App 的 Info.plist 仅声明添加照片权限。`testNativePhotoLibraryStoresAndReloadsLiveSubtype` 是额外的模拟器回读测试：没有图库读取授权时会跳过，常规测试仍验证原生 Live 解析和保存界面。若运行此专项，先完成 build-for-testing，仅在**临时测试产物**的主 App Info.plist 添加 `NSPhotoLibraryUsageDescription = Simulator PhotoKit round-trip test only.`，使用 test-without-building 启动，并在模拟器允许读取测试图库。结束后移除此临时键、重置模拟器权限并重新构建；不要将它加进 project.yml 或分发包。测试通过 PhotoKit 检查 `.photoLive`、`.photo` 与 `.pairedVideo`，再请求原生播放对象。

真机建议使用自己拍摄的横竖 Live、长短片段、带原声、来自 iCloud 和经过系统编辑的素材验证；同时检查苹果相册中的长按播放及 AirDrop 分享。测试通过前，不把模拟器速度当作旧款 iPhone 的性能承诺。

最终 V4 本机构建产物：`build/TestFlight/JiPin-4.0.0-4/JiPin.xcarchive` 和 `build/TestFlight/JiPin-4.0.0-4/Export/JiPin.ipa`。上传前使用这一份包含系统选图修复的归档；V3 归档仍保留。


## V4.0.1 手势修复包

4.0.1 归档：`build/TestFlight/JiPin-4.0.1-5/JiPin.xcarchive`；分发包：`build/TestFlight/JiPin-4.0.1-5/Export/JiPin.ipa`。主 App 和扩展同时升级为 4.0.1 / build 5，草稿仍使用 schema 4。旧版归档保留；本次没有上传 TestFlight。

手势验收使用 `-sampleEditor -sampleMode template -sampleLayout g4-grid`，与反馈中的四分格场景一致。`CanvasGestureUITests` 验证真实多指缩放/旋转、撤销、连续预览、跨格拖动、长按交换和画笔兼容；`CanvasInteractionTests` 验证焦点坐标、镜像、边界、缓存和自动保存。

## V4.0.2 体验更新包

当前主 App 和扩展均为 **4.0.2 / build 6**，草稿仍使用 schema 4。

- 签名归档：`build/TestFlight/JiPin-4.0.2-6/JiPin.xcarchive`
- App Store Connect 分发 IPA：`build/TestFlight/JiPin-4.0.2-6/Export/JiPin.ipa`
- 验证结果：`build/Validation-4.0.2/`
- 变更、测试与内置 Live 示例的维护方法：[4.0.2 发布说明](v4.0.2-release.md)

产物已在本机导出，尚未上传 TestFlight。主 App、扩展以及内嵌框架签名已核验；安装包只声明添加照片用途，未加入测试用的全图库读取用途说明。

## V4.0.3 长图滑动修复包

当前主 App 和扩展均为 **4.0.3 / build 7**，草稿保持 schema 4。修复内容与验证见 [4.0.3 发布说明](v4.0.3-release.md)。

```sh
JIPIN_EXPORT_ROOT="$PWD/build/TestFlight/JiPin-4.0.3-7" ./scripts/archive-testflight.sh
```

长图交互回归为 `JiPinUITests/LongStripGestureUITests`，覆盖纵横浏览、Live、双指与长按、撤销以及工具页稳定。开发参数 `-sampleLiveEditor -sampleMode longStrip` 可打开内置 Live 长图示例。


4.0.3（构建 7）已完成正式签名归档、IPA 导出和 TestFlight 上传，Apple 处理完成后已关联内部群组与“官网公开内测”群组。公开群组的新构建需等待本次 Beta 审核；审核期间旧版 4.0.2 继续可用。签名核验与上传记录见 4.0.3 发布说明。

## V4.0.4 高清默认与保存收尾

主 App 与扩展版本统一为 **4.0.4 / build 8**。项目清晰度默认高清，保存成功后关闭根导出入口。新用例为 `Version404UITests`；拒绝相册权限用例在新建模拟器单独执行，避免已有授权影响结果。完整记录见 [4.0.4 发布说明](v4.0.4-release.md)。

```sh
JIPIN_EXPORT_ROOT="$PWD/build/TestFlight/JiPin-4.0.4-8" ./scripts/archive-testflight.sh
```

4.0.4（构建 8）已完成签名核验、TestFlight 上传与群组关联。内部测试已可使用，公开外测提交完成时等待 Apple Beta 审核。具体 IPA 大小、校验值与验证证据见 4.0.4 发布说明。


## V4.0.5 Live 预览刷新修复

主 App 与扩展统一为 **4.0.5 / build 9**，草稿 schema 仍为 4。修复设置变化后的自动预览、连续请求取消与导出锁交接。发布记录见 [4.0.5 发布说明](v4.0.5-release.md)。

```sh
JIPIN_EXPORT_ROOT="$PWD/build/TestFlight/JiPin-4.0.5-9" ./scripts/archive-testflight.sh
```

签名归档和分发 IPA 位于 `build/TestFlight/JiPin-4.0.5-9/`，验证记录位于 `build/Validation-4.0.5/`。
