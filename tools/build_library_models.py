"""Reconstruct every object on the two user-selected reference sheets: 24 GLBs.

Reference pixels remain unchanged. Geometry is authored from their silhouettes,
not produced by putting the artwork on a flat plane. Back sides are inferred.
"""
from pathlib import Path
import json, math
import numpy as np
import trimesh
import build_decor_revamp as base
from collections import deque

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'models'/'library_props'
REF=ROOT/'assets'/'library_model_references'
OUT.mkdir(parents=True,exist_ok=True)
base.OUT=OUT
base.C.update(cream='e0d7bf',navy='29445e',blue='466a88',gold='bca46d',
              leaf='709568',leaf_light='9bab72',leaf_dark='466d54',bark='806751',birch='d4d9ce',
              cherry='c49aaa',cherry_light='ddbac3',water='75b7bf',water_light='b2d2d5',
              autumn='bf884f',autumn_light='d7a15d',autumn_dark='94714f',berry='ab4d58',
              snow='d4e1e4',snow_shadow='9bb8c5',teal='527f86')

class Model(base.Model):
    def add(self,mesh,color,smooth=False,fabric=False):
        valid=mesh.area_faces>1e-12
        if not valid.all():
            mesh.update_faces(valid)
            mesh.remove_unreferenced_vertices()
        if smooth and 'vertex_normals' not in mesh._cache:
            smooth_normals(mesh)
        super().add(mesh,color,smooth,fabric)

    def save(self,reference,trunk=False):
        for mesh in self.scene.geometry.values():
            if 'vertex_normals' not in mesh._cache:smooth_normals(mesh)
        super().save()
        path=OUT/(self.name+'.tscn')
        text=path.read_text(encoding='utf-8').replace('res://models/themed_props/','res://models/library_props/')
        if trunk:
            # Players can walk beneath the canopy; the trunk, not the foliage,
            # is the obstacle. A broad crown must never become an invisible box.
            import re
            text=re.sub(r'size = Vector3\([^)]+\)','size = Vector3(0.55, 2.0, 0.55)',text)
            text=re.sub(r'position = Vector3\([^)]+\)','position = Vector3(0, 1, 0)',text)
        path.write_text(text,encoding='utf-8')
        base.CATALOG[-1].update(reference='res://assets/library_model_references/'+reference,
                                representation='solid_3d',collision='trunk' if trunk else 'bounds')

def smooth_normals(mesh):
    # Explicit normals without scipy's optional sparse matrix dependency.
    vectors=np.cross(mesh.vertices[mesh.faces[:,1]]-mesh.vertices[mesh.faces[:,0]],
                     mesh.vertices[mesh.faces[:,2]]-mesh.vertices[mesh.faces[:,0]])
    normals=np.zeros_like(mesh.vertices)
    for corner in range(3):np.add.at(normals,mesh.faces[:,corner],vectors)
    lengths=np.linalg.norm(normals,axis=1)
    assert np.all(lengths>1e-12)
    mesh.vertex_normals=normals/lengths[:,None]

def orient_mesh(mesh):
    # Orient adjacent triangles consistently, using only the exported topology.
    # Closed connected components additionally get outward winding by volume.
    faces=mesh.faces.copy();edges={};adj=[[] for _ in faces]
    for i,face in enumerate(faces):
        for k in range(3):
            a,b=int(face[k]),int(face[(k+1)%3]);key=(min(a,b),max(a,b))
            edges.setdefault(key,[]).append((i,a<b))
    for owners in edges.values():
        if len(owners)==2:
            (a,da),(b,db)=owners;adj[a].append((b,da==db));adj[b].append((a,da==db))
    seen={};components=[]
    for root in range(len(faces)):
        if root in seen:continue
        queue=deque([root]);seen[root]=False;group=[]
        while queue:
            current=queue.popleft();group.append(current)
            for following,invert in adj[current]:
                if following not in seen:seen[following]=seen[current]^invert;queue.append(following)
        components.append(group)
    for face,flip in seen.items():
        if flip:faces[face]=faces[face][::-1]
    for group in components:
        triangles=mesh.vertices[faces[group]]
        volume=np.einsum('ij,ij->i',triangles[:,0],np.cross(triangles[:,1],triangles[:,2])).sum()/6
        if volume<0:faces[group]=faces[group][:,::-1]
    mesh.faces=faces

