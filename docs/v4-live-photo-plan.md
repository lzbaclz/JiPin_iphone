# 极拼 V4.0：Live Photo 拼图

## 交付目标

从系统选择器导入苹果 Live Photo，保留静态画面和动态视频；与静态图片混排后，导出能被 PhotoKit 识别、保存到系统“照片”并长按播放的原生 Live Photo。沿用四种拼图模式、裁切、滤镜、文字、贴图、边框、图层与草稿。

## 交互与范围

- 普通选图、添加和替换照片自动保留 Live 动态；首页提供 Live 入口方便发现。
- 每份作品最多使用 9 个不同 Live 来源，静态图片仍受原模式数量限制；超限明确提示，不把失败的 Live 静默变成静态图。
- 动态围绕原照片拍摄时刻对齐，默认 3 秒，可选 1.5、2、3 秒；不足部分保持首/尾帧。封面取输出中间帧，避免封面和动态接不上。
- 默认静音；可保留其中一个 Live 来源的声音，避免多段声音叠在一起。
- 标准输出最长边 1080、高清最长边 1440、30 fps；采用 SDR JPEG + H.264 MOV，优先兼容 iOS 17+。原始相册资源不修改。
- 带 Live 的作品默认进入 Live 导出，展示原生动态预览，保存 Live 到相册；同时提供视频分享和既有静态导出。
- 相册操作扩展识别到 Live 时保留动态草稿交接，完整 Live 导出在主 App 进行，避免扩展内存限制。

## 技术路径

1. 使用 `PhotosPickerItem.loadTransferable(type: PHLivePhoto.self)` 和 `PHAssetResource.assetResources(for:)` 导出所选 Live 的资源，不申请全相册读取权限。不依赖 `supportedContentTypes` 判断 Live：系统可能只列出 JPEG/HEIC，但仍提供完整 PHLivePhoto；原生读取错误明确报告，普通照片无 Live 表示时继续原有去元数据流程。
2. 原始动态文件保存在本机，工作文件有生命周期管理；草稿用版本化描述引用共享视频文件，原子写入，复制、撤销和删除不能误删仍在使用的视频。
3. AVFoundation 顺序解码多个视频，对大尺寸来源先逐张生成较小的工作视频，再限定每路解码尺寸；共享拼图渲染器逐帧合成，避免逐帧 JPEG 中转和整段视频常驻内存。
4. 写出图片标识符、MOV content identifier 和 still-image-time 元数据，生成配对资源；以 PhotoKit 实际加载验证成功后才提供保存。
5. 使用 `PHAssetCreationRequest` 的 `.photo` 与 `.pairedVideo` 成对保存。视频分享按视频交付；各社交平台对 Live 的支持由接收端决定。

## 验收

- 原生 Live 资源导入、静态混拼、取消/iCloud 失败、源文件缺失、上限、旋转、裁切、图层、滤镜、半透明和声音选择。
- 多个来源在输出中均有真实帧变化，静态装饰保持一致；封面与对应帧一致。
- PhotoKit 能加载生成的 Live Photo；保存后仍为 Live 资源，动态视频和封面标识匹配，导出不继承 GPS。
- 草稿重开/复制/删除/撤销后的动态资源完整；V1–V3 草稿向后读取兼容。
- 模拟器核心和界面回归、签名 Release 归档与分发包导出。真机未验证的部分如实记录。
- V4.0 落地后单独 commit；上传 TestFlight 和发送邀请另按明确发布指令执行。

## 官方依据

- [PHLivePhoto](https://developer.apple.com/documentation/photos/phlivephoto)：资源加载、原生 Live Photo 表示与 Transferable。
- [导出 Live Photo 底层资源](https://developer.apple.com/documentation/photos/phassetresource/assetresources(for:)-2fedw)：图片、动态与声音资源。
- [PHAssetCreationRequest](https://developer.apple.com/documentation/photos/phassetcreationrequest)：成对保存图片和 pairedVideo。
- 本机 iOS 26.2 SDK 的 `_PhotosUI_SwiftUI.swiftinterface` 确认 PHLivePhoto 的 Transferable 支持始于 iOS 16，本项目最低为 iOS 17。
