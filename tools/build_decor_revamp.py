"""50 usable v22 furniture meshes: curved silhouettes, open frames, soft seats.

Coordinates use metres and Y up. Models carry explicit surface normals and
original-game color names so Godot can reuse its existing material library.
"""
from pathlib import Path
import json, math
import numpy as np
import trimesh

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "models" / "themed_props"
C = dict(cream="d8dcd8", white="d4dfe3", blue="476a8a", navy="354d66",
         metal="455665", silver="9aadb8", wood="aaa493", glass="88b9ca",
         leaf="729986", gold="b7a578", sage="9bb7b5", soil="58625a",
         pink="c5a5a8", orange="c6a176", red="b58487", chalk="c9d9de")
CATALOG = []

class Model:
    def __init__(self, name, label):
        self.name=name; self.label=label; self.scene=trimesh.Scene()
        self.materials={}; self.count=0

    def add(self, mesh, color, smooth=False, fabric=False):
        valid=mesh.area_faces>1e-12
        if not valid.all():
            mesh.update_faces(valid)
            mesh.remove_unreferenced_vertices()
        self.count+=1
        key=(color,fabric)
        if key not in self.materials:
            rgb=tuple(int(C[color][i:i+2],16) for i in (0,2,4))
            mode="glass" if color=="glass" else ("fabric" if fabric else
                  "metal" if color in ("metal","silver","gold") else "matte")
            self.materials[key]=trimesh.visual.material.PBRMaterial(
                name=f"decor_{C[color]}_{mode}",baseColorFactor=(*rgb,90 if mode=="glass" else 255),
                alphaMode="BLEND" if mode=="glass" else "OPAQUE",
                roughnessFactor=.23 if mode=="glass" else (.9 if fabric else .63),
                metallicFactor=.35 if mode=="metal" else 0,
                doubleSided=mode=="glass")
        if not smooth:
            mesh.unmerge_vertices()
            mesh.vertex_normals=mesh.face_normals.repeat(3,axis=0)
        mesh.visual=trimesh.visual.TextureVisuals(material=self.materials[key])
        self.scene.add_geometry(mesh,node_name=f"Part_{self.count:03d}")

    def round(self,size,center,color,r=.10,axis=1,angle=0):
        axes=[i for i in range(3) if i!=axis]
        a,b=size[axes[0]]/2,size[axes[1]]/2
        r=min(r,a*.9,b*.9)
        outline=[]
        for cx,cz,begin in [(a-r,b-r,0),(-a+r,b-r,math.pi/2),
                             (-a+r,-b+r,math.pi),(a-r,-b+r,3*math.pi/2)]:
            for i in range(7):
                theta=begin+i*math.pi/12
                outline.append((cx+r*math.cos(theta),cz+r*math.sin(theta)))
        vertices=[]
        for h in (-size[axis]/2,size[axis]/2):
            for aa,bb in outline:
                v=[0.,0.,0.]; v[axis]=h; v[axes[0]]=aa; v[axes[1]]=bb
                vertices.append(v)
        n=len(outline); faces=[]
        for i in range(n):
            j=(i+1)%n
            if axis==1: faces.extend(((i,j+n,j),(i,i+n,j+n)))
            else: faces.extend(((i,j,j+n),(i,j+n,i+n)))
        for i in range(1,n-1):
            if axis==1: faces.extend(((0,i,i+1),(n,n+i+1,n+i)))
            else: faces.extend(((0,i+1,i),(n,n+i,n+i+1)))
        mesh=trimesh.Trimesh(vertices=vertices,faces=faces,process=True)
        if angle: mesh.apply_transform(trimesh.transformations.rotation_matrix(angle,[0,1,0]))
        mesh.apply_translation(center); self.add(mesh,color)

    def ball(self,radii,center,color,fabric=False):
        mesh=trimesh.creation.icosphere(subdivisions=1 if max(radii)<.20 else 2)
        mesh.apply_scale(radii)
        normal=mesh.vertices/np.square(radii)
        mesh.vertex_normals=normal/np.linalg.norm(normal,axis=1)[:,None]
        mesh.apply_translation(center); self.add(mesh,color,True,fabric)

    def rod(self,a,b,r,color):
        delta=np.subtract(b,a)
        mesh=trimesh.creation.cylinder(radius=r,height=np.linalg.norm(delta),sections=16)
        mesh.apply_transform(trimesh.geometry.align_vectors([0,0,1],delta))
        mesh.apply_translation((np.array(a)+b)/2); self.add(mesh,color)

    def cyl(self,r,h,center,color):
        x,y,z=center; self.rod((x,y-h/2,z),(x,y+h/2,z),r,color)

    def ring(self,r,t,center,color,vertical=False):
        mesh=trimesh.creation.torus(major_radius=r,minor_radius=t,
                                  major_sections=32,minor_sections=8)
        if not vertical: mesh.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[1,0,0]))
        mesh.apply_translation(center); self.add(mesh,color)

    def lathe(self,profile,center,color):
        vertices=[]; faces=[]; n=32
        for r,y in profile:
            vertices.extend((r*math.cos(i*math.tau/n),y,r*math.sin(i*math.tau/n)) for i in range(n))
        for row in range(len(profile)-1):
            for i in range(n):
                j=(i+1)%n; a=row*n+i; b=row*n+j; c=b+n; d=a+n
                faces.extend(((a,c,b),(a,d,c)))
        mesh=trimesh.Trimesh(vertices=vertices,faces=faces,process=True)
        mesh.apply_translation(center); self.add(mesh,color)

    def tube(self,points,r,color):
        for a,b in zip(points[:-1],points[1:]): self.rod(a,b,r,color)
        for p in points[1:-1]: self.ball((r,r,r),p,color)

    def save(self):
        bounds=self.scene.bounds
        assert np.isfinite(bounds).all() and bounds[0,1]>=-.035, (self.name,bounds)
        # Combine disconnected parts that share one material. Preserve each
        # vertex normal, including smooth cushions and flat metal/wood edges.
        # This retains the shape while avoiding hundreds of nodes per shelf.
        groups={}
        for mesh in self.scene.geometry.values():
            groups.setdefault(mesh.visual.material.name,[]).append(mesh)
        optimized=trimesh.Scene()
        for name,parts in groups.items():
            vertices=[];faces=[];normals=[];offset=0
            for mesh in parts:
                vertices.append(mesh.vertices);faces.append(mesh.faces+offset)
                normals.append(mesh.vertex_normals);offset+=len(mesh.vertices)
            merged=trimesh.Trimesh(vertices=np.concatenate(vertices),faces=np.concatenate(faces),
                                   vertex_normals=np.concatenate(normals),process=False)
            merged.visual=trimesh.visual.TextureVisuals(material=parts[0].visual.material)
            optimized.add_geometry(merged,node_name=name)
        data=optimized.export(file_type="glb",include_normals=True)
        (OUT/f"{self.name}.glb").write_bytes(data)
        size=bounds[1]-bounds[0]; center=(bounds[1]+bounds[0])/2
        # A small, conservative collision margin; collider aligns to real bounds.
        w,h,d=(float(v)+.03 for v in size)
        cx,cy,cz=(float(v) for v in center)
        scene=f'''[gd_scene load_steps=3 format=3]
[ext_resource type="PackedScene" path="res://models/themed_props/{self.name}.glb" id="1"]
[sub_resource type="BoxShape3D" id="Collision"]
size = Vector3({w:.5f}, {h:.5f}, {d:.5f})
[node name="{self.name}" type="Node3D"]
[node name="Model" parent="." instance=ExtResource("1")]
[node name="Body" type="StaticBody3D" parent="."]
[node name="Collision" type="CollisionShape3D" parent="Body"]
position = Vector3({cx:.5f}, {cy:.5f}, {cz:.5f})
shape = SubResource("Collision")
'''
        (OUT/f"{self.name}.tscn").write_text(scene,encoding="utf-8")
        CATALOG.append(dict(id=self.name,name=self.label,parts=len(self.scene.geometry),surfaces=len(groups),
                            size=[w,h,d],center=[cx,cy,cz],bytes=len(data)))