def triangulate(points):
    p=np.array(points,float);indices=list(range(len(p)));result=[]
    shoelace=sum(p[i,0]*p[(i+1)%len(p),1]-p[(i+1)%len(p),0]*p[i,1] for i in range(len(p)))
    if shoelace<0:indices.reverse()
    cross=lambda a,b:float(a[0]*b[1]-a[1]*b[0])
    while len(indices)>3:
        found=False
        for k,b in enumerate(indices):
            a=indices[k-1];c=indices[(k+1)%len(indices)]
            if cross(p[b]-p[a],p[c]-p[b])<=1e-10:continue
            inside=False
            for n in indices:
                if n in [a,b,c]:continue
                if all(cross(p[v]-p[u],p[n]-p[u])>=-1e-10 for u,v in [(a,b),(b,c),(c,a)]):inside=True;break
            if not inside:result.append((a,b,c));indices.remove(b);found=True;break
        assert found,'Cannot triangulate profile'
    result.append(tuple(indices));return result

def leaf(m,points,radii,color):
    # Smoothly tapered flipper / fluke. Curved along its spine in all three axes.
    vertices=[];faces=[];rings=12
    for n,(point,width) in enumerate(zip(points,radii)):
        tangent=np.subtract(points[min(n+1,len(points)-1)],points[max(0,n-1)])
        tangent=tangent/np.linalg.norm(tangent)
        cross=np.cross(tangent,[0,0,1.])
        if np.linalg.norm(cross)<.1:cross=np.cross(tangent,[0,1.,0])
        cross/=np.linalg.norm(cross);other=np.cross(tangent,cross)
        for k in range(rings):
            a=k*math.tau/rings
            vertices.append(np.array(point)+cross*width*math.cos(a)+other*width*.28*math.sin(a))
    for n in range(len(points)-1):
        for k in range(rings):
            a=n*rings+k;b=n*rings+(k+1)%rings
            faces.extend(((a,b,b+rings),(a,b+rings,a+rings)))
    for k in range(1,rings-1):
        faces.append((0,k+1,k));last=(len(points)-1)*rings
        faces.append((last,last+k,last+k+1))
    mesh=trimesh.Trimesh(vertices=vertices,faces=faces,process=True)
    orient_mesh(mesh);smooth_normals(mesh);m.add(mesh,color,True)

def whale(m,origin,scale=1,color='navy'):
    x,y,z=origin
    def p(dx,dy,dz):return (x+dx*scale,y+dy*scale,z+dz*scale)
    def ball(size,offset,col):m.ball(tuple(v*scale for v in size),p(*offset),col)
    ball((.78,.45,.40),(-.22,0,0),color)
    ball((.52,.22,.35),(-.37,-.23,.012),'cream' if color=='navy' else 'white')
    leaf(m,[p(.32,-.05,0),p(.70,.02,0),p(.94,.33,0),p(1.02,.59,0)],[.30*scale,.22*scale,.13*scale,.055*scale],color)
    for side in [-1,1]:
        leaf(m,[p(1.0,.50,0),p(1.16,.69,side*.20),p(1.05,.77,side*.47)],
             [.05*scale,.22*scale,.012*scale],color)
        leaf(m,[p(-.03,-.20,side*.29),p(-.18,-.35,side*.43),p(.08,-.39,side*.61)],
             [.10*scale,.16*scale,.012*scale],color)
        ball((.046,.046,.018),(-.64,.02,side*.34),'gold' if color=='navy' else 'navy')
    m.tube([p(-.92,-.18,-.13),p(-.91,-.21,0),p(-.87,-.19,.16)],.012*scale,'navy')

def logo(m,center,size=.22,color='cream'):
    x,y,z=center
    m.ball((size*.72,size*.40,.016),(x-size*.22,y,z),color)
    leaf(m,[(x+size*.19,y,z),(x+size*.65,y+size*.05,z),(x+size*.84,y+size*.33,z)],
         [size*.18,size*.13,size*.025],color)
    for side in [-1,1]:
        leaf(m,[(x+size*.8,y+size*.24,z),(x+size*(.9+side*.13),y+size*.46,z)],
             [size*.07,size*.005],color)

