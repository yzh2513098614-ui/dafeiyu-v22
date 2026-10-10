extends RefCounted
## Twelve surface recipes reuse the four full-resolution generated albedo tiles.
const SHADER=preload("res://assets/modern/shaders/wall_surface.gdshader")
const DIR="res://assets/modern/wall_surfaces/"
const PRESETS={
 "plaster_ivory":{"name":"细腻暖白灰泥","scope":"内墙","grain":"plaster_ivory","tint":"dce0d7","pattern":0,"unit":Vector2(1,1),"scale":Vector2(1.8,1.8),"detail":.28,"roughness":.90},
 "linen_bluegrey":{"name":"浅蓝灰布纹墙纸","scope":"内墙","grain":"linen_bluegrey","tint":"bccad0","pattern":0,"unit":Vector2(1,1),"scale":Vector2(6.5,6.5),"detail":.38,"roughness":.94,"type":2,"specular":.10},
 "oak_vertical":{"name":"浅橡木竖拼护墙","scope":"内墙","grain":"oak_fine","tint":"cbbfa8","pattern":1,"unit":Vector2(.36,2.1),"scale":Vector2(.75,1.8),"detail":.46,"roughness":.68,"wainscot":.80,"type":1,"specular":.28},
 "tile_seaglass":{"name":"海玻璃青色方砖","scope":"内墙","grain":"plaster_ivory","tint":"b7cdc8","pattern":3,"unit":Vector2(.30,.30),"scale":Vector2(1,1),"detail":.07,"roughness":.32,"type":3,"specular":.38},
 "tile_ivory":{"name":"暖白错缝瓷砖","scope":"内墙","grain":"plaster_ivory","tint":"dce3df","pattern":2,"unit":Vector2(.36,.18),"scale":Vector2(1,1),"detail":.07,"roughness":.36,"type":3,"specular":.35},
 "terrazzo_wainscot":{"name":"浅灰水磨石护墙","scope":"内墙","grain":"stone_limestone","tint":"c6d0cd","pattern":9,"unit":Vector2(1,1),"scale":Vector2(.85,.85),"detail":.70,"roughness":.80},
 "brick_warm":{"name":"暖米色错缝砖","scope":"外墙","grain":"stone_limestone","tint":"d2cbb9","pattern":2,"unit":Vector2(.52,.24),"scale":Vector2(1.3,1.3),"detail":.56,"roughness":.89},
 "brick_bluegrey":{"name":"灰蓝色细砖","scope":"外墙","grain":"plaster_ivory","tint":"b8c6cf","pattern":2,"unit":Vector2(.45,.22),"scale":Vector2(1.4,1.4),"detail":.55,"roughness":.88},
 "limestone_blocks":{"name":"浅石灰岩大块饰面","scope":"外墙","grain":"stone_limestone","tint":"d5d7ce","pattern":4,"unit":Vector2(1.15,.58),"scale":Vector2(1.3,1.3),"detail":.72,"roughness":.86},
 "oak_horizontal":{"name":"浅木色横向挂板","scope":"外墙","grain":"oak_fine","tint":"c9c0ac","pattern":5,"unit":Vector2(2.4,.25),"scale":Vector2(1.7,.75),"detail":.58,"roughness":.84},
 "metal_blue":{"name":"海蓝立缝金属板","scope":"外墙","grain":"plaster_ivory","tint":"afc3cd","pattern":7,"unit":Vector2(.90,3.2),"scale":Vector2(2,2),"detail":.10,"roughness":.43,"metal":0.0,"type":4,"specular":.32},
 "stucco_cool":{"name":"浅冷灰细颗粒涂层","scope":"外墙","grain":"plaster_ivory","tint":"cbd5d2","pattern":0,"unit":Vector2(1,1),"scale":Vector2(1.35,1.35),"detail":.60,"roughness":.93}
}
const ROOMS={
 "restaurant_dining":"linen_bluegrey","restaurant_patisserie":"tile_seaglass","restaurant_bar":"oak_vertical","restaurant_kitchen":"tile_ivory","restaurant_pantry":"plaster_ivory","restaurant_lounge":"oak_vertical",
 "school_lobby":"terrazzo_wainscot","school_classroom":"oak_vertical","school_staff":"plaster_ivory","school_library":"oak_vertical","school_science":"tile_seaglass","school_art":"plaster_ivory","school_math":"plaster_ivory","school_language":"linen_bluegrey","school_media":"linen_bluegrey","school_observatory":"linen_bluegrey","school_craft":"oak_vertical","school_store":"plaster_ivory",
 "hospital_lobby":"terrazzo_wainscot","hospital_triage":"tile_seaglass","hospital_consult":"tile_ivory","hospital_pharmacy":"tile_ivory","hospital_imaging":"linen_bluegrey","hospital_waiting":"plaster_ivory","hospital_ward":"tile_seaglass","hospital_treatment":"tile_ivory","hospital_nurse":"terrazzo_wainscot","hospital_recovery":"oak_vertical","hospital_lab":"tile_ivory","hospital_quiet":"linen_bluegrey"
}
const BUILDINGS={"restaurant":"brick_warm","school":"brick_bluegrey","hospital":"limestone_blocks","apartment":"stucco_cool","community":"oak_horizontal","inn":"brick_bluegrey","shop":"brick_warm","flower":"stucco_cool","cafe":"oak_horizontal","market":"metal_blue","music":"brick_bluegrey","gallery":"limestone_blocks","bookshop":"brick_warm","observatory":"metal_blue","studio":"stucco_cool","office":"limestone_blocks"}
const MEANS={"plaster_ivory":Color(.8114,.7837,.7303),"oak_fine":Color(.7827,.7149,.6008),"stone_limestone":Color(.7409,.7137,.6596),"linen_bluegrey":Color(.6213,.6663,.6786)}
static var cache: Dictionary={}
static var interior_shader: Shader

