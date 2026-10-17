# UI 纹理自动导入规则

项目已启用 `addons/ui_texture_import/` 编辑器插件。在 Godot 编辑器首次导入或重新导入指定 PNG 前，插件为内置纹理导入器写入以下设置：

| 设置 | 值 |
| --- | --- |
| `mipmaps/generate` | `true` |
| `compress/mode` | `0`（无损） |
| `process/fix_alpha_border` | `true` |
| `process/size_limit` | `0`（保留原始尺寸） |

自动处理范围：

- `assets/cards/cute_v22/`
- `assets/ui/card_quality/`
- `assets/ui/downloaded_20261011/`
- `assets/ui/inventory_icons_soft_edges_20261016/`
- `assets/ui/pack/combat/` 和 `combat32/` 中的 `card_energy.png`、`link.png`、`block_counter.png`。

这些目录中的新 PNG 自动沿用设置；混合目录按明确文件名处理，不根据目录名或图片尺寸猜测像素风。新增非像素 UI 素材目录或混合目录图标时，更新 `plugin.gd` 对应名单。

插件只处理本轮正在导入的文件，不扫描旧素材、不修改 PNG 原图和全局过滤；已有 UID、其他导入参数以及未纳入名单的像素图片保持原样。已配置为其他导入器或跳过导入的资源不接管。插件运行在编辑器中，不进入游戏运行流程。

控件仍须使用 `LINEAR_WITH_MIPMAPS`，自定义图片采样器仍须使用 `filter_linear_mipmap`；插件只负责持久化的素材导入配置。PNG 与生成的 `.import` 一起提交，`.godot` 缓存不入库。

功能依据是 Godot 的 [EditorFileSystem.resources_reimporting](https://docs.godotengine.org/en/stable/classes/class_editorfilesystem.html#class-editorfilesystem-signal-resources-reimporting) 信号，在内置导入器读取配置前应用规则，无需再次触发导入。

2026-10-17 使用实际插件进行首次导入及重新导入检查：11 张样本的真实纹理尺寸与 mip 层符合预期，包含新卡图、品质框、菜单和背包图标、指定战斗图标，以及 3 张不应接管的像素图片。重新纠正一张导入配置后，已有 10 份 `.import`（含 UID 和像素设置）与纠正前逐字节一致。项目编辑器启动成功，无脚本或导入错误；仍有旧预览图片重复 UID 的既有警告。相关日志位于 `预览/texture_import_policy_20261017/`。