def fountains():
    m=Model('library_whale_fountain','资料库 · 蓝鲸环池喷泉')
    m.lathe([(0,.02),(1.68,.02),(1.78,.14),(1.78,.43),(1.59,.49),
             (1.49,.40),(1.49,.16),(0,.16)],(0,0,0),'cream')
    m.lathe([(1.70,.15),(1.791,.15),(1.791,.30),(1.71,.30)],(0,0,0),'navy')
    m.ring(1.67,.025,(0,.493,0),'gold')
    m.cyl(1.49,.014,(0,.183,0),'water')
    m.lathe([(0,0),(.52,0),(.52,.12),(.35,.16),(.35,.53),(.45,.56),(0,.56)],(0,.17,0),'navy')
    m.ring(.39,.025,(0,.68,0),'gold')
    whale(m,(0,1.02,0),.58)
    for k in range(3):
        a=k*math.tau/3+.4
        points=[]
        for t in np.linspace(0,1,18):
            r=.12+1.13*t
            points.append((math.cos(a)*r,1.28+1.82*t-2.87*t*t,math.sin(a)*r))
        m.tube(points,.028,'water_light')
        for t in [.28,.63,.84]:
            r=.12+1.13*t
            m.ball((.045,.06,.045),(math.cos(a)*r,1.28+1.82*t-2.87*t*t,math.sin(a)*r),'water')
    for k in range(12):
        a=k*math.tau/12
        m.cyl(.022,.10,(math.cos(a)*1.79,.24,math.sin(a)*1.79),'gold')
    logo(m,(0,.28,1.79),.21,'gold')
    m.save('whale_fountain.png')

    m=Model('library_whale_statue','资料库 · 奶白鲸鱼雕塑')
    m.round((1.75,.13,1.22),(0,.065,0),'navy',.16)
    m.round((1.54,.65,1.04),(0,.47,0),'navy',.13)
    m.round((1.77,.09,1.24),(0,.82,0),'gold',.15)
    m.round((1.59,.06,1.08),(0,.90,0),'blue',.14)
    for x in [-.58,.58]:
        m.round((.055,.61,.06),(x,.48,.54),'gold',.01)
    logo(m,(0,.50,.54),.26)
    m.tube([(-.68,1.04,0),(-.35,1.12,.08),(0,1.02,.10),(.35,1.15,.10),(.65,1.07,0)],.07,'water')
    whale(m,(-.04,1.51,0),.68,'cream')
    m.save('whale_statue.png')

    m=Model('library_whale_sign','资料库 · 鲸鱼吊牌路标')
    m.round((.62,.12,.62),(0,.06,0),'navy',.12)
    m.lathe([(.27,0),(.23,.12),(.16,.21),(.13,1.84),(.22,1.94),(0,1.94)],(0,.12,0),'navy')
    for y in [.28,1.90,2.02]:m.ring(.17,.025,(0,y,0),'gold')
    whale(m,(.18,2.27,0),.47)
    m.rod((0,1.65,0),(1.17,1.65,0),.036,'gold')
    for x in [.30,1.07]:m.rod((x,1.65,0),(x,1.43,0),.022,'gold')
    m.round((1.13,.83,.12),(.68,1.04,0),'gold',.11,2)
    m.round((1.04,.73,.13),(.68,1.04,.004),'cream',.09,2)
    for x in [.25,1.11]:
        for y in [.77,1.31]:m.ball((.027,.027,.016),(x,y,.08),'gold')
    m.save('whale_sign.png')