static func material(id: String,axis: Vector3=Vector3.RIGHT,outside: bool=false,tint: Color=Color.WHITE) -> ShaderMaterial:
 var key: String=id+str(axis)+str(outside)+str(tint)
 if cache.has(key):return cache[key]
 var recipe: Dictionary=PRESETS[id]
 var result:=ShaderMaterial.new();result.resource_name="wall_surface_"+id
 if not outside:
  if interior_shader==null:
   interior_shader=Shader.new();interior_shader.code=SHADER.code.replace("render_mode specular_schlick_ggx;","render_mode specular_schlick_ggx, shadows_disabled;")
  result.shader=interior_shader
 else:result.shader=SHADER
 var color:=Color(recipe.tint)
 if outside:color=color.lerp(tint,.35)
 # This v22 project uses the Compatibility renderer's sRGB lighting space.
 # vec3 uniforms require Vector3: passing Color leaves the shader default.
 var mean: Color=MEANS[recipe.grain]
 result.set_shader_parameter("grain_texture",load(DIR+recipe.grain+"_v1.png"))
 result.set_shader_parameter("grain_mean",mean.r*.2126+mean.g*.7152+mean.b*.0722)
 result.set_shader_parameter("wall_color",Vector3(color.r,color.g,color.b))
 result.set_shader_parameter("wall_axis",axis.normalized())
 result.set_shader_parameter("grain_scale",recipe.scale)
 result.set_shader_parameter("grain_strength",recipe.detail)
 result.set_shader_parameter("unit_size",recipe.unit)
 result.set_shader_parameter("pattern",recipe.pattern)
 result.set_shader_parameter("joint_width",.008 if outside else .004)
 result.set_shader_parameter("joint_contrast",.18 if outside else .15)
 result.set_shader_parameter("roughness_value",recipe.roughness)
 result.set_shader_parameter("specular_value",recipe.get("specular",.20))
 result.set_shader_parameter("surface_type",recipe.get("type",0))
 result.set_shader_parameter("roughness_variation",.06 if recipe.get("type",0)==1 else .025)
 result.set_shader_parameter("relief_depth",.0015 if recipe.get("type",0)==3 else .003)
 result.set_shader_parameter("normal_strength",.32 if recipe.get("type",0)==3 else .16)
 result.set_shader_parameter("metal_value",recipe.get("metal",0.0))
 result.set_shader_parameter("wainscot_height",recipe.get("wainscot",0.0))
 result.set_shader_parameter("facade",outside)
 result.set_shader_parameter("plinth",outside)
 cache[key]=result;return result

static func finish_module(root: Node3D,kind: String,axis: Vector3) -> void:
 var recipe: String=ROOMS[kind]
 for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var source: Material=mesh.mesh.surface_get_material(surface)
   if source==null:continue
   var bits: PackedStringArray=source.resource_name.split("_")
   if bits.size()!=3 or bits[0]!="wall" or bits[2]!="matte":continue
   # Colored raised trims retain their original geometry and finish.
   var color:=Color(bits[1]);var brightness: float=(color.r+color.g+color.b)/3.
   if brightness>.79:mesh.set_surface_override_material(surface,material(recipe,axis))
