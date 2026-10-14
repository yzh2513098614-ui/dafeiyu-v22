# tools/ 脚本索引

武鸣校区接入实机检查：`preview_wuming_campus.gd`。验证校园入口、公共渲染光影、行走与地标、存档恢复及往返；命令和截图位置见 [武鸣校区接入说明](../00_武鸣校区接入_v22.md)。

工程内约 130 个脚本，混了四种用途：**无头验证**、**实机截图**、**视觉评审**、**素材生成管线**。
本文件让「我要验 X」直接变成「跑哪条命令」，不必再翻目录猜脚本名。

引擎：`%USERPROFILE%\Godot\Godot_v4.7.2-stable_win64.exe`（缺失回落 `\Godot\4.6.2\`）。

## 一、命令约定

```powershell
# 1) 无头逻辑验证 —— 不需要渲染，CI 友好
& "$env:USERPROFILE\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tools/test_battle_rules_cli.gd -- --test-session-ui --test-dialogue

# 2) 需要渲染的截图 / 预览 —— 不能加 --headless
& "$env:USERPROFILE\Godot\Godot_v4.7.2-stable_win64.exe" --path . --script res://tools/capture_menu.gd

# 3) 带旗标（注意 `--` 之后才是脚本自己的参数）
... --script res://tools/test_audio_ui.gd -- --test-audio-ui
```

脚本自身认得的旗标：`--after` `--before` `--battle-art-review` `--capture-dialogue` `--capture-ui`
`--details` `--frames` `--map-only` `--only-floors` `--overview` `--require-eight` `--test-audio-ui` `--test-merge`

⚠️ **截图 / 评审类脚本会往 `预览\` 写文件**（脚本内 `const OUT = "res://预览/..."`）。`预览\` 已经是全工程最大目录（794 MB / 2068 文件），批量重跑前先确认是否要保留旧截图。

多数脚本声明使用隔离存档（`user://` 测试路径、`--capture-ui` 等），但**它们说法不一**；碰存档相关脚本前先读一遍头部注释，别假设一定安全。

## 二、回归验证（改完对应模块就跑）

| 验什么 | 脚本 | 备注 |
|---|---|---|
| **战斗引擎规则不变量** | `test_battle_rules_cli.gd` → `test_battle.gd` | CLI 入口调用既有 RefCounted 测试；500 局 + 6 项定向断言（AP 连携 / 护盾减半 / 束缚跳回合 / 无效指令不消耗回合 / 体力回复封顶 / 存档 id 白名单） |
| 糖果色战斗实机 UI | `preview_candy_battle.gd` | 需 `--test-session-ui --test-dialogue`；真实鼠标输入、手牌、补给、胜利、三目标、4:3 与 16:9，输出 `预览/糖果UI全局改造_20261011/` |
| 当前战斗布局与大立绘 | `preview_gpt6_large.gd` | 需 `--test-session-ui --test-dialogue`；三种窗口、普通遭遇、三目标、至少双倍 gpt6、手牌悬停/出牌、补给/返回、结束回合、目标切换与 UI 随机数检查，输出 `预览/角色与能量底框_20261013/` |
| 已接入界面统一换肤 | `preview_candy_global.gd` | 需 `--test-session-ui --test-dialogue`；标题、出发、HUD、背包、设置、对话和暂停实机截图及输入回归 |
| **战斗数值体检** | `measure_battle_balance.gd` | 胜率、平均回合、等级探针；配合 `现状不足分析_v22.md` 的语气 |
| 卡牌排版与字体字形覆盖 | `test_cute_card_layout.gd` | 42 张卡的名称与说明字形 |
| 战斗表现（命中同步 / 连续攻击 / 同名目标 / 格挡 / 五位数布局） | `test_battle_presentation.gd` | 退出时可能有既有 ObjectDB 清理警告 |
| 42 卡循环 | `test_card_battle.gd` | 不读写玩家存档 |
| 试炼遭遇开启 | `test_card_integration.gd` | 只开启、不结算 |
| 攻击反馈 | `test_attack_feedback.gd` | |
| 战斗 UI 校验 | `test_battle_ui.gd` | 输出到 `user://battle_ui_validation_20261004/` |
| 属性 / 成长 / **存档校验边界** | `test_life_state.gd` | 逐字段类型范围、装备槽合法性、`combat.defeated` 白名单 |
| 人物数值与道具 UI | `test_life_ui.gd` | 输出 `预览/人物数值与道具_v19/` |
| 宝箱双栏与随身背包 | `preview_chest_bag.gd` | 需 `--test-session-ui --test-dialogue`；真实输入、容量边界、保存回滚与五种窗口比例，输出 `预览/宝箱背包_20261011/` |
| 暂停与旅程 UI | `test_session_ui.gd` | 输出 `预览/暂停与旅程_v19/` |
| 对话 | `test_dialogue.gd` | |
| 八方向人物（运行时） | `test_character_8dir.gd` | 不加载 UI / 背包 / 对话 / 玩家存档 |
| 碰撞安全 | `test_collision_safety.gd` | 需旗标：`-- --test-expedition --test-dialogue` |
| 练习场循环 | `test_practice_loop.gd` | 掉落只领一次、25% 基础阅历 |
| 音乐设置界面 | `test_audio_ui.gd` | 需旗标：`-- --test-audio-ui` |
| 远征规则（三指令同步结算线） | `test_expedition_rules.gd` | `combat_simulator` / `run_state` / `tactical_grid` / `encounter_director` |
| 远征场景 | `test_expedition_scene.gd` | |
| **跨数据表审计** | `audit_data_tables.gd` | `assets/*.json` 之间的引用一致性 |
| 大地图容器摆放审计 | `audit_map_containers.gd` | |
| 大地图容器双向存取 | `test_map_storage.gd` | 需 `--test-session-ui --test-dialogue`；38 个容器真实 E/Esc、鼠标存取、容量、装备、失败回滚、切图与旧存档；加 `--verify-containers` 在新进程复验读档。输出 `预览/大地图容器_20261012/` |
| 地图交互小按钮 | `preview_interaction_buttons.gd` | 需 `--test-session-ui --test-dialogue --test-expedition`；8 张代表地图的单按钮提示、真实鼠标/E 操作、入口门右键开合、3 种窗口尺寸；不加 `--headless` 生成实机截图。输出 `预览/地图交互小按钮_20261012/`。`--refresh-compact-design` 仅用于重建尚未自定义的对应 UI 页面 |
| 26 地图与模型依赖可加载性 | `load_pack26.gd` | 只验可加载，不验画面 |

