@tool
extends RefCounted
## Shared, editable modern materials. No baked dirt or aged surfaces.
static var cache: Dictionary = {}

static func surface(color: Color, metal: bool = false, fabric: bool = false) -> StandardMaterial3D:
 var key:=str(color)+str(metal)+str(fabric)
 if cache.has(key):return cache[key]
 var m:=StandardMaterial3D.new();m.albedo_color=color
 m.resource_name="modern_fabric" if fabric else ("modern_metal" if metal else "modern_paint")
 m.roughness=.93 if fabric else (.42 if metal else .72)
 m.metallic=.58 if metal else 0.0
 m.metallic_specular=.24 if metal else (.10 if fabric else .18)
 cache[key]=m;return m

static func led(color: Color, power: float = .65) -> StandardMaterial3D:
 var key: String="led"+str(color)+str(power)
 if cache.has(key):return cache[key]
 var m:=surface(color).duplicate();m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=power
 cache[key]=m;return m

static func floor_material(style: String) -> ShaderMaterial:
 var key: String="floor"+style
 if cache.has(key):return cache[key]
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
 #include "res://assets/modern/shaders/filtered_grid.gdshaderinc"
 varying vec3 wp;
 uniform vec3 tile_color=vec3(.72,.75,.78);
 uniform float tile_size=1.1;
 uniform float roughness_value=.58;
 uniform int pattern=0;
 float hash21(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
 float seam(vec2 p){vec2 joint=filtered_grid_axes(p,vec2(.004));return joint.x+joint.y-joint.x*joint.y;}
 // The box filter's sinc response averages fine fibers within each pixel.
 float filtered_wave(float phase){float width=max(fwidth(phase)*.5,.0001);return sin(phase)*sin(width)/width;}
 void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
 void fragment(){
  vec2 p=wp.xz;vec2 t=p/tile_size;float grout=seam(t);float variation=hash21(floor(t));
  vec3 color=mix(tile_color*(.985+variation*.03),tile_color*.79,grout*.52);
  if(pattern==1 || pattern==7){
   vec2 wood=p;
   if(pattern==7){wood=vec2(p.x+p.y,p.y-p.x)*.7071;wood.x*=mod(floor(wood.y/.32),2.)<1.?1.:-1.;}
   vec2 planks=wood/vec2(2.2,.32);planks.x+=mod(floor(planks.y),3.)*.3333;
   float grain=filtered_wave(wood.x*23.+sin(wood.y*17.)*2.)*.015;
   color=mix(tile_color*(.95+hash21(floor(planks))*.10+grain),tile_color*.69,seam(planks)*.55);
  }else if(pattern==2){
   float weave=filtered_wave(p.x*65.)*filtered_wave(p.y*65.);
   color=tile_color*(.99+weave*.012);SPECULAR=.035;
  }else if(pattern==3){
   vec2 speck=p*19.;float random=hash21(floor(speck));float dot_size=.07+random*.15;
   float coverage=max(length(fwidth(speck)),.10);
   float chip=1.-smoothstep(dot_size-coverage*.5,dot_size+coverage*.5,length(fract(speck)-.5));
   float detail=1.-smoothstep(.45,1.1,coverage);
   color=tile_color*(1.-chip*(random>.55?.12:-.10)*detail);
  }else if(pattern==4){
   float vein=sin(p.x*.66+p.y*.47+sin(p.y*.91)*1.9);
   color=tile_color*(.96+.04*vein);color=mix(color,tile_color*.77,(1.-smoothstep(.025,.11,abs(vein)))*.35);
  }else if(pattern==5){
   vec2 mats=p/vec2(1.0,2.0);float straw=filtered_wave(p.y*72.)*.013;
   color=mix(tile_color*(.99+straw),tile_color*.73,seam(mats)*.7);
  }else if(pattern==6){
   float detail=1.-smoothstep(.35,1.1,length(fwidth(p*7.)));
   color=tile_color*(.9975+(hash21(floor(p*7.))-.5)*.025*detail);
  }
  ALBEDO=color;ROUGHNESS=roughness_value;
  if(pattern!=2){SPECULAR=.12;}
 }
 """
 var m:=ShaderMaterial.new();m.shader=shader
 var colors: Dictionary={"ivory_tile":Color("a9b4be"),"slate_tile":Color("939fa9"),"concrete":Color("adb9c1"),"marble":Color("bcc7d0"),"terrazzo":Color("bbc8cf"),"metal_grid":Color("8b9ba7"),"oak":Color("d4c7b1"),"pale_oak":Color("dfd9c9"),"walnut":Color("8e8a82"),"herringbone":Color("c0bcb3"),"navy_carpet":Color("51627a"),"tatami":Color("c9cbbb")}
 var tint: Color=colors.get(style,Color("a9b4be"))
 m.set_shader_parameter("tile_color",tint.srgb_to_linear())
 m.set_shader_parameter("tile_size",1.1 if style!="metal_grid" else .55)
 m.set_shader_parameter("roughness_value",.9 if style=="navy_carpet" else .72)
 var patterns: Dictionary={"oak":1,"pale_oak":1,"walnut":1,"herringbone":7,"navy_carpet":2,"terrazzo":3,"marble":4,"tatami":5,"concrete":6}
 m.set_shader_parameter("pattern",int(patterns.get(style,0)))
 cache[key]=m;return m

static func glass() -> StandardMaterial3D:
 if cache.has("glass"):return cache.glass
 var m:=StandardMaterial3D.new();m.albedo_color=Color(.63,.85,.94,.14)
 m.resource_name="modern_glass"
 m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS;m.roughness=.22;m.metallic=0.0;m.metallic_specular=.30
 cache.glass=m;return m