def plant(m,x,y,z,s=.7,flowers=False):
    m.lathe([(0,0),(.16*s,0),(.23*s,.31*s),(.24*s,.36*s),
             (.20*s,.36*s),(.17*s,.27*s),(0,.27*s)],(x,y,z),"cream")
    m.cyl(.18*s,.018*s,(x,y+.28*s,z),"soil")
    for i in range(7):
        a=i*2.4; dx=math.cos(a)*.15*s; dz=math.sin(a)*.15*s
        yy=y+(.55+.12*(i%3))*s
        m.rod((x,y+.3*s,z),(x+dx,yy,z+dz),.012*s,"leaf")
        m.ball((.12*s,.045*s,.08*s),(x+dx,yy-.06*s,z+dz),"leaf")
        if flowers:
            for j in range(5):
                b=j*math.tau/5
                m.ball((.048*s,.045*s,.045*s),(x+dx+math.cos(b)*.05*s,yy,z+dz+math.sin(b)*.05*s),"blue" if i%2 else "pink")

def wheel(m,x,z,y=.10,r=.08):
    m.rod((x-.028,y,z),(x+.028,y,z),r,"metal")
    m.rod((x-.032,y,z),(x+.032,y,z),r*.46,"silver")
    m.rod((x,y+r,z),(x,y+r+.07,z),.025,"silver")

def cup(m,x,y,z,s=1):
    m.lathe([(0,0),(.055*s,0),(.065*s,.10*s),(.058*s,.11*s),
             (.05*s,.025*s),(0,.025*s)],(x,y,z),"cream")
    m.ring(.04*s,.009*s,(x+.075*s,y+.06*s,z),"cream",True)
    m.cyl(.044*s,.003*s,(x,y+.082*s,z),"wood")

def book(m,x,y,z,color="blue",s=1):
    m.round((.20*s,.035*s,.28*s),(x,y+.018*s,z),color,.016)
    m.round((.185*s,.018*s,.26*s),(x,y+.019*s,z),"cream",.009)

def chair(m,x,z,angle=0):
    # Curved shell and tubular legs instead of an upholstered rectangular block.
    group=Model("part","")
    group.ball((.32,.10,.30),(0,.48,0),"sage",True)
    group.ball((.33,.30,.09),(0,.73,-.25),"blue",True)
    for sx in (-.23,.23):
        group.tube([(sx,.04,.23),(sx,.43,.18),(sx,.47,-.20),(sx,.03,-.28)],.023,"metal")
    transform=trimesh.transformations.rotation_matrix(angle,[0,1,0]); transform[:3,3]=(x,0,z)
    for mesh in group.scene.geometry.values():
        normals=mesh.vertex_normals.copy()
        mesh=mesh.copy(); mesh.apply_transform(transform)
        mesh.vertex_normals=normals@transform[:3,:3].T
        m.scene.add_geometry(mesh,node_name=f"Chair_{len(m.scene.geometry):03d}")

def monitor(m,x,y,z):
    m.round((.45,.055,.28),(x,y+.025,z),"silver",.07)
    m.rod((x,y+.06,z),(x,y+.34,z),.034,"metal")
    m.round((.59,.39,.075),(x,y+.49,z),"navy",.055,2)
    m.round((.51,.31,.014),(x,y+.49,z+.045),"blue",.03,2)
    for i in range(8):
        a=(x-.21+i*.058,y+.48+(.075 if i in (3,4) else -.015),z+.055)
        b=(x-.21+(i+1)*.058,y+.48+(.075 if i+1 in (3,4) else -.015),z+.055)
        m.rod(a,b,.007,"sage")

