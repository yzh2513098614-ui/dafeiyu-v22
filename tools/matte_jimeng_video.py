"""Video-frame alpha extraction and lossless integer canvas registration.

No drawing, joints, warping, interpolation, resizing or generated body parts.
Only the connected studio background receives alpha=0. RGB remains source RGB.
"""
from pathlib import Path
import sys, json
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, str(Path(__file__).parent / 'video_runtime'))
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source/jimeng_20261001'
REVIEW = ROOT / '预览/视频八方向_v20'
ASSETS = ROOT / 'assets/character/jimeng_v20'
CANVAS = (1024,1152)
GROUND = (512,1080)
CLIPS = {
    'down': (1,25,7), 'down_left': (111,135,119),
    'left': (174,206,176), 'up': (262,286,265),
    'right': (417,443,437), 'down_right': (502,526,510),
}

def video_alpha(rgb):
    """Border-connected near-neutral studio matte; keep white costume islands."""
    a = rgb.astype(np.int16)
    neutral = a.max(axis=2) - a.min(axis=2)
    # The cap's pale lavender outline is light but not studio-neutral. A wide
    # white key leaks through it and erases lace; use a strict background key.
    candidate = (a.min(axis=2) >= 231) & (neutral <= 10)
    seed = np.zeros(candidate.shape, bool)
    seed[0,:] = candidate[0,:]; seed[-1,:] = candidate[-1,:]
    seed[:,0] = candidate[:,0]; seed[:,-1] = candidate[:,-1]
    background = ndi.binary_propagation(seed, mask=candidate)
    # The curl encloses a patch of the same plain studio background above the cap.
    # Detect only flat neutral enclosed holes in the top 17% of the video frame.
    holes, count = ndi.label(candidate & ~background)
    for label,obj in enumerate(ndi.find_objects(holes),start=1):
        if obj is None or obj[0].stop > int(rgb.shape[0]*.17):
            continue
        region = holes[obj]
        mask = region == label
        pixels = rgb[obj][mask]
        extended=(slice(max(0,obj[0].start-1),min(rgb.shape[0],obj[0].stop+1)),
                  slice(max(0,obj[1].start-1),min(rgb.shape[1],obj[1].stop+1)))
        local=holes[extended]==label
        ring=ndi.binary_dilation(local)&~local
        border=rgb[extended][ring].astype(np.int16)
        # A true curl hole is enclosed by blue hair. Lace petals are enclosed
        # by lavender/white outlines, even when their fill resembles the studio.
        blue_enclosure=len(border)>0 and np.mean(border[:,2]-border[:,0]>30)>.65
        if blue_enclosure and len(pixels)>80 and pixels.mean(axis=0).min()>232 and pixels.std(axis=0).max()<4:
            background[obj] |= mask
    foreground = ~background
    # Keep the character component; eliminate disconnected caption/compression noise.
    labels, count = ndi.label(foreground)
    sizes = np.bincount(labels.ravel()); sizes[0]=0
    foreground = labels == int(sizes.argmax())
    return foreground.astype(np.uint8)*255

def measurements(rgb, alpha):
    yy,xx=np.where(alpha>0)
    # Skull centre is independent of the large asymmetric tail.
    top=int(yy.min()); cut=(alpha>0).copy()
    cut[:top+90]=False; cut[top+350:]=False
    head_y,head_x=np.where(cut)
    return {'bounds':[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],
            'head_x':float(np.median(head_x)), 'foot_y':int(yy.max()+1)}

def sample(number):
    path=SOURCE/f'frame_{number:04d}.png'
    rgb=np.array(Image.open(path).convert('RGB'))
    alpha=video_alpha(rgb)
    rgba=np.dstack([rgb,alpha])
    out=REVIEW/f'matte_{number:04d}.png'; Image.fromarray(rgba).save(out)
    print(str(out));print(json.dumps(measurements(rgb,alpha)))

def pack_video():
    records = {}; paths = {}; idles = {}
    ASSETS.mkdir(parents=True, exist_ok=True)
    for direction,(start,end,idle_number) in CLIPS.items():
        samples=[]
        for number in range(start,end,2):
            rgb=np.array(Image.open(SOURCE/f'frame_{number:04d}.png').convert('RGB'))
            alpha=video_alpha(rgb); measured=measurements(rgb,alpha)
            samples.append((number,rgb,alpha,measured))
        centre=int(round(np.median([s[3]['head_x'] for s in samples])))
        folder=ASSETS/direction;folder.mkdir(exist_ok=True)
        paths[direction]=[]; records[direction]=[]
        nearest_idle=min(range(len(samples)),key=lambda i:abs(samples[i][0]-idle_number))
        for index,(number,rgb,alpha,measured) in enumerate(samples):
            rgba=np.dstack([rgb,alpha]); x=GROUND[0]-centre; y=GROUND[1]-measured['foot_y']
            out=np.zeros((CANVAS[1],CANVAS[0],4),np.uint8)
            # Whole video frame integer translation: every kept RGB pixel is exact.
            x0=max(0,x); y0=max(0,y); x1=min(CANVAS[0],x+rgb.shape[1]); y1=min(CANVAS[1],y+rgb.shape[0])
            out[y0:y1,x0:x1]=rgba[y0-y:y1-y,x0-x:x1-x]
            original_count=int(np.count_nonzero(alpha))
            if int(np.count_nonzero(out[:,:,3]))!=original_count:raise RuntimeError('Clipped character '+direction)
            destination=folder/f'walk_{index:02d}.png';Image.fromarray(out).save(destination)
            resource='res://'+destination.relative_to(ROOT).as_posix()
            paths[direction].append(resource)
            records[direction].append({'source_frame':number,'source_time':(number-1)/24,
                                       'translation':[x,y],'source_bounds':measured['bounds'],
                                       'foreground_pixels':original_count,'rgb_exact':True})
        idles[direction]=[paths[direction][nearest_idle]]
        print(direction,'frames=',len(samples),'centre=',centre,'native RGB retained')
    metadata={'canvas_size':list(CANVAS),'ground':list(GROUND),'video_fps':24,
              'source_resolution':[834,1112],'clips':{k:list(v) for k,v in CLIPS.items()},
              'frames':paths,'idle':idles,'records':records,
              'matte':'neutral border-connected studio background; main character component',
              'transform':'integer whole-frame translation only; source RGB exact; no resize'}
    (ASSETS/'video_extraction.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')

if __name__=='__main__':
    if '--pack-video' in sys.argv:pack_video()
    else:
        for number in map(int,sys.argv[1:] or [101,281,361,481]):sample(number)
