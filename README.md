# 即拼 JiPin 官网

照片在一起，回忆会动。

- 官网：<https://lzbaclz.github.io/JiPin_iphone/>
- 支持：<https://lzbaclz.github.io/JiPin_iphone/support.html>
- 隐私：<https://lzbaclz.github.io/JiPin_iphone/privacy.html>
- 旧版归档：<https://lzbaclz.github.io/JiPin_iphone/archive/2026-09-11-v1/>
- 客服：`chestnutlee23@163.com`

## Web V2 · 中国山水

以可爱日常与山河旅行两套 Live 成品展示玩法，保留即拼橘红品牌色，使用更轻快的暖色背景与字体。三张 AI 山水原图分别取意漓江喀斯特、黄山松石云海和三峡江湾；三张原生 Live 素材和一张合成成品由即拼现有 `JiPinCore` 生成并经过 Apple PhotoKit 识别。

- 首页展示真正经即拼渲染的 Live 拼图，提供主动播放、暂停和静态封面。
- 原图、配对 JPEG/MOV、网页 MP4、静态成品、提示词和生成源码完整保留，来源明确标为 AI 生成。
- 模板、自由、海报、长图切换真实渲染成品，操作界面单独预览。
- 保留原创贴纸添加、拖动、键盘移动、删除和重置，分成可爱与酷风两组。
- 正文以 16px 起，常用标签以 14px 起，辅助信息不低于 12px；减少英文装饰和重复文案。
- 品牌故事保留，版本历程收进可展开内容。
- 手机下载区优先显示加入按钮和两步安装说明，二维码在“分享给朋友”中展开；桌面直接显示扫码入口。
- 无自动播放，页面离开或切到后台暂停视频；无照片上传、广告、账号或统计脚本。

## 旧版保留

归档对应提交 `1670e750b1c75db71b8c9fa41d900e42b3180a33`，Git 标签 `web/v1-2026-09-11`。`archive/2026-09-11-v1/` 保留该提交的全部 42 个原始文件，字节不变，支持独立浏览。改版不会修改此快照。

旧版页面的相对资源、帮助和隐私链接仍可使用。新页面页脚提供“旧版官网归档”入口。

## 项目结构

纯静态 HTML / CSS / JavaScript，无框架构建依赖，继续使用现有 GitHub Pages，不改变 App 发版流程。

| 路径 | 内容 |
| --- | --- |
| `index.html`、`landing.css`、`landing.js` | 主站布局、样式、交互 |
| `site-config.js` | App Store / TestFlight 真实公开链接及开放状态 |
| `testflight-invite.mjs` | 本地二维码编码、下载、复制邀请 |
| `assets/shanhe/` | 新山水原图、视频、成品、提示词及原生配对 |
| `tools/native-live/` | 基于即拼核心的素材生成源码与说明 |
| `support.html`、`privacy.html`、`styles.css` | 帮助和隐私页面 |
| `archive/` | 旧版完整快照 |

素材来源与动态制作范围见 [ASSETS.md](ASSETS.md)。既有 App 截图仍注明 4.0.1，支持页保留 4.0.3、4.0.4 的操作更新，不把旧截图说成新版本界面。

## 预览与验证

```sh
python3 -m http.server 8769 --bind 127.0.0.1
```

检查桌面和手机布局、四种模式、视频播放/暂停/离屏停止、贴纸的触控和键盘操作、截图弹窗、邀请复制、二维码、FAQ 和归档入口。JavaScript 关闭时，原生视频控件、静态内容、帮助、隐私和 TestFlight 链接仍可使用。

## 邀请配置

`site-config.js` 当前保留公开群组的真实链接：`https://testflight.apple.com/join/1NqZxpgX`。`testFlightStatus: "open"` 表示公开邀请已开放；该状态不会自动向 Apple 查询。新构建外测审核、名额与构建有效期仍由 App Store Connect 管理，TestFlight 开放不代表 App Store 正式版审核通过。

空链接隐藏对应入口；只有规范 HTTPS 官方链接会启用。`pending-review` 显示待审核说明。二维码与按钮使用同一个规范化链接，不在码面覆盖 Logo。

安装说明参照 [Apple TestFlight](https://testflight.apple.com/)，安装链接使用 [Apple 官方 TestFlight 页面](https://apps.apple.com/us/app/testflight/id899247664)。公开邀请无需手填邀请码。

## 发布

GitHub Pages：分支 `codex/app-store-pages`，根目录 `/`，HTTPS。正常快进推送后由 GitHub Pages 发布；不强制覆盖发布分支，不把 iOS 主工程改动带入网站提交。CSS / JS 采用内容版本参数避免缓存混用。

```sh
git fetch origin codex/app-store-pages
git merge-base --is-ancestor origin/codex/app-store-pages HEAD
git push origin HEAD:codex/app-store-pages
```

当前未持有 `jipin.com`，不设置自定义域名或 CNAME；取得域名后参照 [DOMAIN_SETUP.md](DOMAIN_SETUP.md)。仅视觉改版不改变隐私政策生效日期。


## 2026-09-11 名称、主题与预览修复

- 当前页面（首页、支持、隐私）统一使用用户确认的品牌名“即拼”；旧版归档作为历史快照保留。
- 首页和贴纸体验加入小兔、小熊；四种玩法可切换“可爱日常”和“山河旅行”。
- 长图有独立滚动区域、始终可见的纵向滑块、浏览进度和上下浏览按钮。滚动位置与滑块双向同步，播放时保持当前位置。
- 两种主题的四种玩法都配有真实动态成品预览。切换主题/模式会停止旧视频并重置播放按钮；取消旧视频加载不会误报播放失败。
- 八份成品来自 App 4.0.6 的原生导出流程，经 PhotoKit 配对检查。网页 MP4 仅负责播放；FAQ 提供 Mac 可导入的原生照片/视频配对 ZIP，明确单独下载封面不能成为 Live。
- 原生生成证据：`assets/examples/validation.json`；视频抽帧检查：`assets/examples/playback-validation.json`（每个视频的 12 个采样帧都不同）。生成源码：`tools/native-live/MixedExamples.swift`。
- 浏览器已逐一验证八个播放器、主题/玩法切换、长图滑块与到顶/到底，另以 390 像素 iframe 检查窄屏布局及点击操作。
