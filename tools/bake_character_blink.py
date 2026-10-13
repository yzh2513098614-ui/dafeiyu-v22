"""Bake half/closed whole-frame blink variants; only eye-region RGB changes."""
from pathlib import Path
import argparse,json,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFilter

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/video_runtime'))
from scipy import ndimage as ndi
SOURCE=ROOT/'assets/character/download_walk_20261013'
OUT=ROOT/'assets/character/blink_20261013'
REVIEW=ROOT/'预览/眨眼_20261013'
# Original source eye outlines, not a head/body deformation.
EYES={
 'down':[(448,577,(402,538,487,607)),(552,574,(517,535,603,605))],
 'down_right':[(514,582,(475,546,555,608)),(602,583,(574,548,640,608))],
 'right':[(571,589,(532,555,604,617)),(639,596,(617,570,657,624))],
}
MIRRORS={'down_left':'down_right','left':'right'}

def iris_centre(rgb,cx,cy):
    h,w=rgb.shape[:2]
    x0,x1=max(0,cx-22),min(w,cx+23);y0,y1=max(0,cy-24),min(h,cy+25)
    a=rgb[y0:y1,x0:x1].astype(int)
    mask=(a[:,:,1]-a[:,:,0]>22)&(a[:,:,2]-a[:,:,0]>55)&(a[:,:,1]>85)
    labels,_=ndi.label(mask)
    candidates=[]
    for label,box in enumerate(ndi.find_objects(labels),1):
        if box is None:continue
        yy,xx=np.where(labels[box]==label)
        if len(xx)<25:continue
        x=x0+box[1].start+xx.mean();y=y0+box[0].start+yy.mean()
        candidates.append(((x-cx)**2+(y-cy)**2,x,y))
    best=min(candidates)
    return best[1],best[2]

def eye_variant(rgba,eyes,shifts,phase):
    result=rgba.copy()
    for (_,_,box),(dx,dy) in zip(eyes,shifts):
        x0,y0,x1,y1=[int(round(v+(dx if k%2==0 else dy))) for k,v in enumerate(box)]
        width,height=x1-x0,y1-y0
        margin=18
        tile=rgba[y0-margin:y1+margin,x0-margin:x1+margin,:3].astype(float)
        th,tw=tile.shape[:2]
        yy,xx=np.indices((th,tw))
        # A tapered mask follows the eye opening and includes its upper lash.
        polygon=[(.02,.47),(.14,.20),(.36,.03),(.66,.03),(.88,.20),(.99,.47),
                 (.92,.74),(.70,.95),(.33,.97),(.12,.76)]
        eye_mask=Image.new('L',(tw*3,th*3),0)
        draw=ImageDraw.Draw(eye_mask)
        draw.polygon([((margin+x*width)*3,(margin+y*height)*3) for x,y in polygon],fill=255)
        eye_mask=eye_mask.resize((tw,th),Image.Resampling.LANCZOS)
        full_mask=np.asarray(eye_mask,dtype=float)/255
        skin=(tile[:,:,0]>235)&(tile[:,:,1]>155)&(tile[:,:,0]-tile[:,:,1]>12)&(tile[:,:,0]-tile[:,:,2]>15)&(tile[:,:,2]<tile[:,:,1]+6)&(full_mask<.01)
        _,near=ndi.distance_transform_edt(~skin,return_indices=True)
        fill=tile[near[0],near[1]]
        fill=np.stack([ndi.gaussian_filter(fill[:,:,c],8) for c in range(3)],axis=2)
        # Half closure retains the original lower iris and lower outline.
        t=np.clip((xx-margin)/width,0,1)
        arc=(.34+.20*np.sin(t*np.pi)) if phase=='half' else (.39+.34*np.sin(t*np.pi))
        lid_y=margin+arc*height
        blend=full_mask
        if phase=='half':blend=blend*np.clip((lid_y-yy+1)/2,0,1)
        painted=tile*(1-blend[:,:,None])+fill*blend[:,:,None]
        patch=Image.fromarray(np.clip(painted,0,255).astype('uint8')).resize((tw*3,th*3),Image.Resampling.BICUBIC)
        line=ImageDraw.Draw(patch)
        points=[]
        for i in range(65):
            t=.07+.86*i/64
            y=(.34+.20*np.sin(t*np.pi)) if phase=='half' else (.39+.34*np.sin(t*np.pi))
            points.append(((margin+t*width)*3,(margin+y*height)*3))
        line.line(points,fill=(57,38,52),width=max(6,round(width*.045*3)),joint='curve')
        # The outer-corner lashes stay small and keep the drawing's style.
        outer=points[0]
        line.line([outer,(outer[0]-width*.08*3,outer[1]-height*.08*3)],fill=(57,38,52),width=6)
        patch=np.array(patch.resize((tw,th),Image.Resampling.LANCZOS))
        # Commit only the eye mask and eyelid line, never the neighbouring hair.
        line_mask=Image.new('L',(tw*3,th*3),0);ld=ImageDraw.Draw(line_mask)
        ld.line(points,fill=255,width=max(8,round(width*.05*3)),joint='curve')
        ld.line([outer,(outer[0]-width*.08*3,outer[1]-height*.08*3)],fill=255,width=8)
        line_mask=np.array(line_mask.resize((tw,th),Image.Resampling.LANCZOS))>0
        changed=(blend>0)|line_mask
        destination=result[y0-margin:y1+margin,x0-margin:x1+margin,:3]
        destination[changed]=patch[changed]
    assert np.array_equal(result[:,:,3],rgba[:,:,3]),'Blink changed silhouette alpha'
    return result

