# 极拼草稿格式与迁移说明

草稿保存在 App Group `group.com.jipin.JiPin` 的 `Drafts/{uuid}/` 目录，照片位图放在同容器的 `SharedAssets/` 中按素材 UUID 共享。主 App 与相册操作扩展共用该容器。若 App Group 不可用（例如尚未签名），则回退到 App 沙盒 Documents。

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

写入流程：先把仍被引用的素材写入 `SharedAssets/`，再把项目文件写到 `{uuid}.tmp/`，全部落盘后再写入 `.complete`，最后 rename 到 `{uuid}/`。没有 `.complete` 的目录不会出现在可继续编辑列表中。复制草稿只增加项目记录，不复制已存在的共享素材；删除草稿后，只有不再被任何完整草稿引用的素材才会从 `SharedAssets/` 回收。导出缓存可单独清理，不得删除草稿或共享素材。

## project.json

JSON，ISO-8601 日期。关键字段：

- `schemaVersion`：当前为 `1`
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

读取时若 `schemaVersion` 低于当前版本，应在加载处做字段默认值兼容（缺失字段使用模型默认值）。提高 schema 时需：

1. 增加版本号
2. 为旧草稿补默认值
3. 保留旧素材文件

撤销历史只存在于本次编辑会话，重启后不恢复 50 步命令栈。导出缓存位于 `ExportCache/`，清理缓存不得删除 Drafts。
