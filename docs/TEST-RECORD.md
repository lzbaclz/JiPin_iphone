# 极拼本机测试记录

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


## V3.0 本机验证（2026-09-10）

- iPhone 17 / iOS 26.3：120 项核心测试通过；25 项 UI 用例全部完成回归（全量运行 23 项通过，另两项修正测试手势及滚动定位后复跑通过）。没有忽略失败或降低功能断言。
- iPhone 16e / iOS 26.3：8 项 V3 核心回归与 3 项新用户流程通过，覆盖首页试贴、可爱/酷感分类、搜索、收藏、移动、导出，以及边框添加、移除和撤销。
- 修复实际渲染问题：多路径矢量贴图原先在半透明叠加处变深；现在以整层合成应用透明度，半透明输出最大 alpha 验证通过。
- 所有 18 张原创贴图渲染结果不同且外围透明；所有 6 款边框在横、竖、方形比例下中心透明；V1/V2 草稿兼容、装饰保存重开、跨模式复制、未知素材导出阻止均通过。
- 主 App 与扩展均为 3.0.0 / build 3；未签名设备 Release 编译通过。
- 设计目录：46 布局、20 海报、78 贴纸、20 背景、10 滤镜、6 风格、6 装饰边框。导出 18 张透明贴图 PNG、6 张镂空边框 PNG 和两张总览，已视觉检查；App 使用同源矢量绘制。
- 界面视觉检查：`docs/version-screenshots/v3-*-iphone16e.png` 的贴纸册、酷感分类、可爱边框、画布试贴和首页示例流程，已人工查看。
- 记录：`/private/tmp/jipin-v2-v3/v3-final.xcresult`（核心 + 全量 UI）、`v3-ui-final.xcresult`（iPhone 17 两条复跑）、`v3-small.xcresult`（8 项核心）、`v3-small-final.xcresult`（小屏三条复跑）；编译日志 `v3-release.log`。临时结果不是长期分发包。

UI 测试定位修正：工具条改用容器内的短距离拖动，避免一次滑过目标按钮；导出页按实际小屏布局滚动到生成按钮。素材、编辑与成功导出的断言保留。


## 首次签名与 TestFlight 分发包验证（2026-09-10）

- 根因由 Xcode `Update Signing` 日志和实际构建确认：账号已是付费 Individual 团队，主 App/扩展团队一致，但 Apple 返回 `Your team has no devices`，没有开发描述文件。Archive 使用通用目标，未完成设备登记。
- 已对当前配对的 iPhone 15 Pro 执行一次指定设备的 Debug 构建，允许 Xcode 登记设备/更新签名资源；构建成功，主 App 与扩展均取得开发描述文件，设备数为 1，App Group 为 `group.com.jipin.JiPin`。
- Release `archive` 成功。对归档内主 App 与扩展执行 `codesign --verify --deep --strict`，均通过。
- `app-store-connect` 本地分发导出成功。解包 IPA 后两端均为 Apple Distribution 签名，`get-task-allow=false`、`beta-reports-active=true`，无开发设备列表，Team 和 App Group 一致。
- 版本/构建号均为 3.0.0 (3)。产物：`build/TestFlight/JiPin-3.0.0-3.xcarchive`、`build/TestFlight/Export/JiPin.ipa`（4,907,144 字节）。这些文件被 Git 忽略。
- `project.yml` 持久化团队，新增本地归档/导出脚本与 ExportOptions。脚本通过 `zsh -n`，plist 通过 `plutil -lint`；对应归档与导出命令已实际执行。
- 没有安装/运行真机 App，也没有上传 TestFlight、提交 Beta 审核或发送邀请；本节不替代真实相册宿主和 TestFlight 验收。


## V4.0 本机验证（2026-09-10）