def bake(samples_only=False):
    OUT.mkdir(parents=True,exist_ok=True);REVIEW.mkdir(parents=True,exist_ok=True)
    config={'interval_min':5.5,'interval_max':8.5,'closing_time':.07,'closed_time':.12,'opening_time':.09,'variants':{}}
    for name,eyes in EYES.items():
        paths=sorted((SOURCE/name).glob('walk_*.png'))
        reference=np.array(Image.open(paths[0]))
        centres=[iris_centre(reference[:,:,:3],cx,cy) for cx,cy,_ in eyes]
        for path in paths[:1] if samples_only else paths:
            rgba=np.array(Image.open(path))
            shifts=[]
            for (cx,cy,_),(rx,ry) in zip(eyes,centres):
                tx,ty=iris_centre(rgba[:,:,:3],cx,cy)
                shifts.append((tx-rx,ty-ry))
            entry={}
            for phase in ['half','closed']:
                folder=OUT/phase/name;folder.mkdir(parents=True,exist_ok=True)
                picture=eye_variant(rgba,eyes,shifts,phase)
                target=folder/path.name;Image.fromarray(picture).save(target)
                entry[phase]='res://'+target.relative_to(ROOT).as_posix()
            config['variants']['res://'+path.relative_to(ROOT).as_posix()]=entry
        print('BLINK_BAKED',name,len(paths[:1] if samples_only else paths),flush=True)
    if not samples_only:
        for target,source in MIRRORS.items():
            for path in sorted((SOURCE/target).glob('walk_*.png')):
                entry={}
                for phase in ['half','closed']:
                    picture=Image.open(OUT/phase/source/path.name).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    folder=OUT/phase/target;folder.mkdir(parents=True,exist_ok=True)
                    destination=folder/path.name;picture.save(destination)
                    entry[phase]='res://'+destination.relative_to(ROOT).as_posix()
                config['variants']['res://'+path.relative_to(ROOT).as_posix()]=entry
        (OUT/'blink.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    preview()

def preview():
    board=Image.new('RGB',(1200,780),'#b6cece');draw=ImageDraw.Draw(board)
    for row,name in enumerate(EYES):
        for col,phase in enumerate(['open','half','closed']):
            path=(SOURCE/name if phase=='open' else OUT/phase/name)/'walk_00.png'
            im=Image.open(path).crop((375,495,725,690)).resize((400,223))
            x,y=col*400,row*260;board.paste(im,(x,y+25),im)
            draw.text((x+15,y+5),name+' '+phase,fill='#192b3b')
    board.save(REVIEW/'01_blink_eye_review.png')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--samples-only',action='store_true')
    parser.add_argument('--install-only',action='store_true')
    args=parser.parse_args()
    if not args.install_only:bake(args.samples_only)
    if args.install_only:
        path=ROOT/'assets/character/manifest.json'
        manifest=json.loads(path.read_text(encoding='utf-8'))
        manifest['blink_config']='res://assets/character/blink_20261013/blink.json'
        path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
        print('NATURAL BLINK INSTALLED')
