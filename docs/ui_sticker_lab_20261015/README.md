# 大肥鱼 · 网页 UI 示例第一版

直接打开 `dist/index.html`，或双击工程根目录的 `网页UI示例.cmd`。HTML 内嵌字体、图片、图标、样式与脚本，可以离线打开，也可以把这一个文件复制出去预览。

本轮包含三个页面：

- 共用组件：六种按钮状态、贴纸卡片、分类按钮、动效开关、四项数值。右侧可以切换普通 / 满值 / 低值 / 归零；「体力 −12」展示 0.6s 拖尾，「饱食 +20」展示 0.4s 恢复提示。
- 背包与宝箱：12 种项目物品的图标、说明与规则，支持分类、分页、查看详情、使用补给、装备、阅读、收取 / 放入、全部收取和放下确认。可以切换空背包、满背包、空宝箱；满背包可叠加已有物品，新物品需要空格。
- 对话：现有角色立绘与港口背景，支持继续、快进到回复选项、自动播放、三种回复与对话回看。`Space` / `Enter` 推进正文，`Esc` 关闭弹窗。

示例画布为 1448×1086，网页按窗口宽度等比缩放。左侧切页，右侧切状态与晴日 / 夜色背景。所有操作使用页面内模拟数据；刷新或点击「复原示例」恢复初始状态。

设计参考：`C:/Users/Administrator/.codex/skills/candy-sticker-vitals/references/mockup-v3.html`。共用厚白边、蓝色硬底影、浅色承面、内 accent 线；红色警报只给生命，其他低值使用暖黄 / 棕色。

素材原样复用项目资源，索引见 `asset-manifest.json`。没有修改 Godot 场景、游戏脚本、平衡数据或存档。对话正文是此次编写的预览文案。

可编辑源文件为 `index.template.html`、`ui.css`、`ui.js`。重新打包：

```powershell
& 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'D:\迅雷下载\大肥鱼_数值战斗怪物_v22\docs\ui_sticker_lab_20261015\build_preview.py'
```

检查结果：资源内嵌、模板引用、重复 DOM ID 与 JavaScript 语法检查通过；16 项状态逻辑和 DOM 模拟检查通过，覆盖补给与数量、满值保留、双向转移、满背包无损拒绝 / 叠加、装备、放下、三页初始化、宝箱 / 空背包、回复与回看。记录在 `预览/ui_sticker_lab_20261015/check-result.json`。浏览器控制接口当前没有可用浏览器，本轮未做浏览器画面或真实点击验收。