- 核心覆盖共 135 项：原有 120 项回归和 15 项 Live 专项。分轮常规测试覆盖 134 项通过；需要额外测试图库权限的 1 项原生相册回读在独立运行中通过。没有把该项常规跳过当作验收成功。
- 原生 Live 验证：JPEG/MOV 配对标识和 still-image-time 一致；苹果 PhotoKit 可加载；保存后 PHAsset 含 `.photoLive`，拥有 `.photo` / `.pairedVideo` 资源，并可重新请求 PHLivePhoto。
- 动态内容：四种模式、两个同时运动的来源、普通照片静止、裁切/旋转/滤镜/贴图/装饰边框、9 路 1080 合成、超出 9 路拒绝、时长设置与封面时刻对齐、首尾保持、原声音轨保留与静音清除。
- 图像验证：静态封面从编码后的中间帧生成，与视频帧的方向和颜色一致；覆盖相机视频的 preferredTransform 旋转；大尺寸来源先逐张准备较小的工作视频。
- 数据验证：动态草稿重开、跨模式复制、删除最后一个磁盘引用后的撤销恢复、视频内容冲突、缺失资源、ENOSPC 写入失败、V3 缺省字段兼容、生成中取消并清理半成品。丢失动态时明确阻止 Live 导出，但允许用户选择导出完好的静态封面。
- iPhone 17 / iOS 26.3：原有 25 条 UI 回归通过；5 条 Live 流程均完成通过，包括首页动态示例、原生预览/时长/保存/静态导出、草稿重开、扩展界面交接，以及系统 PhotosPicker 选择真实图库 Live 后再次动态导出。UI 测试修正了 iOS 26 的虚拟照片节点和可见范围定位；扩展用例在无同时手动操作模拟器的环境复跑通过。
- iPhone 16e / iOS 26.3：4 条 Live 重点流程通过，包含小屏固定底部生成/保存按钮、权限提示、动态保存和静态导出。界面证据见 `docs/version-screenshots/v4-*-iphone16e.png`，已查看。
- 手动系统选图验证：一张已保存的原生 Live 加一张普通 JPG 从系统选择器导入，编辑器显示 `LIVE · 1`，可进行混合 Live 导出。此验证发现并修复了 `supportedContentTypes` 只列出静态格式时丢失 Live 的问题：现在优先请求 PHLivePhoto 表示，错误按失败处理，仅无该表示时走静态读取。
- 主 App 与扩展均为 4.0.0 / build 4，Apple Distribution 签名、App Group 一致，`get-task-allow=false`、`beta-reports-active=true`；IPA 不含整图库读取权限用途说明，临时测试键未进入发布包。
- 最终分发包：`build/TestFlight/JiPin-4.0.0-4/Export/JiPin.ipa`，5,481,345 字节；SHA-256 `ee1db4c1e51e0fba43074063bf2d8fee4ecec44a0eb197f7deb3e62f8535b988`。归档：同目录上一层 `JiPin.xcarchive`。未上传 V4 TestFlight。
- 设计资源脚本均执行成功，原有 46 布局、20 海报、78 贴图、20 背景、10 滤镜与可爱边框保持可重新生成。

本轮结果路径（临时诊断文件，不作为分发包）：`/private/tmp/jipin-v4/full-tests.xcresult`（原有核心与 25 条 UI）、`live-core-final.xcresult`（最终 15 条 Live 核心）、`photokit-roundtrip2.xcresult`（真实 PhotoKit 保存回读）、`live-ui-final.xcresult` 与 `live-handoff-final.xcresult`（大屏 Live 流程及交接复跑）、`small-live-ui.xcresult` 与 `small-live-final.xcresult`（小屏流程及生成保存复跑）、`picker-roundtrip-final.xcresult`（系统选图回归）。签名日志 `picker-fixed-release.log`。

模拟器验收不替代真实相机/iCloud/相册宿主与旧款 iPhone 内存、耗时测试；剩余边界列在 `KNOWN-ISSUES.md`。


## V4.0.1 手势与预览修复（2026-09-10）

