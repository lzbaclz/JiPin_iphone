# 极拼官网的自定义域名

当前可用地址：<https://lzbaclz.github.io/JiPin_iphone/>。

## 当前状态

`jipin.com` 已被注册，目前不属于项目所有者。2026 年 9 月 10 日核查时，`www.jipin.com` 指向该域名的现有服务器。GitHub Pages 不能替我们取得域名所有权。

因此本次没有创建 `CNAME`，也没有修改 GitHub Pages 的 Custom domain。现有 Pages 地址继续工作。请先取得想使用的域名及其 DNS 管理权限，再进行以下操作。

## 取得域名后再绑定

1. 在 GitHub **个人设置 → Pages → Add a domain** 验证自己的域名。按照该页面提供的记录名和验证码，到域名平台添加 TXT 记录。不要猜测验证码。
2. 打开本仓库 **Settings → Pages → Custom domain**，填写实际持有的完整域名，例如取得所有权后的 `www.jipin.com`，保存。
3. 在域名平台的 DNS 设置中添加：

   | 类型 | 名称 | 目标 |
   | --- | --- | --- |
   | CNAME | `www` | `lzbaclz.github.io` |

   CNAME 的目标只有主机名，不能包含 `https://`，也不能带 `/JiPin_iphone/` 路径。已有同名的冲突 DNS 记录需依据域名平台指引处理。
4. GitHub 会在发布分支根目录创建 `CNAME` 文件，内容为完整自定义域名。同步回本地并保留该文件，避免后续发布移除绑定。若通过命令行配置，则需在该分支自行提交同等内容的 `CNAME` 文件。
5. 等待 DNS 检查与 HTTPS 证书就绪，勾选 **Enforce HTTPS**。最终宣传链接使用 `https://`。
6. 将 `index.html` 的 canonical、Open Graph URL / image，以及 `sitemap.xml` 中的地址更新为新域名；添加适用于新域名根目录的 `robots.txt`。站内链接使用相对路径，可继续工作。
7. 检查首页、支持页、隐私政策和下载链接。若还希望不带 `www` 的根域名也能访问，请按 GitHub 官方文档配置根域名记录及重定向，勿随意照抄其他服务商 IP。

网站可以先在 GitHub Pages 上发布，域名后续再接入。不需要为了等待域名而停掉网站。

参考：[管理 GitHub Pages 自定义域名](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site)、[验证自定义域名](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/verifying-your-custom-domain-for-github-pages)。
