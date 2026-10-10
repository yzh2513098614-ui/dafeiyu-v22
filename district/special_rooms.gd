extends RefCounted
## Each special floor has a unique room program, silhouette and equipment set.
static func room(kind: String,name: String,x: float,z: float,w: float,d: float,shift: float=0.0) -> Dictionary:
 return {"kind":kind,"name":name,"rect":Rect2(x,z,w,d),"shift":shift}

static func plan(building: String,level: int) -> Array:
 if building=="restaurant":
  return [room("restaurant_dining","海蓝主餐厅",-23,-17,20,12,.16),room("restaurant_patisserie","烘焙甜品展台",-1,-15,12,10,-.13),room("restaurant_bar","咖啡与饮品吧",13,-16,10,11,.12),room("restaurant_kitchen","明档备餐厨房",-23,5,17,11,-.15),room("restaurant_pantry","冷藏与餐具小间",-4,9,10,8,.12),room("restaurant_lounge","窗边安静卡座",8,5,15,11,-.16)]
 if building=="school":
  if level==1:
   return [room("school_lobby","海湾学校门厅",-23,-17,16,12,.15),room("school_classroom","海风大教室",-4,-16,13,11,-.16),room("school_staff","教师备课室",11,-16,12,10,.10),room("school_library","鲸歌阅读室",-23,5,14,11,.12),room("school_science","海洋科学教室",-7,7,15,10,-.16),room("school_art","色彩手作小间",10,5,13,11,.13)]
  return [room("school_math","星图数学教室",-23,-17,17,12,-.13),room("school_language","海港语言教室",-4,-16,13,11,.15),room("school_media","媒体学习角",11,-16,12,10,-.12),room("school_observatory","天文实验室",-23,5,17,11,.14),room("school_craft","工艺实践室",-4,8,12,9,.15),room("school_store","教具收纳室",10,5,13,11,-.10)]
 if building=="hospital":
  if level==1:
   return [room("hospital_lobby","海湾医院接待大厅",-23,-17,20,12,.14),room("hospital_triage","分诊与登记",0,-15,11,10,-.13),room("hospital_consult","门诊检查室",13,-16,10,11,.12),room("hospital_pharmacy","药房取药窗口",-23,5,16,11,-.15),room("hospital_imaging","影像检查室",-5,8,12,9,.12),room("hospital_waiting","安静候诊区",9,5,14,11,-.16)]
  return [room("hospital_ward","日光双人病房",-23,-17,16,12,-.14),room("hospital_treatment","护理治疗室",-4,-16,13,11,.16),room("hospital_nurse","护士工作站",11,-16,12,10,-.12),room("hospital_recovery","恢复观察间",-23,5,17,11,.14),room("hospital_lab","检验工作间",-4,8,12,9,.15),room("hospital_quiet","家属休息室",10,5,13,11,-.10)]
 if building=="observatory":
  if level==1:
   return [room("ocean_exhibit","潮汐海洋标本大厅",-23,-17,19,12,.15),room("aquatic_lab","海水与生态实验室",-1,-14,11,10,-.15),room("navigation_archive","航海档案小库",13,-16,10,9,.12),room("seed_lab","样本植物温室",-23,4,13,12,-.16),room("weather_lab","气象仪器间",-7,8,9,8,.12),room("sea_lounge","海风值班茶厅",5,5,18,11,-.16)]
  if level==2:
   return [room("sky_observation","大望远镜观测厅",-23,-14,18,10,-.14),room("chart_lab","星图研究工作厅",-2,-17,25,12,.18),room("radio","海洋无线电室",-23,4,12,12,.12),room("photo_archive","航拍影像资料室",-8,9,11,8,-.12),room("weather_lab","气象记录小室",6,10,7,7,.08),room("sea_lounge","夜班安静休息间",16,5,7,11,-.10)]
  return [room("planetarium","星空穹顶大展厅",-23,-17,22,14,.16),room("sky_observation","精密观测工作间",2,-16,12,10,-.12),room("calibration","镜片校准小室",17,-13,6,8,.05),room("chart_lab","潮汐与星轨测算厅",-23,5,21,11,-.18),room("instrument_store","观测器材储藏室",1,10,10,7,.12),room("navigation_archive","历年天象档案室",14,7,9,10,-.12)]
 if building=="music":
  if level==1:
   return [room("performance","蓝鲸小剧场",-23,-17,22,12,.15),room("recording","隔音录音小间",2,-14,8,9,-.12),room("mixing","声音混录工作室",13,-16,10,10,.12),room("instrument_repair","乐器修理工坊",-23,4,11,12,-.14),room("percussion","鼓乐排练间",-9,8,12,9,.16),room("music_lounge","演出前会客厅",6,5,17,11,-.15)]
  return [room("rehearsal","合奏大排练厅",-23,-17,25,12,-.15),room("vinyl_library","唱片试听藏书室",5,-14,18,9,.16),room("instrument_store","乐器收藏小库",-23,9,8,8,-.10),room("piano_room","窗边琴房",-12,5,10,12,.15),room("songwriting","歌词与旋律创作厅",1,6,14,10,-.16),room("music_lounge","午后静听休息室",18,10,5,7,.12)]
 return []