def utilities():
    m=Model('library_water_barrel','资料库 · 蓝金鲸纹水桶')
    m.lathe([(0,.04),(.46,.04),(.54,.18),(.58,.60),(.57,1.04),(.48,1.28),
             (.42,1.28),(.42,1.17),(0,1.17)],(0,0,0),'navy')
    for y,r in [(.23,.555),(.97,.582)]:
        m.lathe([(r-.02,y-.065),(r+.025,y-.065),(r+.025,y+.065),(r-.02,y+.065)],(0,0,0),'gold')
    for k in range(16):
        a=k*math.tau/16
        m.tube([(math.cos(a)*r,y,math.sin(a)*r) for y,r in [(.08,.47),(.30,.554),(.60,.586),(.94,.581),(1.19,.502)]],.009,'blue')
    m.cyl(.43,.045,(0,1.22,0),'blue')
    for z in [-.24,-.12,0,.12,.24]:
        w=math.sqrt(.41**2-z*z)
        m.rod((-w,1.245,z),(w,1.245,z),.010,'navy')
    m.cyl(.09,.05,(.23,1.285,.06),'gold')
    logo(m,(0,.65,.595),.30)
    m.save('water_barrel.png')

    m=Model('library_token_atm','资料库 · 蓝金 Token 终端')
    m.round((1.11,.10,.94),(0,.05,0),'silver',.16)
    m.round((1.02,1.14,.83),(0,.65,0),'navy',.12)
    # Upper case tilts back, reproducing the reference terminal silhouette.
    profile=[(-.41,1.05),(.42,1.05),(.25,1.93),(-.40,1.93)]
    verts=[(x,y,z) for x in [-.51,.51] for z,y in profile]
    faces=[]
    for n in range(4):j=(n+1)%4;faces.extend([(n,j,j+4),(n,j+4,n+4)])
    faces.extend([(0,2,1),(0,3,2),(4,5,6),(4,6,7)])
    mesh=trimesh.Trimesh(vertices=verts,faces=faces,process=True);orient_mesh(mesh);m.add(mesh,'navy')
    for x in [-.46,.46]:m.round((.11,.09,.82),(x,1.96,-.035),'gold',.03)
    angle=-.19
    # Embossed screen face is solid geometry and a faint blue material.
    panel=trimesh.creation.box(extents=(.81,.67,.07))
    panel.apply_transform(trimesh.transformations.rotation_matrix(angle,[1,0,0]));panel.apply_translation((0,1.53,.36));m.add(panel,'silver')
    panel=trimesh.creation.box(extents=(.70,.56,.025))
    panel.apply_transform(trimesh.transformations.rotation_matrix(angle,[1,0,0]));panel.apply_translation((0,1.53,.41));m.add(panel,'water')
    logo(m,(0,1.54,.43),.29,'navy')
    m.round((.73,.22,.095),(0,1.01,.455),'gold',.055,2)
    m.round((.57,.075,.105),(0,1.01,.469),'navy',.025,2)
    m.round((.43,.055,.018),(0,.75,.429),'water',.015,2)
    m.round((.90,.055,.10),(0,.17,.47),'cream',.02)
    m.save('token_atm.png')

def trees():
    for kind,label in [('cherry','粉樱分枝树'),('birch','白桦层簇树')]:
        m=Model('library_tree_'+kind,'资料库 · '+label)
        bark='birch' if kind=='birch' else 'bark'
        m.rod((0,.04,0),(.05,2.65,0),.18 if kind=='cherry' else .12,bark)
        for k in range(5):
            a=k*math.tau/5+.3
            m.tube([(0,.05,0),(math.cos(a)*.30,.10,math.sin(a)*.30),
                    (math.cos(a)*.44,.025,math.sin(a)*.44)],.05,bark)
        for k,(x,y,z) in enumerate([(-.80,2.05,.12),(.70,2.18,-.12),(-.30,2.76,-.32),(.52,2.90,.34),(0,3.38,0)]):
            m.tube([(.04,1.12+.16*k,0),(x*.62,y-.38,z*.64),(x,y,z)],.055 if kind=='cherry' else .038,bark)
            colors=['cherry','cherry_light','pink'] if kind=='cherry' else ['leaf','leaf_light','leaf_dark']
            foliage(m,(x,y,z),(.87,.68,.81),colors,k)
        if kind=='birch':
            for y in np.arange(.27,2.5,.27):
                m.rod((-.125,y,.10),(.03,y+.02,.13),.013,'bark')
        m.save('tree_'+kind+'.png',True)

    m=Model('library_tree_pine','资料库 · 分层针叶松')
    m.rod((0,.025,0),(0,3.8,0),.14,'bark')
    for tier in range(4):
        bottom=.86+tier*.72;radius=1.27-tier*.25;top=bottom+1.14
        verts=[];faces=[];segs=48
        for row in range(6):
            t=row/5
            for k in range(segs):
                a=k*math.tau/segs
                r=max(.015,radius*(1-t)**1.15*(.89+.11*math.cos(a*8)))
                y=bottom+(top-bottom)*t+.12*math.sin(a*8)*(1-t)
                verts.append((math.cos(a)*r,y,math.sin(a)*r))
        for row in range(5):
            for k in range(segs):
                a=row*segs+k;b=row*segs+(k+1)%segs
                faces.extend([(a,b,b+segs),(a,b+segs,a+segs)])
        verts.append((0,bottom+.10,0));center=len(verts)-1
        for k in range(segs):faces.append((center,(k+1)%segs,k))
        mesh=trimesh.Trimesh(vertices=verts,faces=faces,process=True);orient_mesh(mesh)
        m.add(mesh,'leaf_dark' if tier%2==0 else 'leaf')
        for k in range(8):
            a=k*math.tau/8
            leaf(m,[(math.cos(a)*.14,bottom+.30,math.sin(a)*.14),
                    (math.cos(a)*radius*.73,bottom+.08,math.sin(a)*radius*.73),
                    (math.cos(a)*radius,bottom-.02,math.sin(a)*radius)], [.12,.17,.015],'leaf_light')
    m.save('tree_pine.png',True)

