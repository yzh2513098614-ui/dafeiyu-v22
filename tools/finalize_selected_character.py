from pathlib import Path
import shutil
ROOT = Path(__file__).resolve().parents[1]
shutil.copy2(ROOT / "assets/character/selected_walk_sheet.png", ROOT / "art_source/用户选定_完整人物.png")
(ROOT / "00_人物步态完成使用说明.md").write_text('''# 大肥鱼 · 指定完整人物图集 v14

当前人物使用用户最后选定的完整 PNG：`assets/character/selected_walk_sheet.png`。原图按字节原样复制，没有重新生成、拆腿、拉伸腿或改画风。四行分别为下、左、上、右，每方向六帧；待机和互动保留同一张图中的静止姿态，不切回旧画风。

主入口仍是 `district/continuous_world.tscn`。使用 Godot 4.6.2 导入 `project.godot`，或双击「启动人物步态.bat」。初始为整图视角；按 Z 跟随人物，滚轮可放大。WASD / 方向键行走，E 互动，1 / 2 / 3 进入公寓二层、街区、社区馆，M 打开导览，F5 保存、F9 恢复。

行走相位按实际移动距离推进，堵墙停步，滑动朝向跟随真实位移。原图的行间留白不完全等宽，采用独立裁切带保留呆毛、头发和鞋子，并根据每帧脚底定位。人物使用场景深度测试和脚下接触影，家具可正常挡住人物。

已完成 Godot 4.6.2 导入和人物链路检查：四方向各六帧已实际加载，连续穿过门洞、停步及墙面碰撞通过。实际画面位于「预览/人物步态_v14」：四方向行走 GIF、四方向截图、脚点定位和家具遮挡。检查日志为 `tests/v14_selected_motion.log`；这里只验证本次人物接入。

原连续大地图、12 栋大小错位建筑、3 栋重点建筑、8 套各含六间房的不同楼层布局沿用 v13。

早期分腿拼接稿已被用户否决，不作为运行时人物。`body_parts.png`、`leg_parts.png`、`*_atlas_v14.png`、`character_paper_rig.gd` 留作失败过程记录；当前只加载 `selected_walk_sheet.png` 和 `manifest.json`。旧拼腿烘焙器已加保护，禁止覆盖当前完整图集。
''', encoding="utf-8")
print("SELECTED CHARACTER DELIVERY NOTES UPDATED")