def shelf(m,w=1.75,h=1.8,d=.46,mode="books"):
    for x in (-w/2+.055,w/2-.055):
        m.tube([(x,.025,-d/2+.04),(x,h,-d/2+.04),(x,h,d/2-.04),(x,.025,d/2-.04)],.033,"metal")
    for row in range(4):
        y=.16+row*(h-.25)/3
        m.round((w,.055,d),(0,y,0),"wood" if mode=="books" else "cream",.07)
        if row==3: continue
        if mode=="books":
            for i in range(9):
                x=-w*.40+i*w*.10
                m.round((.09,.25+.035*(i%3),.24),(x,y+.17,0),["blue","sage","cream","wood"][i%4],.012,0)
        elif mode=="pantry":
            for i in range(5):
                x=-w*.37+i*w*.185
                m.lathe([(0,0),(.105,0),(.115,.23),(.10,.25),(0,.25)],(x,y+.03,0),"sage" if i%2 else "cream")
                m.cyl(.115,.025,(x,y+.30,0),"wood")
        else:
            for i in range(5):
                x=-w*.37+i*w*.185
                m.round((.20,.25,.25),(x,y+.17,0),"white",.04)
                m.round((.16,.055,.01),(x,y+.16,.132),"blue",.01,2)

def core_models():
    m=Model("restaurant_booth_set","圆背软垫餐厅卡座")
    for side in (-1,1):
        x=side*.93
        for z in (-.54,.54): m.rod((x,.035,z),(x,.44,z),.052,"wood")
        m.round((.65,.12,1.58),(x,.46,0),"wood",.20)
        for z in (-.48,0,.48):
            m.ball((.31,.13,.255),(x,.57,z),"blue",True)
            m.ball((.12,.40,.28),(x+side*.25,.82,z),"navy",True)
        for z in (-.74,.74):
            m.ball((.11,.15,.17),(x,.72,z),"blue",True)
    m.round((1.25,.075,1.48),(0,.84,0),"cream",.40)
    m.cyl(.055,.69,(0,.45,0),"metal"); m.round((.60,.055,.80),(0,.045,0),"metal",.25)
    for z in (-.40,.40):
        m.cyl(.15,.012,(0,.887,z),"white"); cup(m,0,.899,z)
    plant(m,0,.879,0,.34); m.save()

    m=Model("restaurant_pastry_display","圆弧玻璃糕点柜")
    for x in (-.96,.96):
        for z in (-.31,.31): m.rod((x,.035,z),(x,.78,z),.037,"metal")
    for y in (.20,.73,.98): m.round((2.25,.055,.79),(0,y,0),"wood" if y<.4 else "cream",.16)
    m.round((2.27,.13,.82),(0,.85,0),"navy",.16)
    # Curved glazed hood: a real arc section with thin struts.
    for x in (-1.08,1.08):
        points=[(x,1.06+.48*math.sin(a),-.31+.65*math.cos(a)) for a in np.linspace(0,math.pi/2,10)]
        m.tube(points,.017,"silver")
    for i in range(9):
        a,b=(i*math.pi/18,(i+1)*math.pi/18)
        vertices=[(-1.06,1.06+.48*math.sin(a),-.31+.65*math.cos(a)),
                  (1.06,1.06+.48*math.sin(a),-.31+.65*math.cos(a)),
                  (1.06,1.06+.48*math.sin(b),-.31+.65*math.cos(b)),
                  (-1.06,1.06+.48*math.sin(b),-.31+.65*math.cos(b))]
        m.add(trimesh.Trimesh(vertices=vertices,faces=[(0,1,2),(0,2,3)],process=False),"glass")
    for x in (-.76,-.38,0,.38,.76):
        m.cyl(.12,.03,(x,1.03,0),"cream")
        m.ball((.09,.07,.085),(x,1.10,0),"orange" if x<0 else "pink")
        m.ball((.025,.025,.025),(x,1.16,0),"cream")
    for x in (-.75,0,.75): m.lathe([(0,0),(.18,0),(.22,.18),(.18,.20),(0,.20)],(x,.24,0),"wood")
    m.save()

    m=Model("restaurant_service_cart","开放式圆角餐车")
    for x in (-.39,.39):
        for z in (-.26,.26): wheel(m,x,z); m.rod((x,.22,z),(x,1.02,z),.025,"silver")
    for y in (.31,.88): m.round((.98,.055,.68),(0,y,0),"wood",.15)
    m.tube([(-.44,.87,-.30),(-.44,1.14,-.30),(.44,1.14,-.30),(.44,.87,-.30)],.025,"metal")
    for x in (-.25,0,.25): m.cyl(.10,.015,(x,.92,.06),"cream"); cup(m,x,.93,.06)
    for i in range(4): m.cyl(.12,.013,(.20,.36+i*.018,0),"white")
    m.save()

    m=Model("school_learning_board","管架圆角教学板")
    for x in (-1.30,1.30):
        m.rod((x,.11,0),(x,2.13,0),.033,"metal")
        for z in (-.32,.32): wheel(m,x,z,.08,.06)
        m.rod((x,.13,-.32),(x,.13,.32),.032,"metal")
    m.round((2.90,1.42,.12),(0,1.42,0),"silver",.15,2)
    m.round((2.75,1.28,.018),(0,1.42,.077),"navy",.10,2)
    m.round((2.5,.045,.20),(0,.69,.07),"cream",.07)
    for a,b in [((-.95,1.20),(-.40,1.80)),((-.40,1.80),(.15,1.20)),((.15,1.20),(-.95,1.20))]:
        m.rod((a[0],a[1],.092),(b[0],b[1],.092),.009,"chalk")
    m.ring(.23,.011,(.74,1.46,.092),"chalk",True)
    for i in range(3): m.rod((.40,1.05+i*.1,.092),(1.05,1.05+i*.1,.092),.008,"chalk")
    m.save()

    m=Model("school_twin_desks","弧边课桌与曲背椅")
    for x in (-.73,.73):
        m.round((1.18,.068,.72),(x,.78,-.14),"cream",.20)
        for xx in (x-.42,x+.42):
            m.tube([(xx,.03,.16),(xx,.70,.10),(xx,.71,-.34),(xx,.03,-.40)],.023,"metal")
        m.round((.90,.03,.45),(x,.53,-.15),"silver",.08)
        chair(m,x,.85)
        book(m,x-.20,.824,-.16); cup(m,x+.32,.824,-.18,.7)
    m.save()

    m=Model("school_science_bench","开放实验台与显微镜")
    m.round((2.40,.08,.86),(0,.94,0),"cream",.20)
    for x in (-1.0,1.0):
        m.tube([(x,.03,.32),(x,.85,.30),(x,.85,-.30),(x,.03,-.32)],.03,"metal")
    m.round((2.20,.045,.52),(0,.25,0),"silver",.10)
    m.lathe([(.16,0),(.23,.07),(.21,.12),(.17,.09),(.10,.02),(0,.02)],(-.67,.99,.02),"silver")
    m.tube([(-.72,.98,-.26),(-.72,1.28,-.26),(-.60,1.31,-.21),(-.52,1.20,-.15)],.018,"metal")
    for x in (-.08,.19,.46):
        m.lathe([(0,0),(.065,0),(.07,.22),(.06,.22),(.054,.015),(0,.015)],(x,.98,0),"glass")
        m.cyl(.053,.08,(x,1.04,0),"sage")
    m.round((.27,.05,.26),(.89,1.01,0),"metal",.08)
    m.tube([(.86,1.04,-.02),(.96,1.36,-.06),(.82,1.48,.04)],.045,"navy")
    m.rod((.82,1.48,.04),(.73,1.56,.15),.038,"silver")
    book(m,.12,.28,0,"blue",1.7); m.save()

    m=Model("hospital_reception_desk","弧形医院接待台")
    # Curved front with a recess, slats and thin shelves; no solid cuboid body.
    for a in np.linspace(math.pi*.12,math.pi*.88,25):
        x=1.30*math.cos(a); z=.68*math.sin(a)-.26
        m.rod((x,.10,z),(x,1.00,z),.027,"blue")
    m.round((2.83,.10,.96),(0,1.04,0),"cream",.43)
    m.round((2.67,.08,.81),(0,.12,0),"navy",.38)
    m.round((2.03,.055,.58),(0,.57,-.09),"white",.20)
    monitor(m,-.51,1.10,-.10); plant(m,.98,1.095,-.07,.48)
    for x in (.18,.41,.64): book(m,x,1.095,.11,"blue")
    m.round((.30,.07,.026),(0,.63,.445),"white",.025,2)
    m.round((.07,.30,.026),(0,.63,.445),"white",.025,2)
    m.save()

    m=Model("hospital_exam_bay","软垫诊疗床与折叠屏风")
    for x in (-.38,.38):
        for z in (-.71,.71): wheel(m,x,z); m.rod((x,.21,z),(x,.64,z),.035,"silver")
    m.round((1.0,.10,1.96),(0,.69,0),"metal",.24)
    m.ball((.46,.105,.83),(0,.81,.02),"white",True)
    m.ball((.37,.07,.20),(0,.925,-.63),"cream",True)
    for x in (-.49,.49):
        m.tube([(x,.71,-.63),(x,.92,-.60),(x,.92,.46),(x,.71,.53)],.022,"silver")
    m.tube([(.70,.05,-.72),(.70,1.62,-.72),(.47,1.78,-.50),(.28,1.68,-.30)],.027,"metal")
    m.ball((.15,.065,.14),(.28,1.64,-.30),"cream")
    for x in (.87,1.47):
        m.rod((x,.05,.32),(x,1.64,.32),.025,"silver")
    m.rod((.87,1.64,.32),(1.47,1.64,.32),.022,"silver")
    for i in range(7): m.ball((.055,.64,.025),(.91+i*.08,.94,.33),"sage",True)
    m.save()

    m=Model("hospital_medicine_cart","圆角抽屉药品推车")
    for x in (-.32,.32):
        for z in (-.23,.23): wheel(m,x,z); m.rod((x,.21,z),(x,1.02,z),.025,"silver")
    for row in range(3):
        y=.37+row*.19
        m.round((.70,.16,.48),(0,y,0),"white",.075)
        m.tube([(-.12,y,.25),(-.12,y,.29),(.12,y,.29),(.12,y,.25)],.015,"metal")
    m.round((.82,.05,.61),(0,.96,0),"silver",.12)
    m.tube([(-.38,.96,-.25),(-.49,1.13,-.25),(-.49,1.13,.22),(-.38,.96,.22)],.022,"metal")
    for x in (-.23,.0):
        m.cyl(.066,.18,(x,1.08,-.08),"cream"); m.cyl(.067,.035,(x,1.185,-.08),"blue")
    m.round((.22,.045,.20),(.24,1.015,0),"white",.04); m.save()