def corner_caps(m,w,h,d):
    for x in [-w/2+.07,w/2-.07]:
        for z in [-d/2+.07,d/2-.07]:
            for y in [.12,h-.12]:
                m.round((.25,.23,.25),(x,y,z),'navy',.055)
                m.ball((.035,.035,.014),(x,y,z+(.14 if z>0 else -.14)),'gold')

def cabinet(m,w,h,d,color='navy'):
    # Separate front door, rim, hinges and wheel instead of one featureless cube.
    m.round((w,h,d),(0,h/2,0),color,.11)
    m.round((w+.04,.08,d+.04),(0,.05,0),'gold',.055)
    m.round((w-.10,h-.15,.095),(0,h/2,d/2+.025),'silver',.08,2)
    m.round((w-.20,h-.26,.10),(0,h/2,d/2+.085),'navy' if color!='teal' else 'teal',.065,2)
    for y in [h*.23,h*.65]:
        m.rod((-w*.39,y-.10,d/2+.15),(-w*.39,y+.10,d/2+.15),.045,'gold')
    for x in [-w*.35,w*.35]:
        for y in [.17,h-.17]:m.ball((.03,.03,.02),(x,y,d/2+.15),'gold')
    for x in [-w*.36,w*.36]:
        for z in [-d*.34,d*.34]:m.round((.18,.06,.18),(x,.03,z),'navy',.035)

