"""Register the rendered neighborhood modules in the existing asset library."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MODULES=json.loads((ROOT/'assets/district/modules.json').read_text(encoding='utf-8'))
catalog_path=ROOT/'assets/catalog.json'
catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
catalog=[entry for entry in catalog if not entry['id'].startswith('district_')]
for folder in ('scenes/modules_3d', 'scenes/modules'):
    (ROOT/folder).mkdir(parents=True, exist_ok=True)
for kind,info in MODULES.items():
    name=info['name']
    size=info['size']
    identifier='district_'+kind
    texture=f'res://assets/district/{kind}.png'
    catalog.append(dict(id=identifier,name=name,category='street',source='district/street_asset.gd',source_bounds=[0,0,*size],size=size,footprint=info['footprint'],layer='object',solid=kind!='awning',texture=texture,preview_texture=texture))
    (ROOT/'scenes/modules_3d'/f'{identifier}.tscn').write_text(f'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://district/street_asset.gd" id="1"]\n[node name="{identifier}" type="Node3D"]\nscript = ExtResource("1")\nasset_kind = "{kind}"\n',encoding='utf-8')
    (ROOT/'scenes/modules'/f'{identifier}.tscn').write_text(f'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://module.gd" id="1"]\n[node name="{identifier}" type="Node2D"]\nscript = ExtResource("1")\nmodule_id = "{identifier}"\n',encoding='utf-8')
catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Registered {len(MODULES)} reusable modules; total {len(catalog)}')
