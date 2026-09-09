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