def town_remaining():
    for kind,label,w,h,d in [('floor','立式转轮保险柜',1.10,1.36,1.01),
                              ('tall','高身电子保险柜',.83,2.00,.84),
                              ('compact','低身组合保险柜',1.64,.92,.95)]:
        m=Model('library_safe_'+kind,'资料库 · '+label)
        cabinet(m,w,h,d,'teal' if kind=='tall' else ('cream' if kind=='compact' else 'navy'))
        if kind=='tall':
            m.round((.34,.67,.06),(0,1.04,d/2+.15),'gold',.045,2)
            m.round((.29,.59,.07),(0,1.04,d/2+.185),'navy',.035,2)
            m.round((.23,.085,.008),(0,1.23,d/2+.225),'water',.012,2)
            for row in range(3):
                for column in range(3):
                    m.round((.047,.046,.017),((column-1)*.073,.91+row*.08,d/2+.23),'cream',.008,2)
            m.rod((0,.59,d/2+.17),(0,.59,d/2+.22),.073,'gold')
            for y in [.43,1.24,1.69]:
                m.round((.13,.15,.13),(-w/2,y,d/2+.04),'navy',.03)
        else:
            wheel_x=0 if kind=='floor' else .38
            r=.24 if kind=='floor' else .17;y=h*.50;front=d/2+.23
            m.ring(r,.027,(wheel_x,y,front),'gold',True)
            for k in range(8):
                a=k*math.tau/8
                m.rod((wheel_x,y,front),(wheel_x+math.cos(a)*r,y+math.sin(a)*r,front),.018,'silver')
            m.rod((wheel_x,y,front-.03),(wheel_x,y,front+.035),.066,'gold')
            for k in range(6):
                a=k*math.tau/6
                m.rod((wheel_x+math.cos(a)*r,y+math.sin(a)*r,front),
                      (wheel_x+math.cos(a)*(r+.09),y+math.sin(a)*(r+.09),front),.026,'gold')
        corner_caps(m,w,h,d)
        logo(m,(-.33,h*.53,d/2+.15),.21) if kind=='compact' else None
        # Side whale medallion: rotate actual relief meshes onto both side faces.
        for side in [-1,1]:
            emblem=Model('side','');logo(emblem,(0,h*.54,0),.23)
            transform=trimesh.transformations.rotation_matrix(side*math.pi/2,[0,1,0]);transform[:3,3]=(side*(w/2+.018),0,0)
            for mesh in emblem.scene.geometry.values():
                mesh=mesh.copy();mesh.apply_transform(transform)
                m.scene.add_geometry(mesh,node_name='Emblem_'+str(len(m.scene.geometry)))
        m.save('safe_'+kind+'.png')

    m=Model('library_bench','资料库 · 蓝金鲸纹长椅')
    for x in [-1.03,1.03]:
        m.round((.23,.08,.68),(x,.04,0),'gold',.055)
        m.tube([(x,.05,-.23),(x,.57,-.24),(x,.61,.24),(x,.05,.26)],.055,'navy')
        m.tube([(x,.56,-.23),(x,.89,-.25),(x,.98,.16),(x,.75,.40)],.045,'cream')
        m.rod((x,.43,-.24),(x,1.08,-.29),.045,'navy')
        m.round((.13,.29,.39),(x,.50,.03),'navy',.035)
    for z in [-.21,0,.21]:m.round((2.18,.065,.185),(0,.56,z),'wood',.022)
    for y in [.75,.95,1.13]:m.round((2.12,.155,.085),(0,y,-.285),'blue',.035,2)
    m.rod((-1.05,.33,-.20),(1.05,.33,-.20),.035,'navy')
    for x in [-1.03,1.03]:
        emblem=Model('side','');logo(emblem,(0,.47,0),.12)
        transform=trimesh.transformations.rotation_matrix(math.pi/2,[0,1,0]);transform[:3,3]=(x+(.08 if x>0 else -.08),0,0)
        for mesh in emblem.scene.geometry.values():
            mesh=mesh.copy();mesh.apply_transform(transform);m.scene.add_geometry(mesh)
    m.save('bench.png')

    m=Model('library_street_lamp','资料库 · 蓝金暖光路灯')
    m.round((.64,.13,.64),(0,.065,0),'navy',.12)
    m.lathe([(.26,0),(.23,.34),(.15,.42),(.11,1.84),(.18,1.92),(0,1.92)],(0,.12,0),'cream')
    for y in [.50,2.01]:m.ring(.15,.035,(0,y,0),'gold')
    m.lathe([(0,0),(.17,0),(.24,.09),(.23,.13),(0,.13)],(0,2.01,0),'gold')
    m.lathe([(.25,0),(.27,.05),(.24,.11),(.19,.13)],(0,2.69,0),'gold')
    m.lathe([(.17,0),(.245,.17),(.25,.45),(.21,.64)],(0,2.14,0),'glass')
    m.ball((.20,.27,.20),(0,2.43,0),'orange')
    for k in range(6):
        a=k*math.tau/6
        m.tube([(math.cos(a)*r,y,math.sin(a)*r) for r,y in [(.20,2.08),(.29,2.51),(.22,2.79)]],.025,'navy')
    m.lathe([(.27,0),(.31,.075),(.22,.13),(.13,.28),(.08,.33),(0,.33)],(0,2.82,0),'navy')
    m.ring(.23,.028,(0,2.96,0),'cream');m.ball((.055,.07,.055),(0,3.19,0),'gold')
    logo(m,(0,.33,.253),.13,'navy');m.save('street_lamp.png')

    m=Model('library_supply_crate','资料库 · 奶白鲸纹补给箱')
    m.round((1.12,.92,.98),(0,.46,0),'cream',.07)
    for x in [-.40,.40]:m.round((.035,.67,.032),(x,.46,.51),'wood',.009)
    for y in [.16,.78]:m.round((.84,.029,.034),(0,y,.514),'wood',.009)
    for x in [-.27,.27]:m.round((.018,.025,.91),(x,.932,0),'wood',.007)
    for side in [-1,1]:
        m.round((.075,.16,.41),(side*.585,.51,0),'navy',.035)
        m.round((.080,.075,.27),(side*.60,.52,0),'silver',.018)
    corner_caps(m,1.12,.92,.98);logo(m,(0,.48,.516),.28,'navy');m.save('supply_crate.png')

    m=Model('library_recycling_bin','资料库 · 蓝金分类回收桶')
    m.round((.97,.12,.82),(0,.06,0),'gold',.10)
    m.round((.87,1.0,.73),(0,.61,0),'navy',.10)
    # Top is truly open between the supports, with a dark interior below.
    for x in [-.38,.38]:m.round((.12,.34,.73),(x,1.18,0),'cream',.035)
    m.round((.91,.065,.75),(0,1.39,0),'navy',.09)
    m.round((.91,.09,.75),(0,1.00,0),'cream',.07)
    for z in [-.30,.30]:m.round((.66,.065,.10),(0,1.07,z),'navy',.03)
    for a in [0,math.tau/3,2*math.tau/3]:
        points=[(-.19,-.15),(.11,-.15),(.11,-.23),(.27,-.09),(.11,.05),(.11,-.025),(-.19,-.025)]
        vertices=[]
        for thickness in [.381,.40]:
            for x,y in points:vertices.append((math.cos(a)*x-math.sin(a)*y,.59+math.sin(a)*x+math.cos(a)*y,thickness))
        faces=[];n=len(points)
        for x,y,z in triangulate(points):faces.extend([(x,z,y),(x+n,y+n,z+n)])
        for k in range(n):j=(k+1)%n;faces.extend([(k,j,j+n),(k,j+n,k+n)])
        mesh=trimesh.Trimesh(vertices=vertices,faces=faces,process=True);orient_mesh(mesh);m.add(mesh,'cream')
    m.save('recycling_bin.png')

