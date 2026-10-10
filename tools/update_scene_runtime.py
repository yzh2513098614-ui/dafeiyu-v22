from pathlib import Path
root = Path(__file__).resolve().parents[1]
def edit(name, old, new):
    p = root / name
    s = p.read_text(encoding='utf-8')
    assert old in s, (name, old)
    p.write_text(s.replace(old, new), encoding='utf-8')
edit('district/packed_floor.gd', 'const DOOR=2.4', 'const Partitions=preload("res://district/floor_partitions.gd")\nconst DOOR=2.4')
edit('district/packed_floor.gd', 'var polys: Array[PackedVector2Array]=polygons(programs,seed)', 'var family: int=Partitions.family(building,level)\n var polys: Array[PackedVector2Array]=polygons(programs,seed) if family==0 else Partitions.make(family,seed)')
edit('district/packed_floor.gd', 'g.shell.set_meta("floor_layout","interlocking_rooms")', 'g.shell.set_meta("floor_layout","interlocking_rooms")\n g.shell.set_meta("layout_revision","packed_rooms_v2")\n g.shell.set_meta("partition_family",Partitions.name_for(family))')
edit('district/packed_floor.gd', 'return {"bounds":Vector2(48,38)', 'var outline: Rect2=_rect(contours[0])\n return {"bounds":Vector2(maxf(absf(outline.position.x),absf(outline.end.x))*2+4,maxf(absf(outline.position.y),absf(outline.end.y))*2+4)')
edit('district/continuous_world.gd', '"packed_rooms_v1"', '"packed_rooms_v2"')
edit('tools/capture_packed_floors.gd', '"packed_rooms_v1"', '"packed_rooms_v2"')
edit('tools/capture_packed_floors.gd', 'var step:=.45;var origin:=Vector2(-23,-18)', 'var step:=.45\n var bounds:=Rect2(game.room_zones[0].polygon[0],Vector2.ZERO)\n for zone in game.room_zones:\n  for point in zone.polygon:bounds=bounds.expand(point)\n bounds=bounds.grow(.5)\n var origin: Vector2=bounds.position')
edit('tools/capture_packed_floors.gd', 'for z in 82:\n  for x in 104:', 'for z in int(ceil(bounds.size.y/step))+1:\n  for x in int(ceil(bounds.size.x/step))+1:')
edit('district/continuous_world.gd', 'LifePlaces.build(self,target) if target in ["garden","market","gallery"]', 'LifePlaces.build(self,target) if data.type=="courtyard" or target=="gallery"')
edit('district/continuous_world.gd', '_exit(Vector3(-17,0,11),"city","回到鲸落街区","entrance")', '_exit(built.get("exit",Vector3(-17,0,11)),"city","回到鲸落街区","entrance")')
edit('district/continuous_world.gd', 'space_bounds=built.get("bounds",Vector2(44,30));room_zones=built.get("zones",[])', 'space_bounds=built.get("bounds",Vector2(44,30));room_zones=built.get("zones",[])\n shell.set_meta("supply_anchor",built.get("supply",Vector3(2,0,1.25)))')
edit('district/continuous_world.gd', 'crate.position={"city":Vector3(2.4,0,7),"garden":Vector3(2.5,0,5),"market":Vector3(-12.7,0,6)}.get(place,Vector3(2.0,0,1.25))', 'crate.position=Vector3(2.4,0,7) if place=="city" else (shell.get_meta("supply_anchor",Vector3(2,0,1.25)) if locations[place].type=="courtyard" else Vector3(2,0,1.25))')
edit('district/continuous_world.gd', 'locations["gallery"]=', 'locations["reading_court"]={"name":"漂流书庭 · 海边阅读院","group":"outside","type":"courtyard","subtitle":"弧形书亭 / 阅读平台 / 手作树庭","links":["city"]}\n locations["civic_garden"]={"name":"蓝湾公共花园","group":"outside","type":"courtyard","subtitle":"花径 / 休息庭 / 社区活动平台","links":["city"]}\n locations.city.links.append("reading_court");locations.city.links.append("civic_garden")\n locations["gallery"]=')
edit('district/continuous_world.gd', '"玻璃温室 / 错位花圃 / 树下茶庭"', '"折角温室 / 弧形花岛 / 树下茶庭"')
edit('district/continuous_world.gd', '"小铺支街 / 海风摊位 / 港口休憩台"', '"交错店铺 / 双向街口 / 扇形海岸平台"')
print('Four floor families, new courtyard routes, compatible v2 furniture migration')
