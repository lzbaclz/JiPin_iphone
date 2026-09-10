# 极拼草稿格式与迁移说明

草稿保存在 App Group `group.com.jipin.JiPin` 的 `Drafts/{uuid}/` 目录，照片工作副本放在同容器的 `SharedAssets/` 中按素材 UUID 共享。主 App 在 App Group 不可用时回退到自己的 Documents；实际相册扩展在无法共享时拒绝草稿交接并明确提示，可继续保存图片或分享。

## 目录

```
Drafts/{project-id}/
  project.json      项目参数（不含位图）
  thumbnail.jpg     预览缩略图
  .complete         原子提交完成标记
  assets/           仅旧版草稿可能仍有按项目复制的素材；读取时作为回退

SharedAssets/
  {asset-id}.jpg|.png|.dat

ExportCache/
```

写入流程在进程内递归锁和同容器 `.jipin-store.lock` 的文件锁内进行，主 App 与扩展遵守同一把锁。

1. 将不可变素材写入 `SharedAssets/`；同一 UUID 若对应不同内容则拒绝覆盖。缺失素材也会阻止替换旧草稿。
2. 在隐藏的 `.{project-id}.{transaction-id}.tmp/` 中写入 `project.json`、缩略图和 `.complete`。
3. 首次保存使用排他 rename；替换已有草稿使用 Darwin `renamex_np` 的 `RENAME_SWAP` 原子交换。不会先删除旧草稿再移动新目录。
4. 提交成功后回收旧目录和不再使用的共享素材；清理失败不撤回已经成功的保存。提交失败则保留旧目录和缩略图。

没有 `.complete`、临时名称或不能解码的目录不会作为可编辑草稿展示。回收器遇到无法识别的完整草稿时保守停止回收，避免误删仍被引用的素材。复制草稿共享不可变素材；删除最后一份引用该素材的草稿后才回收文件。

缩略图与磁盘写入在串行后台任务中完成。旧的排队快照不会覆盖本进程已经提交的更新快照；退出编辑器会等待当前修改保存成功。相册快速编辑默认不自动建立草稿，用户明确选择保存草稿时才写入。

`Drafts`、`SharedAssets` 和 `ExportCache` 均排除云备份。PNG 工作副本保留透明度；导入去除元数据并将主 App 的解码量限制为约 1600 万像素，扩展为约 400 万像素。系统相册原图不改变。

## project.json

JSON，ISO-8601 日期。关键字段：

- `schemaVersion`：当前为 `3`
- `id`、`name`、`mode`（`template` / `freeform` / `poster` / `longStrip`）
- `canvas`：宽高比
- `background`、`layoutID` / `posterID`、`longStrip`
- `objects`：图层（照片、文字、贴纸、形状、涂鸦）
- `photoOrder`：素材 UUID 顺序
- `spacing`、`outerMargin`、`snapEnabled`
- `exportPreference`
- `originatedFromExtension`

坐标按画布 0–1 归一化保存。照片数据在 `SharedAssets/`（或旧草稿的 `assets/`）中，不保存系统相册临时地址。

## 迁移

当前结构仍为 schema 1，兼容已有 schema 1 草稿和旧的每草稿 `assets/` 目录。高于当前版本的草稿会拒绝打开，避免错误重写。提高 schema 时需显式实现并测试迁移，不能假定 Swift 的属性默认值会自动填补解码缺失字段：

1. 增加版本号
2. 为旧草稿补默认值
3. 保留旧素材文件

撤销历史只存在于本次编辑会话，重启后不恢复 50 步命令栈。导出缓存位于 `ExportCache/`，清理缓存不得删除 Drafts。
## V2 兼容性补充

V2 写入的新项目 schemaVersion 为 2，支持可选 `customLayoutCells`。不存在该字段的 V1 草稿仍可读取；移动分隔线后标记为 V2，旧版会拒绝读取更高版本。自定义格子必须数量匹配且完整覆盖单位画布，否则回退到基础布局。换模板或改变照片数量时重建布局；同数量换图/排序保留自定义分隔线。

`StyleRecipes/styles.json` 与草稿分开，原子保存最多 30 套个人风格（界面限制）。风格不含照片 UUID、图片数据、文字、图层或布局；图片背景转为对应底色。目录不参与系统云备份。分页文件保存在独立临时批次目录，失败/取消会清除未完成批次，关闭导出页后清理已经生成的临时文件。

## V3 兼容性补充

V3 新项目 schemaVersion 为 3；V1/V2 草稿仍可读取。可选 `decorationFrame` 保存画布装饰边框的 `frameID` 和相对短边的 `width`，缺字段时无边框。插入新贴图或应用边框后更新 schema，避免旧版忽略新素材后错误导出。

原创贴图使用稳定 ID `cute-*` / `cool-*`，渲染定义随 App 打包，不依赖相册、网络、emoji 字体或临时 PNG。画布装饰在图层之后绘制，跨模式复制保留，分页使用整幅画布坐标；未知边框会阻止不完整导出。装饰边框不进入“我的风格”，与文字、布局一样保存在作品草稿内。
