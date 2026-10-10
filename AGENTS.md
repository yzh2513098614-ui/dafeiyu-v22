# 大肥鱼 · 数值战斗怪物 v22

Godot 2.5D 卡牌搜打撤原型。本文件是**唯一入口**，供 Codex / Claude Code / DSH 等 agent 会话自动加载。
汇报与说明用简体中文；代码、路径、命令、日志保持原文。

## 三行必读

- **引擎**：Godot 4.7.2（`%USERPROFILE%\Godot\Godot_v4.7.2-stable_win64.exe`），缺失时回落 4.6.2。渲染 GL Compatibility。
- **启动**：双击 `开始试玩.cmd`，或 Godot 打开 `project.godot` 后 F5。启动脚本 `tools\launch_game.ps1`，运行日志落在 `play_stdout.log` / `play_stderr.log`。
- **主场景**：`project.godot` 的 `run/main_scene` = `ui/start_menu.tscn`。**以 project.godot 为准**——`00_打开与试玩.md` 里写的 `district/continuous_world.tscn` 是标题菜单之后的世界场景，不是启动入口。世界主入口为 `district/continuous_world.gd`。

> 素材批次号 `jimeng_v24` ≠ 工程版本 v22。**不要按素材目录名新建或切换工程**，也不要用 v19/v20 或备份目录覆盖当前文件。

## 权威文档怎么读

这个工程有 60+ 份 md，绝大多数是**单轮改动的说明**，不是当前状态。按下面的顺序取信：

| 用途 | 文件 | 时效 |
|---|---|---|
| 当前实现状态 | `项目现状_v22.md` | 10-05，**相对最可信** |
| 目标形态与设计意图 | `docs/GDD_v0.2_20261008.md` | 10-08，**前瞻总纲，不是实现状态** |
| 本轮改动细节 | 根目录 `00_*_v22.md`（按日期挑最新） | 10-09 / 10-10 |
| 已知缺陷与实测数据 | `现状不足分析_v22.md` | 10-03，**部分结论已失效，见 `TASKS.md`** |
| 素材清点 | `docs/素材清点_20261010.md` + `.csv` | 10-10 |
| 待办与回归清单 | `TASKS.md` | 滚动更新 |
| 验证脚本索引 | `tools/README.md` | 滚动更新 |

`README.md` 与 `00_打开与试玩.md` 的下半部分描述的是 v8/v16 时代（四方向人物、三房间、`room.tscn`），**不要当作当前状态引用**。

⚠️ **GDD 与当前实现的落差**：GDD 描述的是「三指令队列 + 同步结算 / 8×8 隐藏战术格子 / 暗房非显示怪 / 撤离系统」。当前可玩的是 **42 张卡的抽牌+算力制回合战斗**，格子化战斗与暗房遭遇尚未成为主路径。读 GDD 时请当设计目标，不要当现状。
`expedition/`（`combat_simulator.gd` / `enemy_planner.gd` / `tactical_grid.gd` / `encounter_director.gd`）是 GDD 那套三指令同步结算的对应实现，属于并行的实验线。

## 目录职责

| 路径 | 负责什么 |
|---|---|
| `battle/battle_engine.gd` | 战斗规则、行动结算、状态与事件快照。**表现层不得消耗战斗随机数** |
| `battle/battle_screen.gd` | 战斗界面、输入、排版、演出播放与显示同步（含倍速 SPEEDS=[1,2,4]） |
| `combat/combat_controller.gd` | 地图遭遇、人物与背包接入、道具保存失败回滚、奖励与练习 |
| `district/continuous_world.gd` | 世界主入口 |
| `district/packed_floor.gd` / `floor_partitions.gd` | 楼层生成与四种分区（错位双排 / 侧厅嵌合 / 梯级叠房 / 中央套间） |
| `district/courtyard_scenes.gd` / `container_rooms.gd` | 四处庭院 / 仓储带 13 个特殊地点 |
| `room_3d.gd` + `room_3d.tscn` | 2.5D 房间场景、人物渲染、输入、房间级 UI |
| `character/life_state.gd` | 属性、成长、**存档校验（类型/范围/装备槽/白名单）** |
| `character/character_controller.gd` | 人物移动、方向选择、状态 HUD |
| `loot_controller.gd` / `meme_chest.gd` | 容器交互、背包、箱子存档 |
| `dialogue/dialogue_controller.gd` | 对话、立绘、选项、自动播放 |
| `ui/harbor_start.gd` / `ui/start_menu.tscn` | 开始界面（八个出发点、继续游戏、设置、音乐鉴赏） |
| `ui/ui_fit.gd` | **宽屏右侧锚定**——`stretch/aspect="expand"` 下靠右固定定位的 UI 必须走这里 |
| `music/music_director.gd` / `sound/sfx_director.gd` | BGM / 音效调度（自动加载） |
| `assets/*.json` | 数据表：`cards/catalog.json`(42 卡)、`battle_data.json`、`combat_balance.json`、`character_balance.json`、`meme_items.json` |
| `models/*/catalog.json` | 3D 素材目录：`themed_props/decor_catalog.json`、`themed_walls/wall_catalog.json` |
| `tools/` | 生成 / 验证 / 截图脚本，索引见 `tools/README.md` |