- 根因：三个独立手势分别写入缩放/旋转/位移并结束撤销记录；移动超过阈值后跨格会被当成换图；每个变化取消当前整图预览，同时又生成多个推荐缩略图并调度保存。图片在拖动期间反复解码和滤镜处理，已完成的帧也可能被丢弃。
- 修复：单一 UIKit 识别器协调触点，按同一参考位置合成平移、缩放与旋转，触点数量改变时重建参考位置；当前手势完成后只提交一次撤销和保存。普通拖动不换图，长按后拖动才换图。边界按实际图片尺寸计算，放大后可平移至完整可用区域；镜像和旋转坐标一起处理。
- 预览：每个画布独立渲染队列，完成当前帧后接收最新请求，持续显示中间帧。缓存解码/滤镜后的像素，几何变化不反复处理；手势中冻结推荐预览并降低预览分辨率，结束恢复高清。缓存不持有动态文件租约，任务结束释放原始输入引用。
- 核心覆盖增至 144 项：完整常规回归先覆盖 142 项（141 通过、1 项需专门图库读取授权而跳过），最后的 9 项交互核心专项补齐无操作手势恢复保存、下一帧重新挂载素材等新增回归，全部通过。Live 原生解析、动态合成、草稿和导出回归保持通过；本次未把相册回读跳过项记作成功。
- iPhone 17：完整 33 条 UI 流程通过（原有 30 条 + 3 条主要手势用例），覆盖四分格缩放/旋转、单步撤销、慢拖动期间持续发布预览、跨格不误换图，以及长按交换。
- iPhone 16e：主要手势三条复跑通过；增加「调整」微调/复位、切换画笔后绘制并在图层列表确认涂鸦的专项。测试使用明确的 `g4-grid`，不再假定自动推荐的默认布局为四分格。
- 性能对照：4 张 2400×3200 JPEG、600×600 预览、30 次几何变化。同一渲染器无缓存为 33.80 ms/帧，缓存复用为 18.72 ms/帧（1.81×）；另一次为 33.42 / 19.28 ms。30 次变化只解码 4 张输入，未反复解码。数值来自模拟器、含同机负载差异，不能换算为真实 iPhone 帧率。
- 本机结果：`/private/tmp/jipin-gesture-fix/core-first.xcresult`、`small-final.xcresult`（常规核心）、`ui-full.xcresult`（完整 UI）、`final-targeted.xcresult`、`acceptance.xcresult`（最终核心与手势）、`drawing-verified.xcresult`（微调与画笔兼容）。中途修正了 UI 测试对默认布局、虚拟元素和涂鸦选中状态的假设。
- 4.0.1 (5) 正式归档与 App Store Connect 本地 IPA 导出成功；包大小 5,599,384 字节，SHA-256 `a45e80f4747d1920404b920e990458d46bddc8e9a5287fef78dfcf7686fe8aa0`。未上传 TestFlight；真实设备最终手感仍需安装此更新验证。


## V4.0.2 体验与导出回归（2026-09-10）

- 核心 145 项：144 通过、1 项原生相册保存后回读测试因未授予专项读取权限而跳过，0 失败。发布包依然仅声明添加照片用途。
- UI 共 38 条：完整运行 36 条通过，修正个人风格保存定位及导出脚本对固定操作区的判断后，清理测试运行器并重新构建，另两条原用例通过。最终 38 条均有通过记录；不是一次全量运行全部成功。
- 新增 4 条用户流程：真实照片模式预览并进入选定海报；直接套用风格并撤销、全部工具与文字标签；首屏直接保存；内置 Live 示例进入、预览并保留高清保存入口。
- 新增原生 Live 示例资源测试：安装包资源、独立照片标识、原生配对解析、3 秒时长、取消与 GPS 检查。原版草稿、撤销与跨模式复制继续回归。
- 大图测试发现已缩小素材重复走视频合成解码的等待，改为方向和尺寸已满足要求时直接读取视频轨道。大图、九路 Live、旋转素材专项通过，随后全部 Live 核心通过。
- Live 快速预览为最长边 640；保存、分享视频按用户选择的 1080 / 1440 再生成，静态导出仍生成所选静态尺寸。Live 保存、草稿重开、扩展草稿交接、系统选择器保留 Live 及转静态流程均通过。
- 设计目录已重新导出：46 布局、23 海报、84 贴纸、20 背景、10 滤镜、9 风格、6 装饰边框。24 个原创贴图渲染均不同且保留透明外围。
- 视觉核验：实图模式选择、固定保存、菜单文字、字号行距、新增贴图总览、个人风格保存自动定位与 Live 保存成功。截图见 `docs/version-screenshots/v4.0.2/`。
- 结果目录 `build/Validation-4.0.2/`：`FullRegression.xcresult`、`CleanFinalFlows.xcresult`、`MediaAndNewUI.xcresult`、`validation-summary.json`、日志和分发包核验 JSON。最终覆盖 183 个不同用例，182 通过、1 跳过，没有剩余失败项。
- 主 App 与扩展都是 4.0.2 / 6；正式签名归档和本地 App Store Connect IPA 导出通过。Apple Distribution、嵌套签名、App Group、`get-task-allow=false`、`beta-reports-active=true`、四个内置 Live 文件哈希均核验通过。
- 最终 IPA：`build/TestFlight/JiPin-4.0.2-6/Export/JiPin.ipa`，8,900,654 字节；SHA-256 `fc8053062ba1017792fdd0aa2d8b320eea69a08642d18c8bdc26063b10dd2bc0`。尚未上传 TestFlight。