def foliage(m,center,radii,colors,seed=0):
    # A coherent scalloped leaf mass with small lobes, not large colored spheres.
    def clump(c,size,color,phase,subdivisions=2):
        mesh=trimesh.creation.icosphere(subdivisions=subdivisions)
        v=mesh.vertices.copy()
        ripple=1+.10*np.sin(v[:,0]*17+phase)*np.cos(v[:,1]*13-phase)*np.sin(v[:,2]*15+.8)
        mesh.vertices=v*ripple[:,None]*np.array(size)+np.array(c)
        m.add(mesh,color)
    clump(center,radii,colors[0],seed*.6)
    for n in range(24):
        a=n*2.39996+seed*.3;y=1-2*(n+.5)/24;r=math.sqrt(1-y*y)
        direction=np.array([r*math.cos(a),y,r*math.sin(a)])
        c=np.array(center)+direction*np.array(radii)*.85
        color=colors[1] if y>.40 and n%2 else (colors[2] if y<-.50 else colors[0])
        size=np.array(radii)*(.22+.045*(n%3))
        clump(c,size,color,n*.7,1)

def broad_tree(kind,label,colors,scale=1):
    m=Model('library_tree_'+kind,'资料库 · '+label)
    m.tube([(0,.10,0),(-.06,1.02,.06),(.05,1.8,0),(.13,2.3,-.06)],.23,'bark')
    for k in range(7):
        a=k*math.tau/7
        m.tube([(0,.10,0),(math.cos(a)*.32,.12,math.sin(a)*.32),(math.cos(a)*.59,.045,math.sin(a)*.59)],.07,'bark')
    centers=[(-.72,2.18,.20),(.73,2.14,.18),(0,2.22,-.65),(-.49,2.88,-.10),(.41,3.02,.09),(0,3.40,.01)]
    for k,center in enumerate(centers):
        x,y,z=center;m.tube([(0,1.25,0),(x*.63,y-.40,z*.7),center],.064,'bark')
        foliage(m,(x*scale,y*scale,z*scale),(.85,.64,.83),colors,k)
    m.save('tree_'+kind+'.png',True)

