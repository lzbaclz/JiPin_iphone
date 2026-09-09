# 极拼 V1.0 测试记录

对照 `docs/iphone-photo-collage-project-plan.md` 第十三节 A01–A16。记录日期：2026-09-09。环境：macOS Sequoia、Xcode 26.3、iPhone 17 模拟器。本机无可用的 Development Team / 签名身份，也没有接入的真机。

最近一次结果：`JiPinTests` 73 项通过；`JiPinUITests` 15 项在 iPhone 17 模拟器全部通过（含导出实际大小、快拼铺满/选图背景）。

运行方式：

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd /Users/liziqing/Programs/myself/jipin_iphone
xcodegen generate
xcodebuild test -project JiPin.xcodeproj -scheme JiPin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO -only-testing:JiPinTests
xcodebuild test -project JiPin.xcodeproj -scheme JiPin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO -only-testing:JiPinUITests
```

| 编号 | 结论 | 证据 | 缺口 |
| --- | --- | --- | --- |
| A01 | 模拟器/单测通过 | `PhotoLimits` 覆盖 0/1/2/9/16/17/20/21；模式选择器对 0、1、17–20、超限有说明；UI 测 1 张与 17 张提示 | 未在真机用实拍库点选上述数量 |
| A02 | 单测通过 | 46 个布局覆盖 2–16，每个数量至少 2 种；零间距缝隙像素测试；裁切/平移；拖到另一格交换照片 | 未人工点开全部布局预览 |
| A03 | 单测 + UI 部分通过 | 图层按钮、90° 与精细旋转、双指旋转、锁定/隐藏/复制/删除；自由模式可改画布比例并关闭吸附；吸附含中心与边缘 | 未做完整手势可用性走查 |
| A04 | 单测通过 | 20 套海报、六主题；数量不匹配换模板/明确选图 | 未逐套替换实拍检查版式 |
| A05 | 单测通过 | 2–20 张限制、横竖拼、裁切改变输出高度、尺寸标签 | 未用极长截图真机导出 |
| A06 | 单测通过 | 中英 emoji 多行、长文换行、60 贴纸 / 20 背景；10 个几何形状含箭头，可选填充与描边 | 模拟器可能缺少 AppleColorEmoji TTC，emoji 有回退 |
| A07 | 单测通过 | 滤镜不挂到文字；马赛克按原图像素跟随裁切；涂鸦橡皮只擦墨迹 | 未在真机画复杂马赛克后连续裁切 |
| A08 | 单测通过 | 50 步撤销；跨模式复制保留原草稿并警告超限 | — |
| A09 | 单测通过 | 30 份草稿复制/删除；共享素材引用计数；旧 `assets/` 仍可读 | — |
| A10 | **未通过（阻塞发布）** | 扩展可接收 `public.image` 与文件形式附件；激活规则同时声明最多 9 张图/9 个文件；快拼「分享」自行生成 JPEG；铺满/完整显示、选图作背景、间距边距；保存草稿失败会显示错误；`-quickCollage*` 5 项 UI 测试通过 | 必须真机：照片多选 2/9 → 分享操作区「极拼」；保存/取消/拒权/草稿交接。步骤见 `docs/BUILD.md` |
| A11 | 单测 + UI 通过 | 预览与同尺寸导出像素差；JPEG/PNG/透明；无默认水印；导出页显示「约 xx（预估）」并在编码后改为实际大小；`testTemplateExportGeneratesFile` | 未用固定复杂稿做人工预览对照 |
| A12 | 代码路径 + 单测 | 损坏图拒绝、不完整草稿不入库、缓存清理保草稿、导入最多 3 次等待 | 未制造真机磁盘满 / iCloud 离线 |
| A13 | 单测通过 | 导入导出剥 GPS；无登录广告统计；隐私清单 | 未抓包证明无上传（架构为本地处理） |
| A14 | 模拟器单测通过 | 连续 50 次导出、60 对象 HD、9 图 4096 | **不是 iPhone 12 基线**；规划 2s/5s/10s 未在真机确认 |
| A15 | 部分通过 | 标签、深色、键盘避让、顶栏「更多」保住导出；快拼草稿收入「更多」；图层按钮替代手势；iPhone 17 完整 UI 套件 15 项通过 | 未做真机 VoiceOver 走查；iPhone 16e 套件未在本轮重跑 |
| A16 | 目录核对通过 | 46 布局、20 海报、60 贴纸、10 几何形状、20 背景、10 滤镜；`docs/asset-license.md` | 程序化素材，无独立设计源文件包 |

`docs/store-screenshots/` 已用 `scripts/export-store-screenshots.sh` 导出 6.9"（iPhone 17 Pro Max）与 6.3"（iPhone 17）各 6 张竖屏截图。TestFlight、备案与开发者账号资料仍不在本次工程验证范围内。
