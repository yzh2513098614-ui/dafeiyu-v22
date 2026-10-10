"""Technical sprite-sheet extraction, manifest publishing and review rendering."""
from pathlib import Path
import json,sys,subprocess,shutil
import numpy as np
from PIL import Image,ImageDraw
sys.path.insert(0,str(Path(__file__).parent/'video_runtime'))
from scipy import ndimage as ndi
ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/character/jimeng_v20'
SOURCE=ROOT/'art_source/jimeng_20261001/generated'
REVIEW=ROOT/'预览/视频八方向_v20'
ORDER=['down','down_left','left','up_left','up','up_right','right','down_right']
GENERATED_SEQUENCE={'up_left':[0,2,4,2],'up_right':[0,2,4,6]}
GENERATED_SCALE=2.16
GODOT=Path.home()/'Godot/4.6.2/Godot_v4.6.2-stable_win64_console.exe'

def extract_generated():
    config={'directions':{},'transform':'whole image uniform 2.16x scale, then integer translation; original native RGBA saved'}
    for direction in ['up_left','up_right']:
        path=SOURCE/f'{direction}_final.png'
        pixels=np.array(Image.open(path).convert('RGBA'))
        labels,count=ndi.label(pixels[:,:,3]>40)
        sizes=np.bincount(labels.ravel());sizes[0]=0
        ids=[int(n) for n in np.argsort(sizes)[-8:] if sizes[n]>10000]
        if len(ids)!=8:raise RuntimeError(f'{direction}: expected8 separate complete characters, got {len(ids)}')
        boxes=[]
        for n in ids:
            yy,xx=np.where(labels==n);boxes.append((int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1),n))
        # Read two rows left to right; use whole components rather than clipping grid lines.
        boxes.sort(key=lambda b:(0 if (b[1]+b[3])/2<pixels.shape[0]/2 else 1,b[0]))
        config['directions'][direction]=[]
        native_folder=ASSETS/'generated_native'/direction;native_folder.mkdir(parents=True,exist_ok=True)
        for index,(x0,y0,x1,y1,n) in enumerate(boxes):
            margin=2;x0=max(0,x0-margin);y0=max(0,y0-margin);x1=min(pixels.shape[1],x1+margin);y1=min(pixels.shape[0],y1+margin)
            mask=ndi.binary_dilation(labels[y0:y1,x0:x1]==n,iterations=1)
            native=pixels[y0:y1,x0:x1].copy();native[:,:,3]=np.where(mask,native[:,:,3],0)
            yy,xx=np.where(native[:,:,3]>40);top=int(yy.min());bottom=int(yy.max()+1)
            head_mask=(native[:,:,3]>40);head_mask[:top+45]=False;head_mask[top+175:]=False
            hy,hx=np.where(head_mask);head_x=int(round(float(np.median(hx))))
            target=[512-round(head_x*GENERATED_SCALE),1080-round(bottom*GENERATED_SCALE)]
            if target[0]<0 or target[1]<0 or target[0]+round(native.shape[1]*GENERATED_SCALE)>1024:raise RuntimeError('Generated full pose would clip '+direction)
            destination=native_folder/f'pose_{index:02d}.png';Image.fromarray(native).save(destination)
            config['directions'][direction].append({'native_frame':'res://'+destination.relative_to(ROOT).as_posix(),
                'source_sheet':'res://'+path.relative_to(ROOT).as_posix(),'source_rect':[x0,y0,x1-x0,y1-y0],
                'source_size':[pixels.shape[1],pixels.shape[0]],'target':target,'source_scale':GENERATED_SCALE})
        print(direction,'8 complete components extracted; native original RGBA retained')
    (ASSETS/'generated_extraction.json').write_text(json.dumps(config,ensure_ascii=False,indent=2),encoding='utf-8')
    subprocess.run([str(GODOT),'--headless','--path',str(ROOT),'--script','res://tools/pack_jimeng_generated.gd'],check=True)

def publish_manifest():
    video=json.loads((ASSETS/'video_extraction.json').read_text(encoding='utf-8'))
    native_directions=set(video['frames'])
    walk=video['frames'];idle=video['idle']
    for direction in ['up_left','up_right']:
        walk[direction]=[f'res://assets/character/jimeng_v20/{direction}/walk_{n:02d}.png' for n in GENERATED_SEQUENCE[direction]]
        idle[direction]=[walk[direction][1]]
    for direction in ORDER:
        for entry in walk[direction]:
            path=ROOT/entry.removeprefix('res://');im=Image.open(path)
            if im.size!=(1024,1152) or im.mode!='RGBA':raise RuntimeError('Wrong canvas '+entry)
    manifest={'version':5,'method':'video_alpha_complete_png_plus_two_ai_diagonals',
        'frame_size':[1024,1152],'canvas_size':[1024,1152],'ground':[512,1080],
        'pixel_size':.0022,'cycle_distance':1.10,'walk_fps':12,
        'atlas_order':ORDER,'frame_counts':{'walk':12,'idle':1,'interact':1},
        'frames_by_state':{'walk':walk,'idle':idle,'interact':idle},
        'frame_counts_by_direction':{d:len(walk[d]) for d in ORDER},
        'provenance':{d:'video' if d in native_directions else 'AI image generation from video keyframes' for d in ORDER},
        'source_video':'res://art_source/jimeng_20261001/source_video.mp4',
        'video_extraction':'res://assets/character/jimeng_v20/video_extraction.json',
        'generated_extraction':'res://assets/character/jimeng_v20/generated_extraction.json',
        'generated_source_sequences':GENERATED_SEQUENCE,
        'note':'Complete pictures only. No body rig, joints, local warps or mirrored directions. Native video RGB retained. Runtime follows actual movement distance.'}
    original=ROOT/'assets/character/manifest.json';backup=ASSETS/'manifest_before_video_v20.json'
    if not backup.exists():shutil.copy2(original,backup)
    temp=original.with_suffix('.json.tmp');temp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8');temp.replace(original)
    print('Manifest installed',manifest['frame_counts_by_direction'],'total',sum(map(len,walk.values())))

def previews():
    metadata=json.loads((ROOT/'assets/character/manifest.json').read_text(encoding='utf-8'))
    images={d:[Image.open(ROOT/p.removeprefix('res://')).convert('RGBA') for p in metadata['frames_by_state']['walk'][d]] for d in ORDER}
    frames=[]
    for tick in range(48):
        sheet=Image.new('RGB',(1024,648),(54,77,96));draw=ImageDraw.Draw(sheet)
        for n,direction in enumerate(ORDER):
            x=(n%4)*256;y=(n//4)*324
            frame=images[direction][int((tick%24)/24*len(images[direction]))]
            small=frame.resize((256,288),Image.Resampling.LANCZOS)
            sheet.paste(small,(x,y),small);draw.line((x+24,y+270,x+232,y+270),fill=(116,153,163))
            draw.text((x+14,y+297),direction+' | '+str(len(images[direction]))+' frames',fill=(235,235,223))
        frames.append(sheet)
    frames[0].save(REVIEW/'八方向行走循环.gif',save_all=True,append_images=frames[1:],duration=83,loop=0)
    frames[0].save(REVIEW/'八方向素材联系表.png')
    print('Animated full-picture review saved')

if __name__=='__main__':
    extract_generated();publish_manifest()
    subprocess.run([str(GODOT),'--path',str(ROOT),'--script','res://tools/defringe_character.gd','--rendering-method','gl_compatibility'],check=True)
    previews()