static func floor_style(kind: String,fallback: String) -> String:
 if kind.begins_with("restaurant_"):return "pale_oak" if kind not in ["restaurant_kitchen","restaurant_pantry"] else "terrazzo"
 if kind.begins_with("school_"):return "pale_oak" if kind not in ["school_science","school_observatory"] else "terrazzo"
 if kind.begins_with("hospital_"):return "ivory_tile" if kind not in ["hospital_waiting","hospital_quiet"] else "pale_oak"
 if kind in ["performance","recording","mixing","percussion","rehearsal","vinyl_library","piano_room"]:return "walnut" if kind in ["performance","piano_room"] else "navy_carpet"
 if kind in ["aquatic_lab","ocean_exhibit","seed_lab","weather_lab","calibration"]:return "terrazzo"
 if kind in ["chart_lab","navigation_archive","photo_archive","songwriting"]:return "pale_oak"
 if kind=="planetarium":return "navy_carpet"
 return fallback

static func _props(g,c: Vector3,specs: Array) -> void:
 for spec in specs:
  if g.catalog.has(str(spec[0])):g._prop(spec[0],c+spec[1],float(spec[2]) if spec.size()>2 else 0.0)

static func _equipment(g,c: Vector3,id: String,pos: Vector3) -> void:
 if g.catalog.has("v18_special_"+id):g._prop("v18_special_"+id,c+pos)

