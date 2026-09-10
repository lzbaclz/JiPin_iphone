# 极拼支持网站

本分支 `codex/app-store-pages` 仅包含极拼的公开支持页和隐私政策页。iOS App 源码继续保存在 `main` 分支。

- 支持页：`index.html`
- 隐私政策：`privacy.html`
- 样式：`styles.css`
- 品牌图标：`assets/app-icon.png`，复用主工程 AppIcon。
- 公开客服邮箱：`chestnutlee23@163.com`

通过 GitHub Pages 的 **Deploy from a branch** 发布本分支根目录 `/`。页面使用静态 HTML/CSS，没有构建依赖、统计脚本、外部字体或账号系统。

App 数据处理说明依据 4.0.1 的系统选图、添加照片权限、草稿存储、Live 工作副本及导出实现整理。更新功能或数据处理方式时，需要同时维护隐私政策内容和更新日期。

上线前可使用 `python3 -m http.server 8769 --bind 127.0.0.1` 本地预览。检查两页导航、联系邮箱、手机显示和隐私链接后，再提交并推送到本分支。
