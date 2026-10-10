extends RefCounted
## Small chamfers catch broad light; detail is sized for the gameplay camera.
const SURFACE=preload("res://assets/modern/shaders/story_surface.gdshader")
static var material_cache: Dictionary={}
static var mesh_cache: Dictionary={}

static func material(color: Color,kind: int=0) -> Material:
 var key: String=str(color)+":"+str(kind)
 if material_cache.has(key):return material_cache[key]
 var result:=ShaderMaterial.new();result.shader=SURFACE
 result.set_shader_parameter("base_color",color);result.set_shader_parameter("finish_kind",kind)
 result.set_shader_parameter("roughness_value",.68 if kind==1 else (.54 if kind==2 else .84))
 material_cache[key]=result;return result

static func _face(tool: SurfaceTool,points: Array[Vector3],normal: Vector3) -> void:
 for i in range(1,points.size()-1):
  var a: Vector3=points[0];var b: Vector3=points[i];var c: Vector3=points[i+1]
  if (b-a).cross(c-a).dot(normal)>0:var swap: Vector3=b;b=c;c=swap
  for vertex in [a,b,c]:tool.set_normal(normal);tool.set_uv(Vector2(vertex.x,vertex.z));tool.add_vertex(vertex)

static func beveled_mesh(size: Vector3,bevel: float) -> ArrayMesh:
 var radius: float=minf(bevel,minf(size.x,minf(size.y,size.z))*.22)
 var key: String=str(size)+":"+str(radius)
 if mesh_cache.has(key):return mesh_cache[key]
 var half: Vector3=size*.5;var inner: Vector3=half-Vector3.ONE*radius
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for axis in 3:
  var u: int=(axis+1)%3;var v: int=(axis+2)%3
  for sign_value in [-1.0,1.0]:
   var normal:=Vector3.ZERO;normal[axis]=sign_value
   var points: Array[Vector3]=[]
   for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
    var point:=Vector3.ZERO;point[axis]=half[axis]*sign_value;point[u]=inner[u]*corner.x;point[v]=inner[v]*corner.y;points.append(point)
   _face(tool,points,normal)
 for a in 3:
  for b in range(a+1,3):
   var c: int=3-a-b
   for sa in [-1.0,1.0]:
    for sb in [-1.0,1.0]:
     var normal:=Vector3.ZERO;normal[a]=sa;normal[b]=sb
     var points: Array[Vector3]=[]
     for mode in [Vector2(0,-1),Vector2(1,-1),Vector2(1,1),Vector2(0,1)]:
      var point:=Vector3.ZERO;point[a]=(half[a] if mode.x==0 else inner[a])*sa;point[b]=(inner[b] if mode.x==0 else half[b])*sb;point[c]=inner[c]*mode.y;points.append(point)
     _face(tool,points,normal.normalized())
 for x in [-1.0,1.0]:
  for y in [-1.0,1.0]:
   for z in [-1.0,1.0]:
    var signs:=Vector3(x,y,z);var points: Array[Vector3]=[]
    for axis in 3:
     var point: Vector3=inner*signs;point[axis]=half[axis]*signs[axis];points.append(point)
    _face(tool,points,signs.normalized())
 var mesh: ArrayMesh=tool.commit();mesh_cache[key]=mesh;return mesh

static func box(parent: Node3D,size: Vector3,position: Vector3,color: Color,kind: int=0,bevel: float=.035) -> MeshInstance3D:
 var node:=MeshInstance3D.new();node.mesh=beveled_mesh(size,bevel);node.material_override=material(color,kind);node.position=position;parent.add_child(node);return node

static func cylinder(parent: Node3D,radius: float,height: float,position: Vector3,color: Color,top_radius: float=-1.0) -> MeshInstance3D:
 var mesh:=CylinderMesh.new();mesh.bottom_radius=radius;mesh.top_radius=radius if top_radius<0 else top_radius;mesh.height=height;mesh.radial_segments=20
 var node:=MeshInstance3D.new();node.mesh=mesh;node.position=position;node.material_override=material(color);parent.add_child(node);return node

static func rod(parent: Node3D,a: Vector3,b: Vector3,radius: float,color: Color) -> void:
 var node: MeshInstance3D=cylinder(parent,radius,a.distance_to(b),(a+b)*.5,color)
 var axis: Vector3=(b-a).normalized();var tangent: Vector3=Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT))<.90 else Vector3.FORWARD
 var right: Vector3=axis.cross(tangent).normalized();node.basis=Basis(right,axis,right.cross(axis).normalized())

static func contact(parent: Node3D,position: Vector3,size: Vector2,opacity: float=.16) -> void:
 var shader:=Shader.new();shader.code="""shader_type spatial;render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;
 uniform float opacity=.16;void fragment(){vec2 p=(UV-.5)*2.;float d=dot(p,p);ALBEDO=vec3(.22,.235,.32);ALPHA=exp(-d*3.8)*(1.-smoothstep(.6,1.,d))*opacity;}"""
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("opacity",opacity);material.render_priority=-1
 var node:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=size;node.mesh=plane;node.position=position;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node)
