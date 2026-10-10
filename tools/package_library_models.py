"""Deliver all 24 authored GLBs with a standalone Godot orbit viewer and comparison."""
from pathlib import Path
import json,zipfile,hashlib,html

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'models/library_props'
PREVIEW=ROOT/'预览/资料库24件3D'
REF=ROOT/'assets/library_model_references'
ORDER=['safe_floor','safe_tall','safe_compact','token_atm','bench','street_lamp','supply_crate','water_barrel','whale_fountain','whale_statue','recycling_bin','whale_sign','tree_oak','tree_pine','tree_birch','tree_cherry','tree_palm','tree_autumn','tree_snow_pine','tree_dead','bush_berry','shrub','stump','fallen_log']
catalog=json.loads((OUT/'library_catalog.json').read_text(encoding='utf-8'))
catalog=sorted(catalog,key=lambda e:ORDER.index(e['id'].removeprefix('library_')))
archive=Path(r'C:\Users\Administrator\Downloads\Token大肥鱼_全部生成资源_卡牌UI人物场景_总包.zip')
manifest=[]
with zipfile.ZipFile(archive) as z:
    for path in sorted(REF.glob('*.png')):
        matching=[n for n in z.namelist() if n.endswith('/'+path.name)]
        found=next(n for n in matching if z.read(n)==path.read_bytes())
        manifest.append(dict(file=path.name,archive_entry=found,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
(REF/'source_manifest.json').write_text(json.dumps(dict(archive=str(archive),files=manifest),ensure_ascii=False,indent=2),encoding='utf-8')

cards=[]
for n,e in enumerate(catalog):
    title=html.escape(e['name'].replace('资料库 · ',''));id=e['id'];reference=Path(e['reference']).name
    cards.append(f'''<article><h3>{n+1:02d} · {title}</h3><div class="comparison">
    <figure><img loading="lazy" src="../../assets/library_model_references/{reference}" alt="{title}参考图"><figcaption>原始参考</figcaption></figure>
    <figure><img class="model" loading="lazy" src="{id}_front.png" data-front="{id}_front.png" data-rear="{id}_rear.png" alt="{title}三维模型"><figcaption>Godot 实际渲染</figcaption></figure></div>
    <div class="actions"><button onclick="flip(this)" aria-pressed="false">查看背面</button><a href="../../models/library_props/{id}.glb" download>GLB 模型</a></div></article>''')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>蓝鲸港 · 24 件三维模型</title><style>
*{box-sizing:border-box}body{margin:0;background:#132536;color:#e6ebe5;font-family:system-ui,"Microsoft YaHei",sans-serif}main{max-width:1460px;margin:auto;padding:36px 28px}h1{font-size:32px;margin:0 0 16px}p{color:#bdd1d5;line-height:1.8}nav{display:flex;gap:14px;flex-wrap:wrap;margin:24px 0}a,button{color:#ead3a0;border:1px solid #476778;background:#213b4e;border-radius:8px;padding:10px 16px;font:inherit;text-decoration:none;cursor:pointer}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(350px,1fr));gap:20px}article{background:#1c3445;border:1px solid #3c5667;border-radius:14px;overflow:hidden}h3{font-size:18px;margin:0;padding:18px 20px}.comparison{display:flex;gap:2px}figure{margin:0;width:50%;background:#294655}img{width:100%;height:235px;object-fit:contain;display:block}figcaption{text-align:center;padding:12px;color:#c0d4d8;font-size:13px}.actions{display:flex;justify-content:space-between;padding:14px}.scene{width:100%;height:auto;border-radius:14px;background:#192a38;margin:14px 0}h2{margin-top:42px}.note{padding:18px;border-left:3px solid #bca46d;background:#1c3445}button:hover,a:hover{background:#365267}</style>
<main><h1>蓝鲸港 · 24 件三维模型</h1><p>按照 town.png 与 trees.png 中的 24 个物件建模，保留蓝金奶白配色、鲸鱼主题和各类植物轮廓。<br>下方为原图与真实三维模型的对照；点击“查看背面”检查补全的另一面。</p>
<nav><a href="#town">12 件城镇物品</a><a href="#nature">12 件植物</a><a href="../../assets/library_model_references/town.png">城镇原图</a><a href="../../assets/library_model_references/trees.png">植物原图</a></nav>
<p class="note">想自由旋转：双击工程目录中的“查看资料库24件3D模型.cmd”。鼠标拖动旋转，滚轮缩放，方向键切换。这里的静态图均由 Godot 渲染；模型具备侧面、背面、材质和碰撞。参考图只有一个视角，其余结构为建模补全。</p>
<h2 id="town">城镇物品</h2><div class="grid">TOWN_CARDS</div><h2 id="nature">树木与植物</h2><div class="grid">NATURE_CARDS</div>
<h2>已接入 v22 场景</h2><p>12 类城镇物品及 6 类植物已布置到花房、集市、书庭和公共花园；其余植物保留在模型库，供不同季节的地图使用。</p>
<img class="scene" src="../餐厅学校医院_3D_v22/civic_garden_庭院重做.png" alt="公共花园中的鲸鱼喷泉和新树木"><img class="scene" src="../餐厅学校医院_3D_v22/market_庭院重做.png" alt="集市中的城镇模型">
<p>本批为静态装饰模型，保险柜开门、取款操作与动态水流尚未制作。已检查 24 个 GLB 的几何、法线、落地位置和碰撞；四张地图的通路及旧存档迁移检查通过。</p>
</main><script>function flip(button){const image=button.closest('article').querySelector('.model'),rear=button.getAttribute('aria-pressed')!=='true';image.src=rear?image.dataset.rear:image.dataset.front;button.setAttribute('aria-pressed',rear);button.textContent=rear?'回到正面':'查看背面'}</script></html>'''
page=page.replace('TOWN_CARDS',''.join(cards[:12])).replace('NATURE_CARDS',''.join(cards[12:]))
(PREVIEW/'index.html').write_text(page,encoding='utf-8')
launcher='''@echo off
set "MODEL_GODOT=C:\\Users\\Administrator\\Godot\\Godot_v4.7.2-stable_win64.exe"
if not exist "%MODEL_GODOT%" (
 echo Open project.godot with Godot 4, then run district/library_models_viewer.tscn.
 pause
 exit /b 1
)
start "" "%MODEL_GODOT%" --path "%~dp0" res://district/library_models_viewer.tscn
'''
(ROOT/'查看资料库24件3D模型.cmd').write_text(launcher,encoding='ascii')
readme='''# town.png 与 trees.png：24 件三维模型

城镇 12 件：转轮保险柜、电子保险柜、低身保险柜、取款机、长椅、路灯、补给箱、水桶、鲸鱼喷泉、雕塑、路标、回收桶。
自然 12 件：橡树、松树、白桦、樱花、棕榈、秋树、雪松、枯树、果丛、绿篱、树桩、倒木。

## 查看
打开 `预览/资料库24件3D/index.html` 查看原图与模型正反面。
用 Godot 4 打开本包的 `project.godot` 并运行，可自由旋转所有模型。
本机可以双击 `查看资料库24件3D模型.cmd` 直接启动。拖动旋转，滚轮缩放，方向键切换，F 复位。

## 使用
每件包含标准 GLB 和 Godot TSCN。Y 为上轴，物件放在地面 y=0 附近，正面为 +Z。
GLB 内置色彩材质，不依赖原图或外部贴图。TSCN 附带碰撞；树干阻挡，树冠可穿行。
使用 TSCN 时将 `models/library_props` 原样复制到目标工程，保留资源相对路径。
本包的 `district/library_models.gd` 用 v22 的材质处理方式加载模型；也可直接在 Godot/Blender 导入 GLB。

## 已完成与范围
已在 v22 四个庭院中布置 18 类模型（12 类城镇物品、6 类植物，共 25 个实例），检查场景中的道路连通、出生点、出口和落地范围。
其余季节性植物已完成，可在查看器中查看，尚未散布到游戏地图。
素材均为按单视角图片手工定义几何的风格化模型，侧面与背面由建模补全，不能视为原图作者的真实背面设计。
当前是静态装饰；没有保险柜开门、取款逻辑或动态喷泉水流。

## 源文件
`tools/build_library_models.py` 与 `build_decor_revamp.py` 为可重复生成的建模源文件，依赖 Python、NumPy、trimesh。
`assets/library_model_references` 保留未经重绘压缩的 PNG 和原始资源包路径、SHA256。
24 个 GLB、101 个材质表面、221496 个三角形（合计，不是单个模型）。同材质几何已合并。
'''
(ROOT/'00_资料库24件3D模型_v22.md').write_text(readme,encoding='utf-8')
files=[]
files.extend(p for p in OUT.iterdir() if p.suffix in ['.glb','.tscn','.json'])
references={'town.png','trees.png','source_manifest.json'}|{Path(e['reference']).name for e in catalog}
files.extend(REF/name for name in sorted(references))
files.extend(PREVIEW.glob('*.png'));files.append(PREVIEW/'index.html')
for name in ['civic_garden','market']:files.append(ROOT/f'预览/餐厅学校医院_3D_v22/{name}_庭院重做.png')
for name in ['district/library_models.gd','district/library_models_viewer.gd','district/library_models_viewer.tscn','district/decor_library.gd','district/space_shape.gd','modern_materials.gd','tools/build_library_models.py','tools/build_decor_revamp.py','tools/validate_library_models.py','查看资料库24件3D模型.cmd','00_资料库24件3D模型_v22.md']:
    files.append(ROOT/name)
project='''config_version=5
[application]
config/name="蓝鲸港 · 24 件三维模型"
run/main_scene="res://district/library_models_viewer.tscn"
config/features=PackedStringArray("4.6", "GL Compatibility")
[display]
window/size/viewport_width=1280
window/size/viewport_height=960
window/size/window_width_override=1000
window/size/window_height_override=750
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
'''
dest=ROOT/'大肥鱼_城镇物品与植物_24件3D模型.zip'
with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in sorted(set(files)):
        assert p.is_file(),p;z.write(p,p.relative_to(ROOT).as_posix())
    z.writestr('project.godot',project)
with zipfile.ZipFile(dest) as z:
    assert z.testzip() is None
    assert len([n for n in z.namelist() if n.endswith('.glb')])==24
    assert len([n for n in z.namelist() if n.startswith('models/') and n.endswith('.tscn')])==24
print('PACK',dest,'bytes',dest.stat().st_size,'files',len(set(files))+1)