def extra_models():
    m=Model("sculpted_planter","扇叶陶盆绿植"); plant(m,0,.01,0,1.65); m.save()
    m=Model("hydrangea_pot","蓝粉绣球花盆"); plant(m,0,.01,0,1.25,True); m.save()

    m=Model("curved_bench","弧背条板长椅")
    for x in (-.75,.75):
        m.tube([(x,.03,.30),(x,.44,.23),(x,.44,-.22),(x,.03,-.30)],.045,"metal")
        m.tube([(x,.46,-.24),(x,.89,-.34),(x,1.03,-.26)],.031,"metal")
    for z in (-.21,-.07,.07,.21): m.round((1.95,.055,.115),(0,.48,z),"wood",.045)
    for y in (.70,.83,.96): m.round((1.94,.10,.056),(0,y,-.30),"wood",.042,2)
    m.save()
    m=Model("lounge_chair","曲面软垫休闲椅")
    m.ball((.43,.14,.39),(0,.46,0),"sage",True)
    m.ball((.42,.40,.14),(0,.76,-.28),"blue",True)
    for x in (-.36,.36):
        m.ball((.085,.12,.35),(x,.61,.02),"sage",True)
        for z in (-.24,.25): m.rod((x*.78,.025,z),(x*.88,.40,z*.8),.032,"wood")
    m.save()
    m=Model("floor_lamp","弧杆落地灯")
    m.cyl(.27,.055,(0,.04,0),"metal")
    m.tube([(0,.06,0),(0,1.40,0),(.06,1.67,.0),(.23,1.85,0),(.49,1.86,0),(.61,1.68,0)],.023,"metal")
    m.lathe([(.23,0),(.19,.19),(.06,.28),(0,.28)],(.61,1.43,0),"cream"); m.save()
    m=Model("waste_bin","圆口金属垃圾桶")
    m.lathe([(0,0),(.18,0),(.23,.56),(.245,.60),(.21,.60),(.19,.10),(0,.10)],(0,.015,0),"silver")
    m.ring(.225,.021,(0,.63,0),"metal"); m.cyl(.17,.014,(0,.13,0),"soil"); m.save()
    m=Model("notice_easel","圆角公告展示架")
    for x in (-.56,.56):
        m.tube([(x,.025,.28),(x,1.90,0),(x,.025,-.28)],.032,"metal")
    m.round((1.37,1.16,.10),(0,1.28,0),"wood",.14,2)
    m.round((1.24,1.02,.018),(0,1.28,.063),"sage",.09,2)
    for x in (-.37,0,.37):
        m.round((.29,.41,.015),(x,1.32,.083),"cream",.028,2)
        m.ball((.02,.02,.012),(x,1.49,.10),"gold")
        for j in range(3): m.rod((x-.09,1.39-j*.07,.10),(x+.09,1.39-j*.07,.10),.006,"blue")
    m.save()

    m=Model("restaurant_bistro_set","圆桌与曲背餐椅")
    m.cyl(.55,.06,(0,.79,0),"cream"); m.cyl(.045,.68,(0,.43,0),"metal"); m.cyl(.27,.05,(0,.055,0),"metal")
    chair(m,-.90,0,-math.pi/2); chair(m,.90,0,math.pi/2)
    cup(m,-.18,.825,.12); cup(m,.19,.825,-.12); plant(m,0,.825,0,.31); m.save()
    m=Model("restaurant_coffee_station","开放咖啡吧台")
    for x in (-.93,.93):
        for z in (-.29,.29): m.rod((x,.025,z),(x,1.02,z),.033,"metal")
    m.round((2.1,.065,.81),(0,1.04,0),"wood",.24)
    for y in (.22,.62): m.round((1.96,.045,.62),(0,y,0),"cream",.12)
    m.round((.74,.43,.49),(-.39,1.32,-.08),"navy",.12)
    m.round((.62,.045,.21),(-.39,1.15,.21),"silver",.04)
    for x in (-.55,-.24):
        m.rod((x,1.35,.16),(x,1.28,.24),.026,"silver"); cup(m,x,1.175,.23)
    for x in (.35,.70): m.cyl(.10,.22,(x,1.20,0),"cream"); m.cyl(.10,.025,(x,1.325,0),"wood")
    for i in range(5): m.cyl(.15,.015,(.53,.265+i*.02,0),"white")
    m.save()
    m=Model("restaurant_kitchen_island","圆角开放备餐岛台")
    for x in (-1.02,1.02):
        for z in (-.33,.33): m.rod((x,.04,z),(x,.90,z),.03,"metal")
    for y in (.24,.87): m.round((2.32,.07,.91),(0,y,0),"silver",.18)
    m.round((.70,.026,.46),(-.49,.923,0),"wood",.10)
    m.lathe([(0,0),(.21,0),(.31,.12),(.28,.14),(.20,.025),(0,.025)],(.52,.91,0),"cream")
    for x in (-.60,-.40,-.20): m.ball((.07,.055,.07),(x,.995,.0),"orange")
    for x in (-.68,0,.68): m.lathe([(0,0),(.18,0),(.24,.20),(.20,.23),(0,.23)],(x,.28,0),"wood")
    m.save()
    m=Model("restaurant_pantry_shelf","罐装食品开放层架"); shelf(m,1.7,1.75,.54,"pantry"); m.save()
    m=Model("restaurant_dish_station","圆盆洗涤餐具架")
    for x in (-.78,.78):
        for z in (-.29,.29): m.rod((x,.025,z),(x,.93,z),.03,"metal")
    m.round((1.8,.06,.76),(0,.95,0),"silver",.16)
    m.lathe([(.21,0),(.27,.07),(.24,.10),(.17,.03),(0,.03)],(-.37,.986,0),"silver")
    m.tube([(-.39,.96,-.25),(-.39,1.27,-.25),(-.25,1.31,-.12),(-.18,1.17,-.07)],.02,"metal")
    for x in (.23,.39,.55): m.ring(.12,.012,(x,1.13,0),"cream",True)
    m.round((1.58,.045,.54),(0,.27,0),"silver",.10); m.save()
    m=Model("restaurant_pastry_table","圆形蛋糕展示台")
    m.cyl(.53,.06,(0,.90,0),"cream"); m.cyl(.04,.76,(0,.48,0),"metal"); m.cyl(.23,.04,(0,.055,0),"metal")
    for x,z in ((-.22,-.12),(.20,-.16),(0,.22)):
        m.cyl(.15,.025,(x,.95,z),"silver"); m.cyl(.045,.10,(x,1.015,z),"silver")
        m.cyl(.17,.018,(x,1.075,z),"cream"); m.cyl(.115,.10,(x,1.134,z),"pink")
        for a in np.linspace(0,math.tau,6,endpoint=False): m.ball((.028,.025,.028),(x+.08*math.cos(a),1.20,z+.08*math.sin(a)),"cream")
    m.save()
    m=Model("restaurant_menu_stand","弧顶菜单牌")
    m.round((.63,.055,.44),(0,.045,0),"metal",.17)
    for x in (-.20,.20): m.rod((x,.06,0),(x,1.04,0),.022,"gold")
    m.round((.72,.68,.065),(0,1.18,0),"wood",.20,2)
    m.round((.64,.58,.014),(0,1.18,.042),"navy",.17,2)
    for y in (1.00,1.13,1.26): m.rod((-.20,y,.055),(.20,y,.055),.009,"chalk")
    m.save()
    m=Model("restaurant_herb_rack","香草三层花架")
    for x in (-.59,.59): m.tube([(x,.03,.29),(x,1.20,-.29),(x,.03,-.32)],.025,"metal")
    for row in range(3):
        y=.19+row*.30; z=.17-row*.20
        m.round((1.32,.05,.36),(0,y,z),"wood",.07)
        for x in (-.42,0,.42): plant(m,x,y+.03,z,.50)
    m.save()

    m=Model("school_open_bookshelf","弧角开放图书架"); shelf(m,1.80,1.84,.49); m.save()
    m=Model("school_globe","立架蓝色地球仪")
    m.cyl(.26,.06,(0,.045,0),"wood"); m.rod((0,.06,0),(0,.93,0),.029,"metal")
    m.ring(.34,.022,(0,1.23,0),"gold",True); m.ball((.29,.29,.29),(0,1.23,0),"blue")
    for x,y,z in ((-.14,.12,.21),(.1,.11,.24),(.09,-.15,.21),(-.05,-.02,.28)):
        m.ball((.085,.07,.023),(x,1.23+y,z),"sage")
    m.save()
    m=Model("school_telescope","三脚天文望远镜")
    for a in (0,2.1,4.2): m.rod((math.cos(a)*.46,.04,math.sin(a)*.46),(0,1.02,0),.022,"silver")
    m.rod((0,.90,0),(0,1.23,0),.035,"metal")
    m.rod((-.43,1.38,0),(.40,1.13,0),.11,"cream")
    m.rod((-.45,1.385,0),(-.37,1.365,0),.12,"navy")
    m.rod((.39,1.13,0),(.52,1.09,0),.046,"metal"); m.save()
    m=Model("school_artist_easel","木质画架与画布")
    for x in (-.38,.38): m.rod((x,.025,.25),(x*.62,1.67,-.07),.029,"wood")
    m.rod((0,.03,-.45),(0,1.49,-.07),.03,"wood")
    m.round((.86,1.06,.06),(0,1.10,0),"wood",.04,2)
    m.round((.79,.99,.02),(0,1.10,.041),"cream",.02,2)
    m.ball((.19,.13,.015),(-.12,1.20,.06),"blue")
    m.ball((.25,.09,.015),(.08,.88,.06),"sage")
    m.cyl(.06,.01,(.23,1.43,.07),"orange")
    m.round((1.01,.045,.18),(0,.54,.10),"wood",.06); m.save()
    m=Model("school_art_cart","绘画颜料推车")
    for x in (-.37,.37):
        for z in (-.23,.23): wheel(m,x,z); m.rod((x,.20,z),(x,.93,z),.022,"silver")
    for y in (.28,.58,.89): m.round((.88,.05,.58),(0,y,0),"wood",.13)
    for i in range(5):
        x=-.29+i*.145
        m.cyl(.052,.12,(x,.99,.06),["blue","sage","cream","pink","orange"][i])
    m.cyl(.07,.14,(-.24,1.0,-.13),"silver")
    for i in range(5): m.rod((-.24,1.0,-.13),(-.29+i*.022,1.29,-.14+i*.01),.009,"wood")
    book(m,.14,.61,0,"cream",1.6); m.save()
    m=Model("school_lab_stool","圆座三脚实验凳")
    m.ball((.25,.07,.25),(0,.66,0),"blue",True)
    for a in (0,2.1,4.2): m.rod((math.cos(a)*.22,.025,math.sin(a)*.22),(math.cos(a)*.13,.60,math.sin(a)*.13),.024,"metal")
    m.ring(.17,.017,(0,.23,0),"silver"); m.save()
    m=Model("school_projector_cart","投影设备移动架")
    for x in (-.27,.27):
        for z in (-.20,.20): wheel(m,x,z); m.rod((x,.20,z),(x,.92,z),.022,"metal")
    for y in (.30,.86): m.round((.72,.045,.57),(0,y,0),"wood",.12)
    m.round((.46,.17,.36),(0,.98,0),"cream",.09)
    m.rod((.10,.99,.18),(.10,.99,.24),.058,"navy")
    m.rod((.10,.99,.24),(.10,.99,.248),.042,"blue")
    book(m,0,.33,0,"blue",1.7); m.save()
    m=Model("school_storage_cubbies","圆角开放教具格架")
    for x in (-.63,.63): m.rod((x,.025,0),(x,1.31,0),.035,"metal")
    for y in (.13,.66,1.20): m.round((1.43,.05,.50),(0,y,0),"wood",.11)
    for y in (.31,.85):
        for x in (-.45,0,.45):
            m.lathe([(0,0),(.14,0),(.17,.24),(.145,.26),(0,.26)],(x,y-.14,0),"sage" if x==0 else "cream")
    m.save()

    m=Model("hospital_iv_stand","五轮输液架")
    for a in np.linspace(0,math.tau,5,endpoint=False):
        x,z=math.cos(a)*.28,math.sin(a)*.28
        m.rod((0,.14,0),(x,.13,z),.022,"silver"); wheel(m,x,z,.065,.042)
    m.rod((0,.15,0),(0,1.82,0),.022,"silver")
    m.tube([(-.26,1.74,0),(-.26,1.85,0),(.26,1.85,0),(.26,1.74,0)],.017,"metal")
    for x in (-.19,.19):
        m.round((.16,.27,.045),(x,1.58,0),"glass",.055,2)
        m.tube([(x,1.43,0),(x-.07,1.07,.06),(x-.04,.74,.02)],.004,"silver")
    m.save()
    m=Model("hospital_oxygen_trolley","氧气瓶手推架")
    for x in (-.18,.18): wheel(m,x,-.08)
    m.cyl(.14,.04,(0,.22,0),"metal")
    m.lathe([(0,0),(.13,0),(.15,.07),(.15,.72),(.10,.80),(.06,.82),(0,.82)],(0,.24,0),"sage")
    m.rod((0,1.05,0),(0,1.17,0),.029,"silver")
    m.ring(.058,.012,(.04,1.17,0),"metal",True)
    m.tube([(-.18,.16,-.14),(-.18,1.26,-.14),(.18,1.26,-.14),(.18,.16,-.14)],.023,"metal")
    m.save()
    m=Model("hospital_monitor_trolley","监护仪移动架")
    for x in (-.28,.28):
        for z in (-.23,.23): wheel(m,x,z); m.rod((x,.18,z),(x,.82,z),.022,"silver")
    for y in (.31,.82): m.round((.72,.045,.58),(0,y,0),"white",.12)
    monitor(m,0,.85,0); m.save()
    m=Model("hospital_privacy_screen","三折软帘屏风")
    for i in range(3):
        x=(i-1)*.59; z=.1 if i%2 else 0
        for xx in (x-.275,x+.275):
            m.rod((xx,.05,z),(xx,1.73,z),.022,"silver")
            m.rod((xx,.07,z-.18),(xx,.07,z+.18),.022,"metal")
        m.rod((x-.28,1.73,z),(x+.28,1.73,z),.022,"silver")
        for j in range(7): m.ball((.049,.69,.022),(x-.24+j*.08,.98,z+.008),"sage",True)
    m.save()
    m=Model("hospital_sanitizer_stand","洗手消毒立架")
    m.round((.48,.05,.40),(0,.04,0),"metal",.17); m.rod((0,.06,0),(0,1.32,0),.03,"silver")
    m.round((.27,.34,.12),(0,1.19,.035),"white",.05,2)
    m.round((.17,.09,.07),(0,1.32,.12),"blue",.025)
    m.round((.30,.03,.23),(0,.94,.085),"silver",.08)
    m.round((.32,.18,.04),(0,1.52,0),"navy",.07,2)
    m.save()
    m=Model("hospital_waiting_seats","三座弧背候诊椅")
    for x in (-.64,0,.64):
        m.ball((.30,.075,.27),(x,.49,0),"blue",True)
        m.ball((.29,.25,.065),(x,.75,-.23),"sage",True)
    m.rod((-.98,.37,0),(.98,.37,0),.035,"metal")
    for x in (-.74,.74):
        m.tube([(x,.025,.24),(x,.36,0),(x,.025,-.27)],.033,"silver")
    m.save()
    m=Model("hospital_scanner","环形影像检查设备")
    m.round((1.55,.20,.70),(0,.14,-.39),"metal",.25)
    m.ring(.60,.20,(0,1.04,-.37),"white",True)
    m.ring(.54,.035,(0,1.04,-.13),"blue",True)
    m.round((.52,.12,1.83),(0,.60,.36),"silver",.20)
    m.ball((.245,.06,.81),(0,.70,.36),"cream",True)
    for z in (.08,1.01): m.rod((0,.07,z),(0,.54,z),.08,"silver")
    m.save()
    m=Model("hospital_supply_shelf","开放护理用品层架"); shelf(m,1.55,1.75,.49,"medical"); m.save()