**改数值改 `assets/*.json`，不要在代码里写死。** 自动加载项：`HarborPrefs`、`MusicDirector`、`SfxDirector`（见 `project.godot`）。

## 改动约定

- **存档名含历史版本号是兼容路径**：`harbor_settings_v18.cfg`、`whale_continuous_v19.json`、`whale_inventory_v5.json`、`whale_dialogue_v19.json`。不要为了名字整齐改名或清空。
- **人物是完整图片帧**，八方向、按真实位移切帧，不用骨骼 / 拼接腿 / 关节变形。边缘描边与遮罩预先烘进素材，**运行时不要再做去白或描边**。
- **不要破坏这四条战斗不变量**：命中时更新生命与格挡、同名敌人按独立 ID 匹配、跳过/取消要清掉延迟回调、道具保存失败回滚 + 奖励防重复。
- 旧家具位置有迁移处理，`legacy_layout_items` 不是垃圾数据。
- 改动前先看 `docs/素材清点_20261010.md`。**人物素材 `v20`–`v24` 五代并存且仍被引用**，不要按目录名清理。
- 视觉改动用 `tools/preview_*` / `review_*` 脚本出实机截图，不要手绘示意图顶替。

## 验证

```powershell
# 无头检查（大多数 test_*.gd / audit_*.gd 适用）
& "$env:USERPROFILE\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tools/test_battle.gd
```

改完对应模块后跑哪几个脚本，见 `tools/README.md`。**引擎层有自动化覆盖（500 局规则不变量 + 定向断言），世界/UI 层覆盖较薄**——动世界或 UI 逻辑时请补一条能复现的检查。

## 导出状态（发布前必读）

- **无 `export_presets.cfg`**，导出从未配置过。
- **运行时仍有 10 处 `Image.load_from_file`**（人物帧 `room_3d.gd:844` / 怪物立绘 `encounter_marker.gd:59`、`battle_screen.gd:1284` / 肖像 `dialogue_controller.gd:64`、`harbor_start.gd:67,76`、`pause_menu.gd:21`、`character_controller.gd:41` / 地板 `room.gd:367` / `room_3d.gd:986`）。导出后这些路径读不到原图。
- 音乐 `.import` **已补齐**（17 个 wav 全部有 `.import`），10-03 报告里「一个 `.import` 都没有」已过时。
- 结论：**当前只能在编辑器内运行**，不能把「本机可跑」当作「装到别的电脑可用」。

## 版本控制

**本工程自 2026-10-10 起是 git 仓库**，远程为私有仓库 `git@github.com:yzh2513098614-ui/dafeiyu-v22.git`（走 SSH，无需令牌/密码）。首次提交 `ca20909` 入库 9276 文件 / 0.69 GB。

- **入库范围（方案 C）**：`assets\` `models\` `world_pack26\` `interior_pack\` 与全部代码 / 数据 / 文档。
- **刻意排除**：`.godot\`（621 MB 缓存）、`tools\video_runtime\`（213 MB 工具链）、`.mcp\`、`预览\`（794 MB 过程截图）、`art_source\`（523 MB 原始源料）、`备份\`、`.battle_*` 快照、`*.log`。详见根目录 `.gitignore`。
- `*.import` 与 `*.uid` **在库内**，不要把它们加进 `.gitignore`——Godot 4 靠它们保存导入设置与稳定引用。

**做有风险的改动前，手工复制到 `备份\<日期>_<改动前>` 仍是既有习惯，保留它。** 但备份目录不入库，所以**改完请自行 `git commit`**——git 不会自动提交，agent 会话结束也不会。

提交前确认没有别的会话正在写同一批文件（本机常同时跑 Codex / DSH 会话）。

```powershell
git add -A
git commit -m "说明这次改了什么"
git push
```
