# 极拼 V1.0 测试记录

日期：2026-09-09。环境：Xcode 26.3、iOS 26.3 模拟器。对照项目计划 A01–A16。

## 本机验证结果

| 检查 | 结果 |
| --- | --- |
| 核心测试 JiPinTests | 97 项通过，0 失败 |
| iPhone 17 界面测试 | 19 项通过，0 失败 |
| iPhone 16e 界面测试 | 19 项通过，0 失败 |
| Release 设备构建 | generic/platform=iOS、CODE_SIGNING_ALLOWED=NO，构建成功 |
| 设计资源导出 | 46 布局、20 海报、60 贴纸、20 背景、10 滤镜 |
| 真机签名与相册宿主 | 本轮暂缓，不作为已通过项目 |

主要命令：

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild test -project JiPin.xcodeproj -scheme JiPin \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
xcodebuild test -project JiPin.xcodeproj -scheme JiPin \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:JiPinUITests
xcodebuild build -project JiPin.xcodeproj -scheme JiPin \
  -destination 'generic/platform=iOS' -configuration Release CODE_SIGNING_ALLOWED=NO
./scripts/export-design-assets.sh
./scripts/export-store-screenshots.sh
```

## 验收条目

| 编号 | 本机证据 | 仍需确认 |
| --- | --- | --- |
| A01 数量与导入 | 0/1/2/9/16/17/20/21 边界；直接从模式卡选图；顺序、PNG 透明度、UIImage 方向、取消与失败提示；海报先确认照片位 | 真机相册、iCloud 下载 |
| A02 模板 | 46 布局覆盖 2–16 张；无缝边界、旋转不越格、裁切与顺序；单击选图不触发交换 | 不同真实照片的主观构图 |
| A03 自由模式 | 稀疏层级上下移动、锁定、重复照片独立替换、复制保留效果、原始照片比例与吸附 | 真机复杂手势体验 |
| A04 海报 | 20 模板可渲染；数量确认、替换、重复照片不隐藏；真实渲染缩略图 | 最终运营文案与展示素材 |
| A05 长图 | 2–20 张、横竖方向、裁切、同比例间距、输出上限；快拼长边 2048 | 超长截图真机测试 |
| A06 文字与素材 | 中文、英文、emoji、换行；60 贴纸、10 形状、20 背景；素材缩略图与自定义渐变；面板可滚动 | 彩色 emoji 真机表现 |
| A07 效果与遮挡 | 滤镜与调色只作用照片；裁切/旋转对应；遮挡上方坐标与垂直翻转；不透明遮挡；固定种子纹理 | 真机连续绘制体验 |
| A08 编辑与历史 | 50 步撤销、文字修改撤销、跨模式复制保存原稿且能导出；照片引用、形状、文字与涂鸦保留 | — |
| A09 草稿 | 30 草稿与复制删除；16 个独立存储实例并发提交；提交失败保留旧稿和缩略图；素材冲突保护；拒绝过期写入 | 真实系统断电等环境事件 |
| A10 相册入口 | 同一快拼界面测试：模式、排序、裁切、背景、保存草稿、分享、取消；部分导入需确认；不自动建草稿 | 真机宿主、签名、App Group |
| A11 输出一致性 | 首帧 Retina 预览与比例变化刷新；JPEG/PNG/透明输出；实际文件大小；唯一分享文件；像素与几何回归 | 最终实拍样本核验 |
| A12 异常 | ENOSPC 提交失败注入、缺失/冲突素材、损坏图片、不完整草稿和取消 | 真机磁盘满、iCloud 离线 |
| A13 隐私 | 工作副本去元数据、成品无 GPS；草稿和素材排除备份；清缓存不动草稿 | 发布包数据流与隐私标签复核 |
| A14 稳定性 | 连续 50 次、9 图 4096、60 对象高清导出；受控解码、串行预览与后台存储 | iPhone 12 计时和峰值内存 |
| A15 适配 | 两种屏幕完整界面测试；画布语义、按钮替代手势、面板滚动、键盘收起与布局重算 | 真机 VoiceOver |
| A16 资源 | 可编辑 Swift 资源源文件、导出的设计 JSON、原创试用插画及图标来源记录 | 外部素材与商标使用如新增另审 |

Xcode 在当前 Command Line Tools 默认选择环境下，测试结束后的额外诊断采集可能提示找不到 simctl；测试过程与 xcresult 结果已明确成功。AppIntents 提取提示无相关依赖，不影响构建。

`docs/store-screenshots/` 使用原生运行界面和原创示例插画生成。真机与发布依赖详见 `KNOWN-ISSUES.md`。

## V2.0 本机验证（2026-09-10）

- iPhone 17 / iOS 26.3：112 项核心测试通过；22 项 UI 用例已全部通过（首轮 20 项，修正两个测试定位假设后分别回归通过）。
- iPhone 16e / iOS 26.3：111 项核心测试与 4 条重点 UI 流程通过；随后新增的深色风格文字回归在 iPhone 17 通过，核心总数为 112。
- 重点验证：全部布局在分隔线边界调整后保持完整覆盖；推荐保留顺序；个人风格不含照片/文字引用；锁定图层与撤销；横竖分页重新拼合后像素一致；第二页写入失败与取消时清除未完成批次。
- 未签名设备 Release 构建通过；设计目录成功导出（46 布局、20 海报、60 基础贴纸、20 背景、10 滤镜及 6 套风格）。
- 视觉检查：`docs/version-screenshots/v2-*-iphone16e.png`，风格工作室、分隔线和分页预览无截字或按钮遮挡，已人工查看。
- 记录：`/private/tmp/jipin-v2-v3/v2-tests-2.xcresult`、`v2-small.xcresult`、`v2-final.xcresult`；最终编译日志 `v2-final-release.log`。临时目录不作为长期构建产物保存。

测试修正说明：默认布局现在可能按照片推荐，固定坐标点击的测试显式指定四宫格；分隔线测试使用专属控件 ID，避免命中后方编辑器的间距滑杆。没有降低原有选择、撤销或导出断言。
