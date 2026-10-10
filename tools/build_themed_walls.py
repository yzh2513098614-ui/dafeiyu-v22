"""Two-sided original v22 low walls: 1.1m body, 20cm thick, 25cm dark cap."""
from pathlib import Path
import json, hashlib
import trimesh
OUT = Path(__file__).resolve().parents[1] / "models" / "themed_walls"
SPECS = [('restaurant_dining', '原墙细拼缝', 'cdd5da', 'bcc8cf', 'panel', 2, 0.98),
 ('restaurant_patisserie', '浅暖灰半墙瓷砖', 'd3d7d8', 'c4c6c2', 'tile', 6, 0.58),
 ('restaurant_bar', '灰木竖条护墙', 'cdd5da', 'a7a59c', 'slat', 12, 0.64),
 ('restaurant_kitchen', '厨房小方砖', 'd5dce0', 'bfcbd1', 'tile', 9, 0.96),
 ('restaurant_pantry', '储藏横向金属板', 'cbd4db', 'a6b6c1', 'horizontal', 4, 0.9),
 ('restaurant_lounge', '卡座窄框嵌板', 'cdd5da', 'b3b7b6', 'frame', 3, 0.61),
 ('school_lobby', '门厅大灰白板', 'cdd5da', 'b9c6ce', 'panel', 3, 0.98),
 ('school_classroom', '教室浅青灰护墙', 'cdd5da', 'b6c8c7', 'wainscot', 3, 0.6),
 ('school_staff', '备课室双横拼板', 'cdd5da', 'bac4c9', 'horizontal', 2, 0.66),
 ('school_library', '图书室细灰木条', 'cdd5da', 'aab1ad', 'slat', 18, 0.55),
 ('school_science', '科学室窄瓷砖', 'd0d9dd', 'bbcbd0', 'tile', 8, 0.72),
 ('school_art', '美术室错缝砖', 'cdd5da', 'bec8c9', 'brick', 5, 0.68),
 ('school_math', '数学室三层拼板', 'cdd5da', 'b4c1ca', 'horizontal', 3, 0.75),
 ('school_language', '语言室方形嵌板', 'cdd5da', 'b6c8c8', 'frame', 4, 0.72),
 ('school_media', '媒体室吸音分格', 'cdd5da', '99aebc', 'acoustic', 10, 0.66),
 ('school_observatory', '天文室深灰护墙', 'cdd5da', '9eaebb', 'wainscot', 4, 0.68),
 ('school_craft', '工艺室细条双横框', 'cdd5da', 'adb5ad', 'slat_rail', 14, 0.68),
 ('school_store', '教具室竖拼板', 'cdd5da', 'b8c4cb', 'panel', 6, 0.83),
 ('hospital_lobby', '医院门厅浅石材', 'd2dce0', 'c1ced5', 'frame', 2, 0.8),
 ('hospital_triage', '分诊室浅青护墙', 'd2dce0', 'b7cdcf', 'wainscot', 5, 0.57),
 ('hospital_consult', '门诊中幅瓷砖', 'd2dce0', 'c0cdd4', 'tile', 5, 0.76),
 ('hospital_pharmacy', '药房错缝墙砖', 'd2dce0', 'c1ced3', 'brick', 6, 0.88),
 ('hospital_imaging', '影像室灰蓝金属板', 'cdd5da', 'a9bcc9', 'panel_rail', 4, 0.85),
 ('hospital_waiting', '候诊室低框护墙', 'd2dce0', 'becbcf', 'frame', 5, 0.54),
 ('hospital_ward', '病房防撞护墙', 'd2dce0', 'bacbd4', 'bumper', 3, 0.62),
 ('hospital_treatment', '治疗室小砖双横线', 'd2dce0', 'c1cfd4', 'tile_rail', 8, 0.87),
 ('hospital_nurse', '护士站横拼护墙', 'd2dce0', 'b4c8cd', 'horizontal', 5, 0.72),
 ('hospital_recovery', '恢复室浅灰木条', 'd2dce0', 'bbc5bf', 'slat', 16, 0.48),
 ('hospital_lab', '检验室大方砖', 'd2dce0', 'beccd3', 'tile', 4, 0.94),
 ('hospital_quiet', '安静区细框嵌板', 'd2dce0', 'b5c0c2', 'frame_rail', 3, 0.73)]
