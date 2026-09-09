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

UI 测试会用 `-sampleEditor` 打开四种模式，并走一遍模板导出「生成文件」。

测试记录与未关闭项见 `docs/TEST-RECORD.md`、`docs/KNOWN-ISSUES.md`。商店文案、年龄分级与审核说明见 `docs/store-listing.md`。按商店尺寸导出截图：

```sh
./scripts/export-store-screenshots.sh
```

## 真机与扩展

相册操作扩展必须在真机上验收（计划 A10）。模拟器与单元测试不能替代下列步骤。

1. 在 Xcode 中为 `JiPin` 与 `JiPinAction` 选择**同一个 Development Team**，并启用 App Group `group.com.jipin.JiPin`。
2. 将 App 装到 iPhone。不必先打开主 App。
3. 打开系统「照片」，多选 2 张、再试 9 张，点分享 → **操作区**「极拼」（不是相册原生工具栏）。扩展声明最多 9 张图片；不足 2 张时会提示改用主 App。
4. 在扩展里切换模板/长图、调整间距与裁切后：**保存到相册**、点「更多」**保存草稿**、**系统分享**、**取消**。分享会自行生成 JPEG，不必先保存到相册。若拒绝添加照片权限，应仍能保存草稿或使用系统分享，且已有草稿不被破坏。
5. 拒绝「添加照片」权限后，确认草稿仍可保存，已有草稿不被破坏。
6. 打开极拼 → 草稿，应看到「来自相册」条目并可继续完整编辑。超过 9 张时扩展应说明忽略多出的照片。

主 App 与扩展的添加照片权限是分开的。

## 模块

- `Packages/JiPinCore`：项目模型、布局、海报模板、素材目录、草稿存储、渲染与导出
- `Apps/JiPin`：主 App（创作、草稿、设置、完整编辑器）
- `Apps/JiPinAction`：系统相册操作扩展（2–9 张快拼与草稿交接）
