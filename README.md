# 极拼 JiPin 官网

**照片在一起，回忆会动。**

极拼的产品介绍、使用帮助与隐私政策网站。继续使用现有 GitHub Pages，不改变 iOS 主工程或 App 发版流程。

- 官网：<https://lzbaclz.github.io/JiPin_iphone/>
- 支持与帮助：<https://lzbaclz.github.io/JiPin_iphone/support.html>
- 隐私政策：<https://lzbaclz.github.io/JiPin_iphone/privacy.html>
- 公开客服邮箱：`chestnutlee23@163.com`

## 页面内容

- 珊瑚橙与奶油色的产品首页，展示极拼实际界面。
- 模板、自由、海报、长图四种可切换排版示意，以及对应 App 截图预览。
- 用户点击播放的 3 秒 Live 拼图效果演示，明确区分网页视频与 App 内的原生 Live 导出。
- 原创贴纸体验：点击添加、拖动、键盘移动、删除、重新开始；最多 8 张。
- 相册入口、草稿、本地编辑介绍，V1–V4 发展历程，以及常见问题。
- 公开下载入口可用后再启用按钮；当前显示“即将上线”。

产品描述与截图依据 4.0.1，不把正在开发中的功能写成已发布能力。没有虚构用户数量、评分、评价或下载入口。

## 文件

| 文件 | 作用 |
| --- | --- |
| `index.html` | 宣传首页 |
| `landing.css` / `landing.js` | 首页响应式样式及原生 JavaScript 互动 |
| `site-config.js` | 已验证的 App Store / TestFlight 公开链接 |
| `support.html` | 原来的操作帮助内容 |
| `privacy.html` / `styles.css` | 原隐私政策及帮助页面样式 |
| `assets/` | 本地托管的图标、截图、原创插画、贴纸和短视频 |
| `sitemap.xml` | 当前公开页面地址 |
| `ASSETS.md` | 素材来源与示意范围 |
| `DOMAIN_SETUP.md` | 取得域名所有权后的绑定步骤 |

纯静态 HTML / CSS / JavaScript，无构建依赖、账号、广告、统计脚本或外部字体。互动体验不上传或保存访问者数据。关闭 JavaScript 时，产品介绍、视频原生控件、FAQ、支持页和隐私政策仍可阅读。

## 本地预览

在本目录执行：

```sh
python3 -m http.server 8769 --bind 127.0.0.1
```

打开 <http://127.0.0.1:8769/>。发布前检查桌面及手机显示、四种模式切换、截图弹窗、视频、贴纸拖动与键盘操作、导航和隐私链接。

## 启用下载入口

在 `site-config.js` 中填入真实可访问的链接，空字符串表示尚未开放：

```js
window.JIPIN_SITE = Object.freeze({
  appStoreURL: "",
  testFlightURL: ""
});
```

App Store 链接需以 `https://apps.apple.com/` 开头并指向 App 页面；TestFlight 链接需以 `https://testflight.apple.com/join/` 开头。不要使用 App Store Connect 后台链接或其他 App 的测试链接。

页面只展示有效格式的配置，至少一个入口可用时隐藏“即将上线”。仍需维护者在发布前实际确认链接可用；前端格式检查不代表已通过 Apple 审核。

## 发布

仓库 **Settings → Pages → Deploy from a branch**：

- 分支：`codex/app-store-pages`
- 目录：`/ (root)`
- HTTPS：已启用

CSS 和 JavaScript 链接带有内容版本参数。修改这些文件时，同步更新 HTML 中相应的 `?v=` 参数，避免旧浏览器缓存混用新页面。

提交并正常推送到该分支后，GitHub Pages 自动部署。若从独立网站工作分支开发，先确认远端发布分支没有别人更新，再使用普通快进推送：

```sh
git fetch origin codex/app-store-pages
git merge-base --is-ancestor origin/codex/app-store-pages HEAD
git push origin HEAD:codex/app-store-pages
```

不要强制覆盖发布分支，也不要把 iOS 主工程的未提交改动带入网站提交。iOS 源码保留在 `main`，网站单独发布。

当前不持有 `jipin.com`，因此没有设置自定义域名或 `CNAME`。取得域名后参照 [域名配置说明](DOMAIN_SETUP.md) 处理。

App 功能或数据处理方式变化时，需要同时维护产品文案、操作帮助和隐私政策。仅改外观不会改变隐私政策的生效日期。