KINDS = [s[0] for s in SPECS]
class Wall:
    def __init__(self):
        self.scene=trimesh.Scene(); self.materials={}; self.count=0
    def box(self,size,center,color,metal=False):
        # Extrude the small original-wall edge bevel along X. Flat normals
        # prevent triangular light wedges; square X ends tile without gaps.
        if min(size) >= .06:
            x,y,z=(s/2 for s in size)
            b=min(.027,min(size)*.18)
            profile=[(-y+b,-z),(y-b,-z),(y,-z+b),(y,z-b),
                     (y-b,z),(-y+b,z),(-y,z-b),(-y,-z+b)]
            vertices=[(side*x,yy,zz) for side in (-1,1) for yy,zz in profile]
            faces=[]
            for i in range(8):
                j=(i+1)%8
                faces.extend(((i,j,j+8),(i,j+8,i+8)))
            for i in range(1,7): faces.extend(((0,i+1,i),(8,8+i,8+i+1)))
            mesh=trimesh.Trimesh(vertices=vertices,faces=faces,process=True)
            trimesh.repair.fix_normals(mesh)
        else:
            mesh=trimesh.creation.box(extents=size)
        mesh.unmerge_vertices()
        mesh.vertex_normals=mesh.face_normals.repeat(3,axis=0)
        mesh.apply_translation(center)
        key=(color,metal)
        if key not in self.materials:
            rgb=tuple(int(color[i:i+2],16) for i in (0,2,4))
            self.materials[key]=trimesh.visual.material.PBRMaterial(
                name=f"wall_{color}_{'metal' if metal else 'matte'}",
                baseColorFactor=(*rgb,255),metallicFactor=.42 if metal else 0,
                roughnessFactor=.36 if metal else .61)
        mesh.visual=trimesh.visual.TextureVisuals(material=self.materials[key])
        self.count+=1
        self.scene.add_geometry(mesh,node_name=f"Part_{self.count:03d}")
    def face(self,x,y,w,h,color,depth=.009):
        for side in (-1,1):
            self.box((w,h,depth),(x,y,side*(.100+depth/2)),color)
def build(spec):
    kind,label,body,accent,style,count,top=spec
    m=Wall()
    m.box((2.7,1.1,.20),(0,.55,0),body)
    m.box((2.7,.075,.25),(0,1.125,0),'455665',True)
    m.box((2.7,.085,.24),(0,.065,0),'8d9eaa',True)
    bottom=.14; h=top-bottom; step=2.7/count
    if style in ('panel','panel_rail'):
        for i in range(1,count): m.face(-1.35+i*step,(bottom+top)/2,.011,h,accent,.005)
    elif style in ('wainscot','bumper'):
        m.face(0,(bottom+top)/2,2.7,h,accent,.008)
        for i in range(1,count): m.face(-1.35+i*step,(bottom+top)/2,.012,h,body,.014)
        m.face(0,top,2.7,.028,'8d9eaa',.016)
    elif style=='horizontal':
        for i in range(count): m.face(0,bottom+(i+.5)*h/count,2.7,h/count-.013,accent,.009)
    elif style.startswith('slat') or style=='acoustic':
        for i in range(count):
            m.face(-1.35+(i+.5)*step,(bottom+top)/2,step*(.65 if style=='acoustic' else .29),h,accent,.015 if style=='acoustic' else .011)
    elif style.startswith('frame'):
        m.face(0,(bottom+top)/2,2.7,h,accent,.006)
        for i in range(count):
            x=-1.35+(i+.5)*step
            for y in (bottom+.035,top-.035): m.face(x,y,step-.07,.018,body,.015)
            for xx in (x-step/2+.035,x+step/2-.035): m.face(xx,(bottom+top)/2,.018,h-.07,body,.015)
    elif style.startswith('tile') or style=='brick':
        rows=max(2,round(h/step)) if style.startswith('tile') else 4
        m.face(0,(bottom+top)/2,2.7,h,accent,.004)
        for row in range(rows):
            offset=step/2 if style=='brick' and row%2 else 0
            for i in range(-1,count+1):
                left=max(-1.35,-1.35+i*step+offset+.006)
                right=min(1.35,-1.35+(i+1)*step+offset-.006)
                if right>left: m.face((left+right)/2,bottom+(row+.5)*h/rows,right-left,h/rows-.012,body,.009)
    if style.endswith('rail'):
        for y in (top,.30): m.face(0,y,2.7,.022,'8d9eaa',.018)
    if style=='bumper': m.face(0,.76,2.7,.066,'a3b7c4',.022)
    return m
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    fingerprints=set(); catalog=[]
    for spec in SPECS:
        kind=spec[0]; m=build(spec); data=m.scene.export(file_type='glb',include_normals=True)
        fingerprints.add(hashlib.sha256(data).hexdigest())
        bounds=m.scene.bounds
        assert abs(bounds[1,1]-1.1625)<1e-6
        assert abs(bounds[1,2]-bounds[0,2]-.25)<1e-6
        assert abs(bounds[1,0]-bounds[0,0]-2.7)<1e-6
        (OUT/f'wall_{kind}.glb').write_bytes(data)
        catalog.append(dict(kind=kind,name=spec[1],style=spec[4],parts=m.count,width=2.7,body_height=1.1,body_depth=.20,cap_depth=.25))
    assert len(fingerprints)==30
    (OUT/'wall_catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
    print('30 unique original-style wall modules; bounds and thickness verified')
if __name__=='__main__': main()
