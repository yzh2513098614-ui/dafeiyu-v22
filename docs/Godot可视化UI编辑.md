# 在 Godot 里编辑大肥鱼 UI

双击工程根目录的 `编辑游戏UI.cmd`。Godot 右侧会出现 **UI 设计** 面板，双击一个界面，进入 **2D** 工作区。若编辑器早已打开，重新打开工程以加载插件；也可以在 项目 → 项目设置 → 插件 中启用“大肥鱼 UI 设计”。

1. 在场景树选中现有控件，在 2D 画布拖动、缩放，或在检查器的 Layout 中修改位置、尺寸、锚点。
2. 按钮的 Icon、TextureRect 的 Texture 可以直接拖入工程里的 PNG/SVG 替换。字体、字号、文字颜色、按钮圆角、描边和阴影在 Theme Overrides 中修改。按钮的 normal / hover / pressed / disabled / focus 分别控制各状态。
3. `Ctrl+S` 保存；停止旧的运行窗口，再按 `F5` 启动完整游戏。`F6` 只预览设计场景，不执行按钮原有业务。

现有界面已拆为 **44 个原生 Control 场景，2751 个可编辑控件**，覆盖标题与出发、音乐和设置、世界工具栏与导览、宝箱/背包/便签、暂停、人物装备、对话/回复/回看、研究远征、新区探索和卡牌战斗。列表支持搜索。

## 常用入口

| 想修改的内容 | 打开的文件 |
|---|---|
| 标题菜单 | `ui/design/pages/title_title.tscn` |
| 背包 | `ui/design/pages/inventory_bag.tscn` |
| 宝箱 | `ui/design/pages/inventory_chest.tscn` |
| 战斗 | `ui/design/pages/battle.tscn` |
| 战斗补给 / 技能 / 结果 | `battle_item.tscn` / `battle_skill.tscn` / `battle_result.tscn` |
| 全部界面目录 | `ui/design/catalog.json` |
| 全局皮肤与功能图标 | `ui/design/game_ui_theme.tres` |

## 修改整套颜色与图标

点击 UI 设计面板的 **全局按钮皮肤与图标**，打开原生 Theme 编辑器。

- `GameUI → Styles`：修改共享 StyleBoxFlat 的背景色、边框、圆角、阴影。`button` 是普通按钮，`primary` 是主按钮，`hover` / `pressed` 是交互状态，`bag` / `chest` 是背包和宝箱面板。保留这些名称及 StyleBoxFlat 类型。
- `GameIcons → Icons`：替换 map、backpack、gift、settings 等功能图标槽位。请把新图片先放进工程 `assets/ui/`，再拖进槽位；完整游戏重新启动后会读取新图片。
- Label / Button 等类型中的字体与颜色是默认值；具体控件已有的 Theme Overrides 优先。要改某一个控件，直接改它的覆盖项。
- PNG 的图案仍是位图；Godot 可以替换图片、修改位置、尺寸和颜色调制，绘制图片内部内容仍需要绘图软件。

## 编辑规则

保存的是视觉设计，完整游戏仍使用原来的交互节点、信号和存档流程。运行时只应用与原始设计不同的视觉属性，因此血量、数量、禁用和选中状态继续由游戏数据更新。

- 可重命名节点；保留 Metadata 中的 `design_id` 和 `design_native_class`。不要改变现有节点的父子层级、删除或复制这些节点。
- 本次入口支持修改现有控件。新增、删除控件或新增按钮功能，需要修改对应的游戏控制器；仅往设计场景中添加节点不会进入完整游戏。
- Container 内的孩子由容器排版。修改 Custom Minimum Size、Size Flags、容器的 separation / columns，而不是强行拖动其位置。
- 默认保护数值和动态文本。固定按钮标题可编辑；确需编辑其他文本时，打开该控件 Metadata 的 `design_edit_text`。不要把生命、库存、角色名字等动态字段改成固定文本。
- 某些子面板按游戏状态隐藏。编辑时可临时勾选 Visible 查看，运行时显隐继续由游戏控制。设计场景中的示例物品与角色只用于看排版。
- 动态物品列表按现有模板位置匹配，示例槽位不能代表无限新增的物品行；要统一这些行的样式，优先修改共享 Theme。
- `ui/design/baselines/` 是比较基准，平时只编辑 `pages/`，不要一起修改基准。

## 实现与验证

`UiDesign` 自动加载器读取保存后的设计差异，并在游戏控制器更新布局后应用；未修改的页面直接跳过。新增的插件和桥接器不替换战斗、奖励或存档逻辑。导出工具不会覆盖已有设计页面，维护者重新导出前仍需备份基准和页面。

测试入口：

```powershell
& 'C:\Users\Administrator\Godot\Godot_v4.7.2-stable_win64_console.exe' --path '.' --audio-driver Dummy --script res://tools/test_editable_ui.gd -- --test-session-ui --test-dialogue --test-expedition
```

测试使用隔离存档，检查所有页面加载、原设计无差异、修改位置和图标能进入真实菜单、布局重绘后修改仍保留，以及真实鼠标点击能打开原有出发界面。测试中的临时页面修改会还原；请先保存自己的编辑。

官方参考：[Godot 编辑器插件](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html)、[编辑器中执行工具脚本](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html)。