## 三、人物素材与渲染检查（`check_*`）

每条对应 `预览\` 下的一个对照目录，运行后会生成「修改前 / 修改后」截图。

| 脚本 | 检查点 | 输出目录 |
|---|---|---|
| `check_baked_mattes.gd` | 烘焙遮罩、透明孔洞 | `预览/人物固定遮罩_v24/` |
| `check_edge_ink.gd` | 边缘描边纹理 | `预览/人物边缘纹理_20261004/` |
| `check_safe_matte.gd` | 斜左下无损去白 | `预览/斜左下无损去白_20261004/` |
| `check_diagonal_palette.gd` | 斜后方向校色 | `预览/斜后方向校色_20261010/` |
| `check_front_proportions.gd` | 正面比例校正 | `预览/正面比例校正_20261010/` |
| `preview_front_upper_body.gd` | 正面头部下拉与身体压短，25 项运行检查 | `预览/正面头部下拉_20261012/`；`--test-merge --capture-ui --capture-dialogue --test-life-ui` |
| `character_proportion_editor.tscn` | Godot 编辑器内实时调人物比例，保存到游戏 | 操作见 `00_人物比例编辑器_v22.md` |
| `check_proportion_editor.gd` | 验证实时调参、逐帧预览、保存与原生碰撞更新 | `预览/人物编辑器调参_20261012/` |
| `check_proportion_live_reload.gd` | 调参自动同步实际游戏/F6，含眼睛上下缘下移和面部局部 GPU 变化检查 | `预览/游戏比例实时同步_20261012/`；`--test-merge --capture-ui --capture-dialogue --test-life-ui` |
| `check_up_right_mirror.gd` | 右上镜像替换 | `预览/右上镜像替换_20261010/` |
| `check_up_left_video.gd` | 左上视频帧接入 | 隔离设置与存档 |
| `check_character_scene_light.gd` | 环境受光（GPU） | `预览/人物环境受光_v22_20261004/` |
| `check_character_motion.gd` | 真人物 + 真走廊 + 真墙的小集成 | 需先导入新人物资源 |
| `check_redrawn_character.gd` | 重绘人物集成 | **只验集成，不认证绘制质量与脚点** |
| `check_latest_merge.gd` | 背包 / 对话 / 世界存档隔离集成 | |
| `check_baked_mattes.gd` | 遮罩孔洞 | |

## 四、场景与 UI 截图（`capture_*`）

| 脚本 | 内容 |
|---|---|
| `capture_packed_floors.gd` / `capture_themed_places.gd` | 19 层 / 114 房间的碰撞与可达性采样 |
| `capture_courtyard_scenes.gd` | 四处庭院 |
| `capture_menu.gd` | 菜单与其导航 |
| `capture_game_ui.gd` | 界面完善（输出 `预览/界面完善_v19/`） |
| `capture_character.gd` / `capture_video_character.gd` / `capture_redrawn_character.gd` | 人物走动（走生产控制器，不手动选帧） |
| `capture_card_battle.gd` | 卡牌手牌 |
| `capture_dialogue.gd` | 对话（输出 `预览/像素立绘对话_v19/`） |
| `capture_district.gd` | 街区（输出 `预览/街区/`） |
| `capture_library_models.gd` / `capture_library_individuals.gd` | 24 件 3D 素材库 / 城镇与植物 |
| `capture_themed_models.gd` / `capture_themed_walls.gd` / `capture_decor_revamp.gd` | 主题家具 / 墙体 / 50 件装饰 |
| `capture_wall_depth.gd` / `capture_actor_preview.gd` / `capture_place_thumbs.gd` | 墙体厚度 / 房间实景 / 地点导览缩略图 |

## 五、视觉评审（`review_*` / `preview_*`）

**`review_*`（12 个）** 是战斗 UI 逐轮评审留存：`review_attack_feedback` `review_battle_art`
`review_battle_feedback_02` `review_battle_readable_spacing` `review_block_badges`
`review_block_position` `review_card_gallery` `review_clear_battle_icons` `review_guard_design`
`review_misans_battle_font` `review_shield_counter` `review_soft_cards`。

**`preview_*`（15 个）** 是针对具体改动轮的实机对照：`preview_lighting`（光照）
`preview_render_refinement` / `preview_render_depth` / `preview_soft_contours`（渲染层次/背光侧边缘）
`preview_map_surfaces` / `preview_wall_surfaces`（地图与内外墙材质）
`preview_floor_motion`（地砖抗闪烁）`preview_restaurant_composition` / `_expansion` / `_finish`（海蓝餐厅）
`preview_pack26` / `preview_expedition_upgrade` / `preview_character_surface` / `preview_edge_rendering` / `preview_lighting`。

它们**用隔离存档 + 固定时钟 + 固定取景**，目的是和上一轮基线严格可比。跑之前先确认对应改动说明（`00_*_v22.md`）还在。

## 六、素材生成管线（一般不必手动跑）

| 家族 | 脚本 |
|---|---|
| 3D 模型 | `build_3d_layouts.py` `build_floor_library.gd` `build_library_models.py` `build_themed_models.py` `build_themed_walls.py` `validate_decor_models.py` `validate_library_models.py` `package_library_models.py` |
| 房间 / 街区 | `build_district_assets.gd` `build_materials.gd` `build_modules.gd` `build_layouts.py` `register_district_assets.py` `package_continuous.py` `package_district.py` |
| 人物 | `bake_character.gd` `bake_character_mattes.gd` `bake_character_v15.gd` `pack_full_character.gd` `pack_jimeng_generated.gd` `pack_original_portraits.gd` `pack_dialogue_portraits.gd` `package_character.py` `package_redrawn_character.py` `finalize_jimeng_character.py` `finalize_selected_character.py` `select_user_character.py` `install_complete_png.py` `configure_complete_png.py` `defringe_character.gd` `repair_white_fringe.py` `repair_inner_matte.py` `matte_jimeng_video.py` `mirror_up_left_video.py` `import_up_left_video.py` `verify_jimeng_pixels.py` `compose_character_surface.py` `prepare_character_texture_imports.py` `write_walk_pose_guides.py` `render_walk_pose_guides.gd` `render_full_pose_guide.gd` `inspect_refined_frames.gd` |
| UI / 卡牌 | `build_whale_ui_assets.py` `export_whale_theme.gd` `export_modern_materials.gd` `import_card_pack.py` `pixelize_cards.gd` `probe_card_text.gd` `catalog_sheet.gd` `render_catalog.gd` `render_modern_catalog.gd` `prepare_catalog.py` |
| 渲染 / 合成 | `compose_edge_rendering.py` `compose_map_surfaces.py` `compose_render_refinement.py` `compose_soft_contours.py` `compose_stronger_contours.py` `make_floor_comparison.py` `make_lighting_comparison.py` `profile_render_refinement.gd` |
| 26 地图包 | `load_pack26.gd` `update_packed_preview.py` `update_scene_runtime.py` |
| 音效音乐合成 | `music_synth.gd`、`music_synth_gal.gd`、`sfx_synth.gd`；`ambience_synth.gd`（**当前未启用**） |
| 钢琴 BGM 批量渲染 | `gal_piano/render_batch.gd`（曲目定义在同目录 `batch_scores.json`，输出 `assets/music/gal_piano_*.wav`）、`gal_piano/render_goodnight.gd`（单曲《晚安，鲸落港》，谱面 `gal_piano/score_goodnight.gd`，输出 `assets/music/gal_goodnight.wav`，约 50 秒；接入自检 `gal_piano/check_goodnight.gd`）、`bgm_glasshouse/main.gd`（《玻璃温室》六首，输出 `assets/music/glasshouse/`）、`bgm_whalefm/main.gd`（《鲸落电台》六首 Lo-fi，输出 `assets/music/whalefm/`）。那三套批量产线都支持 `--tracks 3,5 --quality draft` 只渲指定曲目，`--list` 只看曲目表；`render_goodnight.gd` 是单曲，没有这两个旗标。**都会覆盖同名成品，重跑前先备份；部分渲染还会重写该目录的 manifest，要完整清单就跑全量**。
| 杂项 | `update_v12_source.py` `video_review_readonly.py` `collision_preview.gd` `debug_collision_clearance.gd` `_check_box_pos.gd` `_spec_check.gd` `finalize_restaurant_finish.gd` |
| 启动 | `launch_game.ps1`（由根目录 `开始试玩.cmd` 调用，日志写 `play_stdout.log` / `play_stderr.log`） |

眼睛高光恢复（2026-10-14）：`restore_original_eye_highlights.py` 默认只检查，带 `--apply` 从原始视频帧恢复高光、同步镜像并重新生成眨眼帧。`import_download_walk_videos.py` 已将蓝色虹膜与白色高光排除在发丝白底清理之外。

本轮备份：`备份/20261014_眼睛高光修复前/`；修复 30 张行走帧（含镜像），眼睛区域透明孔洞为 0；`test_character_blink.gd`：37 passed / 0 failed。

## 七、覆盖盲区（已知）

- **世界层与 UI 层几乎没有自动化**：引擎层（`test_battle.gd` 500 局 + 定向断言）覆盖扎实，但连续大地图、楼层生成、背包交互、开始界面流程主要靠 `capture_*` 截图**人工看**，没有断言。
- **没有安装包 / 导出验证**：无 `export_presets.cfg`，未验证过可分发导出（详见 `AGENTS.md` 的「导出状态」）。
- 动世界或 UI 逻辑时，请顺手补一条能复现的检查，别只截图。

## 八、海风场景实机出图（2026-10-11）

| 脚本 | 内容 | 对应说明 |
|---|---|---|
| `preview_story_quay.gd` | 原有码头样板与参考光照 | `00_港口探索参考风格_v22.md` |
| `preview_tidal_cafe.gd` | 咖啡馆、门及设施动画 | `00_潮汐信笺咖啡馆_v22.md` |
| `preview_harbor_terraces.gd` | 双层港区昼夜、两组楼梯连续上下行、工坊门按钮与铰链动画 | `00_海风码头双层港区_v22.md` |

出图脚本使用隔离的设置和世界存档。双层港区脚本的输出位置见脚本内 `output`；启动时传入 `--test-session-ui --test-dialogue` 以隔离背包与对话存档。这两个参数仅用于存档隔离。图集交付在 `预览/海风码头双层港区.html`。

### 港区交互细化出图

`preview_harbor_life.gd` 输出彩旗、路牌、停泊绞盘和灯塔信标的实机画面，含信标开关对照。隔离参数沿用 `--test-session-ui --test-dialogue`；说明见 `00_海风码头交互细化_v22.md`，最新图集为 `预览/海风码头_交互细化.html`。