static func furnish(g,b,c: Vector3,kind: String,_index: int) -> bool:
 if kind.begins_with("restaurant_") or kind.begins_with("school_") or kind.begins_with("hospital_"):
  return true
 match kind:
  "ocean_exhibit","aquatic_lab":
   for x in [-3.5,0.0,3.5]:_equipment(g,c,"specimen_tank",Vector3(x,0,-2.6))
   _props(g,c,[["v18_aquarium",Vector3(-3.3,0,2.0)],["v18_interior_writing_desk",Vector3(2.8,0,2.0)],["chair_white",Vector3(2.8,0,3.3),180]])
   b.box(Vector3(8.8,.03,.12),c+Vector3(0,.06,-3.6),Color("71aeb9"))
  "navigation_archive","photo_archive":
   for x in [-3.8,0.0,3.8]:_equipment(g,c,"chart_cabinet",Vector3(x,0,-3.4))
   _equipment(g,c,"star_desk",Vector3(-2.4,0,1.7))
   _props(g,c,[["v18_interior_ivory_bookcase",Vector3(4.0,0,2.7)],["v18_interior_floor_lamp",Vector3(-4.4,0,2.1)]])
  "seed_lab":
   for x in [-3.7,0.0,3.7]:_props(g,c,[["v18_greenhouse_shelf",Vector3(x,0,-3.5)],["v18_hydrangea",Vector3(x,0,1.2)]])
   _props(g,c,[["v18_whale_planter",Vector3(-3,0,3.0)],["v18_interior_writing_desk",Vector3(2.8,0,2.7)]])
  "weather_lab","radio":
   _equipment(g,c,"weather_station",Vector3(-3.1,0,-2.6))
   _equipment(g,c,"radio_console",Vector3(2.4,0,-2.4))
   _equipment(g,c,"chart_cabinet",Vector3(3.7,0,2.5))
   _props(g,c,[["office_chair",Vector3(2.4,0,-.6),180],["v18_interior_writing_desk",Vector3(-2.9,0,2.7)]])
  "sky_observation","planetarium":
   var floor=b.cylinder(3.0,.045,c+Vector3(0,.07,0),Color("819fb2"))
   floor.name="ObservationPlatform"
   _equipment(g,c,"telescope",Vector3(0,0,-.4))
   for x in [-3.8,3.8]:_props(g,c,[["v18_street_bench",Vector3(x,0,2.7)]])
   _equipment(g,c,"star_desk",Vector3(-3.5,0,-3.2))
   if kind=="planetarium":
    # Low orbit rings keep the front doorway open and give this large room its own silhouette.
    var ring:=MeshInstance3D.new();var mesh:=TorusMesh.new();mesh.inner_radius=2.65;mesh.outer_radius=2.70;mesh.rings=48;mesh.ring_segments=8;ring.mesh=mesh;ring.position=c+Vector3(0,.14,0);ring.material_override=b.material(Color("d8cba7"));b.add_child(ring)
    for i in 9:
     var a: float=i*TAU/9;b.pillow(Vector3(.10,.10,.10),c+Vector3(cos(a)*2.8,.22,sin(a)*2.8),Color("eddfb5"))
  "chart_lab","calibration":
   for x in [-3.0,3.0]:_equipment(g,c,"star_desk",Vector3(x,0,-2.0))
   _equipment(g,c,"telescope",Vector3(0,0,2.0))
   _props(g,c,[["chair_white",Vector3(-3,0,-.6),180],["chair_white",Vector3(3,0,-.6),180],["v18_interior_ivory_bookcase",Vector3(-4.3,0,-4.2)]])
  "sea_lounge","music_lounge":
   _props(g,c,[["v18_interior_cream_sofa",Vector3(-2.6,0,-2.6)],["v18_interior_tea_table",Vector3(-1.6,0,.1)],["v18_reading_chair",Vector3(2.2,0,1.0)],["v18_tea_cart",Vector3(3.9,0,-3.0)],["v18_record_cabinet",Vector3(-4.1,0,2.8)],["v18_hydrangea",Vector3(4.0,0,3.0)]])
  "performance":
   b.box(Vector3(8.8,.18,3.0),c+Vector3(0,.1,-2.5),Color("9caba7"))
   _equipment(g,c,"upright_piano",Vector3(-2.4,.2,-2.7));_equipment(g,c,"microphone",Vector3(1.8,.2,-1.8))
   for x in [-4.2,4.2]:_equipment(g,c,"speaker_stack",Vector3(x,0,-2.0))
   for x in [-3.0,0.0,3.0]:
    for z in [.5,2.4]:_props(g,c,[["chair_white",Vector3(x,0,z)]])
  "recording","mixing":
   _equipment(g,c,"mixing_console",Vector3(0,0,-2.6));_equipment(g,c,"microphone",Vector3(-2.6,0,1.4));_equipment(g,c,"guitar_stand",Vector3(3.3,0,2.0))
   _props(g,c,[["office_chair",Vector3(0,0,-.9),180]])
   for x in [-4.0,4.0]:
    for z in [-3.0,-1.0,1.0,3.0]:b.box(Vector3(.08,1.25,.70),c+Vector3(x,.90,z),Color("587486"))
  "percussion","rehearsal":
   _equipment(g,c,"drum_kit",Vector3(-2.0,0,-1.8));_equipment(g,c,"upright_piano",Vector3(3.0,0,-2.8));_equipment(g,c,"guitar_stand",Vector3(3.0,0,2.0));_equipment(g,c,"microphone",Vector3(-.3,0,2.1))
   b.box(Vector3(6.8,.016,4.8),c+Vector3(-.8,.04,-.6),Color("627d8b"))
  "instrument_repair","instrument_store":
   _props(g,c,[["v18_interior_writing_desk",Vector3(-2.6,0,-2.4)],["v18_sewing_basket",Vector3(-2.8,0,1.7)],["v18_parcels",Vector3(3.5,0,3.0)]])
   for x in [-3.6,.1,3.6]:_equipment(g,c,"guitar_stand",Vector3(x,0,-3.8))
   _equipment(g,c,"chart_cabinet",Vector3(3.1,0,-.1))
  "vinyl_library":
   for x in [-3.8,0.0,3.8]:_props(g,c,[["v18_record_cabinet",Vector3(x,0,-3.5)]])
   _props(g,c,[["v18_reading_chair",Vector3(-2.2,0,1.3)],["v18_reading_chair",Vector3(2.2,0,1.3)],["v18_interior_tea_table",Vector3(0,0,2.8)]])
  "piano_room":
   _equipment(g,c,"upright_piano",Vector3(0,0,-2.5))
   _props(g,c,[["v18_reading_chair",Vector3(-3.0,0,2.1)],["v18_interior_floor_lamp",Vector3(-4.1,0,2.0)],["v18_hydrangea",Vector3(3.1,0,2.2)]])
  "songwriting":
   _props(g,c,[["v18_interior_writing_desk",Vector3(-2.3,0,-2.4)],["v18_interior_ivory_bookcase",Vector3(-4.4,0,-3.9)],["v18_interior_cream_sofa",Vector3(2.5,0,2.7)]])
   _equipment(g,c,"upright_piano",Vector3(2.6,0,-2.6));_equipment(g,c,"guitar_stand",Vector3(-2.9,0,2.0))
  _:return false
 return true