模拟器不替代真实相机/iCloud/照片宿主及低内存设备验收。原生图库回读的跳过项没有计入通过数量。

## V4.0.3 长图滚动修复（2026-09-11）

- 使用旧版识别器、相同照片区域触点重现无法纵向滚动：`BeforeFixPhotoSwipe.xcresult` 按预期失败。
- iPhone 17 / iOS 26.3：9 个核心用例、4 个原模板手势用例通过。5 个新增长图用例中，4 个首轮通过；多指撤销用例原先假设合成捏合不改变角度，改为比较每次实际手势前后的角度、缩放和撤销状态后通过。
- iPhone 16e / iOS 26.3：5 个新增长图用例全部通过，覆盖纵横直接滑动、无额外撤销、Live 工具页保持及原生导出、双指编辑后恢复浏览、长按交换。
- 最终 18 个不同测试均取得通过结果；原有核心几何与缓存测试、模板编辑和画笔操作没有回归。未把对照失败或首次断言失败算作通过。
- 证据：`build/Validation-4.0.3/GestureRegression.xcresult`、`FinalGestureUndo.xcresult`、`SmallPhone.xcresult`、`validation-summary.json`。最终模拟器截图见 `docs/version-screenshots/v4.0.3/`。
- 触点定位按导航栏与工具栏之间的真实可见区域计算，避免 SwiftUI 的全屏 ScrollView AX frame 让测试误触底部工具区。
- 本轮没有替代用户真机确认；未声明物理设备帧率或完成 App Store 所要求的真机录屏。

## V4.0.4 默认高清与保存后关闭（2026-09-11）

- `ExportRegression.xcresult`：首轮 69 项中 68 通过，1 项界面尺寸断言因系统千位分隔格式失败；产品默认值、实际尺寸和保存流程已工作。
- `FinalExportFlow.xcresult`：规范化尺寸显示后的高清保存用例，以及长图直接滑动回归，2 项通过。
- `DeniedPermission.xcresult`：在新建 iPhone 16e 模拟器真实拒绝添加照片权限，1 项通过；窗口没有关闭，错误与重试按钮保留。
- 汇总 71 个不同用例全部取得通过结果；包含核心导出/分页、Live 保存与系统选图、静态/Live/分页保存自动关闭、手动标准选择保留及旧草稿编解码。
- 证据与按用例汇总记录位于 `build/Validation-4.0.4/`，最终截图位于 `docs/version-screenshots/v4.0.4/`。


## V4.0.5 Live 预览刷新修复（2026-09-11）

- 旧版对照复现：预览成功后选择 2 秒，30 秒内仍只有占位图。`BeforeFix.xcresult` 中原用例按预期失败。
- 修改设置后自动生成新预览，250 毫秒合并连续变化。旧任务取消后先完成清理，再释放其持有的导出锁；失效请求不能写入新的预览、提示或状态。
- 四条新增 UI 回归在 iPhone 17、iPhone 16e / iOS 26.3 上分别全部通过：全部时长播放、连续变化与三 Live 两静态混拼保存、关闭重开与撤销、清晰度与手动重新生成。预览断言读取实际生成结果的时长。
- 回归 16 条 Live 核心、5 条既有 Live UI、5 条长图手势、2 条清晰度/嵌套保存流程。共 32 个不同用例，31 通过、1 个需专门图库读取权限的 PhotoKit 回读用例跳过，0 失败。
- 证据：`build/Validation-4.0.5/PreviewRegression.xcresult`、`Compatibility.xcresult`、`SmallPhone.xcresult`、`validation-summary.json`；截图为原创模拟器素材，位于 `docs/version-screenshots/v4.0.5/`。
- 主 App 和扩展为 4.0.5 / 9，正式签名归档和 IPA 导出完成，签名、版本、App Group 和分发权限校验通过。真机上的原始照片场景仍以用户安装更新后的体验为准。

- 发布结果：4.0.5（9）已于 2026-09-11 上传并处理完成，内测“正在测试”，公测“正在等待审核”。代码提交 `860e187`；分发状态见 `build/Validation-4.0.5/testflight-status.json`。
