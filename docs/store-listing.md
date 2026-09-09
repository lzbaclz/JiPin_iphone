# 极拼 App Store 上架资料（草稿）

对照 `docs/iphone-photo-collage-project-plan.md` 第十四节。本机尚未接入开发者账号，下列文案供提交时粘贴；TestFlight、备案主体和最终截图需在签名真机包上完成。

## 基本信息

| 项 | 建议值 |
| --- | --- |
| 名称 | 极拼 |
| 副标题 | 模板、自由、海报与长图拼图 |
| 类别 | 摄影与录像 |
| 年龄分级 | 按实际内容填写问卷，由 App Store Connect 生成最终分级 |
| 最低系统 | iOS 17 |
| 设备 | iPhone |
| 价格 | 免费 |

## App 隐私（营养标签）

首版不收集数据。

- 未用于跟踪的数据：无
- 与用户关联的数据：无
- 未与用户关联的数据：无
- 不接入账号、广告或第三方分析
- 照片仅在本机处理；只有用户点「保存到相册」才申请添加照片权限
- 导出成品不复制 GPS 等位置元数据

隐私政策在 App 设置中，并见工程内 `PrivacyPolicyView`。

## 审核说明（给 App Review）

极拼是本地拼图工具，随安装包提供相册 **Action Extension**。

提交前由开发者配置同一 Development Team 与 App Group，审核人员无需修改工程。

1. 主 App：打开极拼 → 选择照片或「用示例插画体验」→ 四种模式均可编辑并导出。不必登录。
2. 模式卡可直接打开系统选图；首次使用也可用原创插画体验。
3. 相册入口：不必先打开主 App。系统「照片」多选 2 到 9 张 → 分享 → **操作区**「极拼」（不是相册原生工具栏）。扩展可模板/长图快拼、保存到相册、系统分享、保存草稿。
4. 草稿交接：扩展内「更多 → 保存草稿」后，打开极拼 → 草稿，应看到「来自相册」条目。
5. 拒绝「添加照片」后，项目仍可保存为草稿或用系统分享，不要求读取整个图库。

演示账号：无。内购：无。

## 商店截图

按 App Store 常见竖屏尺寸导出到 `docs/store-screenshots/`（6.9" iPhone 17 Pro Max、6.3" iPhone 17）：

1. 创作首页
2. 模板编辑器
3. 自由拼图编辑器
4. 海报编辑器
5. 相册快拼
6. 设置
7. 长图编辑器

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
chmod +x scripts/export-store-screenshots.sh
./scripts/export-store-screenshots.sh
```

`JiPinUITests/testStoreScreenshotAttachments` 仍会把同类画面附在 xcresult 中。现有截图使用项目原创插画，提交前可换成获得授权的实拍素材，并复核最终发布包显示。

## 中国大陆

若首发包含中国大陆，需按 App Store Connect 当时要求核对准营证件、备案号与主体名称，并与开发者账号一致。本仓库不包含这些资料。