def nature_remaining():
    broad_tree('oak','阔叶橡树',['leaf','leaf_light','leaf_dark'])
    broad_tree('autumn','金秋阔叶树',['autumn','autumn_light','autumn_dark'])

    m=Model('library_tree_palm','资料库 · 弯干棕榈树')
    trunk=[(0,.06,0),(.04,.8,0),(.13,1.65,.03),(.31,2.48,.06),(.46,3.20,.08)]
    m.tube(trunk,.14,'bark')
    for y in np.arange(.23,3.16,.16):
        t=y/3.2;x=.46*t*t;z=.08*t
        m.ring(.145,.011,(x,y,z),'wood')
    for k in range(9):
        a=k*math.tau/9
        points=[(.46,3.22,.08),(.46+math.cos(a)*.55,3.59,.08+math.sin(a)*.55),
                (.46+math.cos(a)*1.18,3.26,.08+math.sin(a)*1.18),(.46+math.cos(a)*1.50,2.68,.08+math.sin(a)*1.50)]
        leaf(m,points,[.055,.27,.31,.013],'leaf_light' if k%3==0 else 'leaf')
        m.tube(points,.018,'leaf_dark')
    for x in [.25,.51,.70]:m.ball((.12,.15,.12),(x,3.13,.12),'bark')
    m.save('tree_palm.png',True)

    # Snow pine uses the exact layered pine silhouette, covered by real snow caps.
    m=Model('library_tree_snow_pine','资料库 · 积雪针叶松')
    original=trimesh.load(OUT/'library_tree_pine.glb',force='scene')
    for mesh in original.geometry.values():m.scene.add_geometry(mesh.copy())
    for tier in range(4):
        bottom=.86+tier*.72;radius=1.27-tier*.25;verts=[];faces=[];segs=48
        for row in range(6):
            t=.22+row*.155
            for k in range(segs):
                a=k*math.tau/segs;r=radius*(1-t)**1.15*(.92+.09*math.cos(a*8))+.025
                y=bottom+1.14*t+.047+.065*math.sin(a*8)*(1-t)
                verts.append((math.cos(a)*r,y,math.sin(a)*r))
        for row in range(5):
            for k in range(segs):
                a=row*segs+k;b=row*segs+(k+1)%segs;faces.extend([(a,b+segs,b),(a,a+segs,b+segs)])
        mesh=trimesh.Trimesh(vertices=verts,faces=faces,process=True);smooth_normals(mesh);m.add(mesh,'snow',True)
    m.save('tree_snow_pine.png',True)

    m=Model('library_tree_dead','资料库 · 分叉枯树')
    m.tube([(0,.08,0),(-.03,1.03,.05),(.10,2.03,0),(.20,3.25,.04)],.18,'bark')
    branches=[[(0,1.01,0),(-.72,1.73,.10),(-1.02,2.48,.16)],
              [(.05,1.46,0),(.84,1.88,-.12),(1.08,2.61,-.12)],
              [(.09,2.09,0),(-.48,2.67,-.18),(-.55,3.28,-.30)],
              [(.10,2.44,0),(.63,2.96,.21),(.84,3.53,.15)]]
    for points in branches:
        leaf(m,points,[.12,.071,.018],'bark')
        tip=points[1];m.rod(tip,(tip[0]+(.23 if tip[0]>0 else -.23),tip[1]+.37,tip[2]+.23),.035,'bark')
    for k in range(6):
        a=k*math.tau/6;m.rod((0,.13,0),(math.cos(a)*.60,.04,math.sin(a)*.60),.07,'bark')
    m.save('tree_dead.png',True)

    for kind,label in [('bush_berry','红果灌木'),('shrub','层簇绿篱')]:
        m=Model('library_'+kind,'资料库 · '+label)
        for n in range(15):
            a=n*2.4;r=.64*math.sqrt((n+1)/16)
            x=math.cos(a)*r;z=math.sin(a)*r;y=.49+.26*(1-r)
            foliage(m,(x,y,z),(.29,.25,.29),['leaf','leaf_light','leaf_dark'],n)
            if kind=='bush_berry' and n%2==0:
                for dx,dz in [(-.055,0),(.055,0),(0,.07)]:m.ball((.06,.067,.06),(x+dx,y+.26,z+dz),'berry')
        m.rod((0,.01,0),(0,.66,0),.065,'bark')
        m.save('bush_berry.png' if kind=='bush_berry' else 'hedge.png')

    m=Model('library_stump','资料库 · 年轮树桩')
    m.lathe([(0,.04),(.58,.04),(.49,.21),(.40,.74),(.36,.84),(0,.84)],(0,0,0),'bark')
    m.cyl(.355,.015,(0,.847,0),'wood')
    for r in [.10,.19,.28]:m.ring(r,.007,(0,.862,0),'bark')
    for k in range(7):
        a=k*math.tau/7
        m.tube([(math.cos(a)*.35,.70,math.sin(a)*.35),(math.cos(a)*.44,.24,math.sin(a)*.44),(math.cos(a)*.65,.04,math.sin(a)*.65)],.047,'bark')
    m.save('stump.png')

    m=Model('library_fallen_log','资料库 · 苔藓倒木')
    m.rod((-1.01,.38,0),(1.01,.38,0),.36,'bark')
    m.rod((-1.025,.38,0),(-1.01,.38,0),.329,'wood')
    for r in [.09,.19,.28]:
        ring=trimesh.creation.torus(major_radius=r,minor_radius=.006,major_sections=32,minor_sections=8)
        ring.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[0,1,0]));ring.apply_translation((-1.035,.38,0));m.add(ring,'bark')
    for k in range(12):
        a=k*math.tau/12
        m.rod((-.96,.38+math.sin(a)*.362,math.cos(a)*.362),(.96,.38+math.sin(a)*.362,math.cos(a)*.362),.015,'bark')
    for n in range(7):m.ball((.23,.055,.15),(-.64+n*.21,.74,.03+.10*math.sin(n)),'leaf_dark')
    m.save('fallen_log.png')

if __name__=='__main__':
    fountains();utilities();trees();town_remaining();nature_remaining()
    assert len(base.CATALOG)==24
    (OUT/'library_catalog.json').write_text(json.dumps(base.CATALOG,ensure_ascii=False,indent=2),encoding='utf-8')
    print('24 reference-based GLBs:',', '.join(x['id'] for x in base.CATALOG))