def public_models():
    m=Model("mailbox_bank","双面圆角住户信箱")
    for x in (-.65,.65):
        m.tube([(x,.035,.20),(x,1.76,.04),(x,.035,-.20)],.032,"metal")
    m.round((1.84,.11,.30),(0,1.80,0),"wood",.10)
    for row in range(3):
        for col in range(3):
            x=(col-1)*.55;y=.59+row*.39
            m.round((.51,.35,.24),(x,y,0),"sage" if row%2 else "cream",.09,2)
            for side in (-1,1):
                m.round((.31,.018,.012),(x,y+.052,side*.127),"metal",.005)
                m.ball((.028,.028,.012),(x+.16,y-.075,side*.131),"silver")
    m.save()
    m=Model("parcel_station","圆角开放包裹收纳架")
    shelf(m,1.73,1.75,.54,"pantry")
    for y in (.23,.78,1.34):
        m.round((1.60,.26,.032),(0,y+.16,.295),"blue",.10,2)
        for x in (-.44,0,.44): m.round((.16,.035,.01),(x,y+.17,.32),"cream",.009,2)
    m.save()
    m=Model("recycling_station","三色圆筒分类回收站")
    for x,color in ((-.51,"blue"),(0,"sage"),(.51,"cream")):
        m.lathe([(0,0),(.18,0),(.21,.06),(.21,.69),(.235,.72),(.19,.74),(.17,.63),(0,.63)],(x,.015,0),color)
        m.ring(.21,.022,(x,.75,0),"metal")
        m.round((.17,.09,.016),(x,.49,.214),"white",.024,2)
    m.save()
    m=Model("market_kiosk","弧顶开放街角小铺")
    for x in (-.71,.71):
        for z in (-.30,.30): m.rod((x,.025,z),(x,2.02,z),.031,"metal")
    for y in (.31,.86): m.round((1.68,.06,.81),(0,y,0),"wood",.14)
    # Curved canopy, with alternating thin blue and cream ribs.
    for i in range(10):
        x=-.765+i*.17
        points=[(x,1.88+.23*math.sin(a),-.05+.69*math.cos(a)) for a in np.linspace(.16,math.pi-.16,12)]
        m.tube(points,.072,"blue" if i%2 else "cream")
    for row in range(3):
        y=.48+row*.34
        m.round((1.50,.045,.29),(0,y,.22),"silver",.06)
        for col in range(5): m.round((.20,.26,.035),(-.55+col*.275,y+.15,.13),"sage" if col%2 else "cream",.028,2)
    plant(m,-.58,.90,-.18,.44);m.save()
    m=Model("bus_shelter","弧顶玻璃候车亭")
    for x in (-1.20,1.20):
        m.tube([(x,.035,-.32),(x,2.08,-.32),(x,2.27,-.15),(x,2.28,.40)],.035,"metal")
    for z in np.linspace(-.42,.54,9):
        y=2.22+.12*math.cos(z*math.pi)
        m.round((2.77,.034,.13),(0,y,z),"blue",.05)
    m.round((2.36,1.63,.025),(0,1.17,-.33),"glass",.15,2)
    for x in (-.76,0,.76):
        m.ball((.33,.065,.24),(x,.51,.04),"cream",True)
        m.ball((.32,.21,.055),(x,.76,-.14),"sage",True)
    for x in (-.94,.94):
        m.tube([(x,.025,.24),(x,.45,.02),(x,.025,-.17)],.028,"metal")
    m.save()
    m=Model("coat_stand","枝杈式衣帽架")
    m.cyl(.26,.055,(0,.04,0),"wood");m.rod((0,.07,0),(0,1.82,0),.029,"wood")
    for i in range(6):
        a=i*math.tau/6; y=1.45+.12*(i%2)
        end=(math.cos(a)*.22,y+.12,math.sin(a)*.22)
        m.rod((0,y,0),end,.018,"metal");m.ball((.034,.034,.034),end,"wood")
    m.ball((.12,.37,.038),(.18,1.14,.04),"blue",True);m.save()
    m=Model("floor_clock","圆盘立式时钟")
    m.round((.46,.06,.38),(0,.04,0),"metal",.15)
    for x in (-.13,.13):m.rod((x,.07,0),(x,1.69,0),.023,"silver")
    m.ring(.30,.035,(0,1.89,0),"navy",True)
    m.rod((0,1.89,-.018),(0,1.89,.018),.281,"cream")
    for i in range(12):
        a=i*math.tau/12;m.ball((.009,.014,.005),(math.sin(a)*.243,1.89+math.cos(a)*.243,.022),"blue")
    m.rod((0,1.89,.031),(.07,2.07,.031),.010,"metal")
    m.rod((0,1.89,.035),(-.17,1.89,.035),.008,"metal");m.save()
    m=Model("fire_extinguisher","消防瓶与支架")
    m.round((.35,.04,.29),(0,.035,0),"metal",.09)
    m.lathe([(0,0),(.09,0),(.12,.06),(.12,.46),(.08,.52),(0,.52)],(0,.065,0),"red")
    m.rod((0,.57,0),(0,.66,0),.022,"metal")
    m.rod((-.03,.66,0),(.10,.66,0),.022,"metal")
    m.tube([(.03,.64,0),(.15,.60,0),(.15,.25,0)],.009,"metal")
    m.round((.09,.17,.010),(0,.34,.125),"cream",.02,2);m.save()
    m=Model("retro_fridge","圆角双门冰箱")
    m.round((.96,1.78,.74),(0,.93,0),"cream",.18,2)
    m.round((.87,.52,.045),(0,1.50,.395),"sage",.09,2)
    m.round((.87,1.13,.045),(0,.645,.395),"white",.11,2)
    for y in (.96,1.52): m.tube([(-.30,y-.10,.428),(-.30,y-.10,.48),(-.30,y+.10,.48),(-.30,y+.10,.428)],.014,"silver")
    for x in (-.33,.33):
        for z in (-.25,.25):m.cyl(.045,.065,(x,.035,z),"metal")
    m.save()
    m=Model("woven_crate","编织收纳篮")
    m.round((.64,.045,.48),(0,.04,0),"wood",.10)
    for side in (-1,1):
        for i in range(8):
            m.rod((-.27+i*.077,.06,side*.21),(-.30+i*.086,.40,side*.23),.012,"wood")
        for y in np.linspace(.08,.38,6): m.rod((-.31,y,side*.23),(.31,y,side*.23),.012,"wood")
        for i in range(6):m.rod((side*.30,.06,-.20+i*.08),(side*.33,.40,-.22+i*.088),.012,"wood")
        m.tube([(side*.33,.35,-.13),(side*.35,.53,-.13),(side*.35,.53,.13),(side*.33,.35,.13)],.014,"metal")
    m.round((.49,.12,.32),(0,.19,0),"sage",.10);m.save()

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    core_models(); extra_models(); public_models()
    assert len(CATALOG)==50 and len({c['id'] for c in CATALOG})==50
    (OUT/"decor_catalog.json").write_text(json.dumps(CATALOG,ensure_ascii=False,indent=2),encoding="utf-8")
    print(f"Built {len(CATALOG)} detailed models with explicit normals and bounds-aligned collision")

if __name__ == "__main__": main()
