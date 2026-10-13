"""Extract source walk cycles, connected white-screen matte, and register full frames.

Opaque costume pixels stay unchanged. No synthesized poses, image deformation,
or frame interpolation. Three missing left headings are explicit RGBA mirrors.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/video_runtime'))
from scipy import ndimage as ndi

SOURCE = Path(r'C:\Users\Administrator\Downloads')
RAW = ROOT / 'art_source/download_walk_20261013'
OUT = ROOT / 'assets/character/download_walk_20261013'
REVIEW = ROOT / '预览/下载视频八方向_20261013'
FFMPEG = ROOT / 'tools/video_runtime/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
VIDEOS = {'down': ('01_front', (1112, 834)), 'up': ('02_back', (834, 1112)),
          'right': ('04_right', (1112, 834)),
          'down_right': ('06_front_right', (1112, 834)),
          'up_right': ('08_back_right', (1112, 834))}
MIRRORS = {'left': 'right', 'down_left': 'down_right', 'up_left': 'up_right'}
CANVAS, GROUND, FPS = (1024, 1152), (512, 1080), 24


def decode(name, size):
    result = subprocess.run([str(FFMPEG), '-loglevel', 'error', '-i', str(SOURCE / (name+'.mp4')),
                             '-an', '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1'],
                            capture_output=True, check=True)
    return np.frombuffer(result.stdout, np.uint8).reshape((-1, size[1], size[0], 3))


def choose_loop(frames, stabilize_x=False):
    thumbs = np.stack([np.asarray(Image.fromarray(f).resize((139, 139)), np.float32)/255 for f in frames])
    if stabilize_x:
        for thumb in thumbs:
            head = thumb.min(2) < .65
            head[:20] = False; head[65:] = False
            centre = np.median(np.where(head)[1])
            shift = round(70-centre)
            shifted = np.roll(thumb,shift,axis=1)
            if shift > 0: shifted[:,:shift] = 1
            elif shift < 0: shifted[:,shift:] = 1
            thumb[:] = shifted
    weights = np.ones((139, 139, 1), np.float32)
    weights[104:] = 4
    scores = []
    for start in range(12, min(78, len(frames)-24)):
        for period in range(20, 53):
            end = start+period
            if end+2 >= len(frames)-5:
                continue
            match = np.mean(abs(thumbs[start-1:start+2]-thumbs[end-1:end+2])*weights)
            adjacent = np.mean(abs(thumbs[end-1]-thumbs[start])*weights)
            scores.append({'start': start, 'end_exclusive': end, 'period': period,
                           'score': float(.7*match+.3*adjacent)})
    scores.sort(key=lambda s: s['score'])
    return scores[0], scores[:20]


def matte(rgb):
    colour = rgb.astype(np.int16)
    neutral = colour.max(2)-colour.min(2)
    candidate = (colour.min(2) >= 231) & (neutral <= 12)
    # Floor shadows are neutral lavender and lighter than the dark shoes.
    # Only the bottom studio strip is eligible for this broader shadow key.
    candidate[int(rgb.shape[0]*.90):] |= ((colour.min(2) >= 170) & (neutral <= 38))[int(rgb.shape[0]*.90):]
    seed = np.zeros(candidate.shape, bool)
    seed[0] = candidate[0]; seed[-1] = candidate[-1]
    seed[:, 0] = candidate[:, 0]; seed[:, -1] = candidate[:, -1]
    background = ndi.binary_propagation(seed, mask=candidate)
    labels, _ = ndi.label(~background)
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    silhouette = labels == sizes.argmax()
    yy, xx = np.where(silhouette)
    top, bottom = int(yy.min()), int(yy.max()+1)
    # Empty halo and leg gaps can be enclosed. Protect white costume islands
    # by selecting only flat studio patches above the cap or below the hem.
    holes, _ = ndi.label(candidate & silhouette)
    for label, box in enumerate(ndi.find_objects(holes), 1):
        if box is None:
            continue
        local = holes[box] == label
        pixels = rgb[box][local]
        y0, y1 = box[0].start, box[0].stop
        if local.sum() < 60 or pixels.std(0).max() > 5:
            continue
        margin = (slice(max(0,y0-2),min(rgb.shape[0],y1+2)),
                  slice(max(0,box[1].start-2),min(rgb.shape[1],box[1].stop+2)))
        component = holes[margin] == label
        ring = ndi.binary_dilation(component, iterations=2) & ~component
        edge_colours = colour[margin][ring]
        blue_ring = np.mean(edge_colours[:,2]-edge_colours[:,0]>25) if len(edge_colours) else 0
        halo = y1 < top+(bottom-top)*.12 and blue_ring > .45
        width, height = box[1].stop-box[1].start, y1-y0
        leg_gap = (y0 > top+(bottom-top)*.90 and height > 25 and height > width*1.3
                   and pixels.mean(0).min() > 244 and pixels.std(0).max() < 3)
        if halo or leg_gap:
            silhouette[box][local] = False
    distance = ndi.distance_transform_edt(silhouette)
    clean = silhouette & (distance > 4)
    _, nearest = ndi.distance_transform_edt(~clean, return_indices=True)
    foreground = rgb[nearest[0], nearest[1]].astype(np.float32)
    bg = np.median(np.concatenate([rgb[0],rgb[-1],rgb[:,0],rgb[:,-1]]),axis=0).astype(np.float32)
    axis = foreground-bg
    alpha = silhouette.astype(np.float32)
    edge = silhouette & (distance <= 4)
    fitted = np.clip(np.sum((rgb.astype(np.float32)-bg)*axis,axis=2)
                     /np.maximum(np.sum(axis*axis,axis=2),1),0,1)
    alpha[edge] = fitted[edge]
    alpha[alpha < .03] = 0
    alpha[alpha > .985] = 1
    alpha8 = np.round(alpha*255).astype(np.uint8)
    result = rgb.copy()
    result[edge] = foreground[edge].astype(np.uint8)
    result[alpha8 == 0] = foreground[alpha8 == 0].astype(np.uint8)
    yy, xx = np.where(alpha8 > 127)
    h = int(yy.max()+1-yy.min())
    head = (alpha8 > 127).copy()
    head[:yy.min()+int(h*.17)] = False
    head[yy.min()+int(h*.40):] = False
    head_x = np.where(head)[1]
    return np.dstack([result,alpha8]), {
        'bounds': [int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],
        'head_x': float(np.median(head_x)), 'opaque_rgb_exact': bool(np.array_equal(result[clean],rgb[clean])),
        'foreground_pixels': int((alpha8>0).sum())}


def pack(rgba, translation):
    x,y = translation
    canvas = np.zeros((CANVAS[1],CANVAS[0],4),np.uint8)
    x0,y0 = max(0,x),max(0,y)
    x1,y1 = min(CANVAS[0],x+rgba.shape[1]),min(CANVAS[1],y+rgba.shape[0])
    canvas[y0:y1,x0:x1] = rgba[y0-y:y1-y,x0-x:x1-x]
    assert np.count_nonzero(canvas[:,:,3]) == np.count_nonzero(rgba[:,:,3]), 'Character clipped'
    return canvas


def extract(only_direction=None):
    for folder in [RAW,OUT,REVIEW]: folder.mkdir(parents=True,exist_ok=True)
    (RAW/'.gdignore').touch()
    manifest = json.loads((ROOT/'assets/character/manifest.json').read_text(encoding='utf-8-sig'))
    ref = np.asarray(Image.open(ROOT/manifest['frames_by_state']['walk']['down'][0].removeprefix('res://')))
    y = np.where(ref[:,:,3]>127)[0]
    density = manifest.get('pixel_size_by_direction',{}).get('down',manifest['pixel_size'])
    world_height = (int(y.max()-y.min()+1))*density
    if manifest.get('video_extraction') == 'res://assets/character/download_walk_20261013/extraction.json':
        world_height = json.loads((OUT/'extraction.json').read_text(encoding='utf-8'))['world_height']
    report = {'canvas_size':list(CANVAS),'ground':list(GROUND),'fps':FPS,
              'method':'border-connected white-screen matte; protected white costume; 4px boundary unmix',
              'world_height':world_height,'mirrored_directions':MIRRORS,'directions':{}}
    if only_direction:
        report = json.loads((OUT/'extraction.json').read_text(encoding='utf-8'))
    all_images = {}
    for direction,(name,size) in VIDEOS.items():
        if only_direction and direction != only_direction: continue
        frames = decode(name,size)
        loop,candidates = choose_loop(frames,stabilize_x=direction=='up_right')
        samples = []
        for n in range(loop['start'],loop['end_exclusive']):
            rgba,record = matte(frames[n])
            samples.append((rgba,record))
        centre = int(round(np.median([r['head_x'] for _,r in samples])))
        foot = int(round(np.median([r['bounds'][3] for _,r in samples])))
        translation = (GROUND[0]-centre,GROUND[1]-foot)
        height = float(np.median([r['bounds'][3]-r['bounds'][1] for _,r in samples]))
        # Rear clip walks across the studio. Remove only the measured linear
        # horizontal camera drift by translating the complete image. Vertical
        # bob, foot lift, face, clothing, and every pose stay source pixels.
        drift = 0.0
        if direction == 'up_right':
            drift = float(np.polyfit(np.arange(len(samples)),[r['head_x'] for _,r in samples],1)[0])
        folder = OUT/direction; folder.mkdir(exist_ok=True)
        raw_folder = RAW/direction; raw_folder.mkdir(exist_ok=True)
        pictures = []
        records = []
        for i,(rgba,record) in enumerate(samples):
            registered = (translation[0]-round(drift*(i-(len(samples)-1)/2)),translation[1])
            canvas = pack(rgba,registered)
            Image.fromarray(canvas).save(folder/f'walk_{i:02d}.png')
            number = loop['start']+i
            Image.fromarray(frames[number]).save(raw_folder/f'source_{number:03d}.png')
            pictures.append(canvas)
            records.append({'source_frame':number,'source_time':number/FPS,'translation':list(registered),**record})
        # Select a balanced stance with the two feet nearest the ground row.
        idle = min(range(len(samples)),key=lambda i:abs(samples[i][1]['bounds'][3]-foot))
        row = {'source_file':str(SOURCE/(name+'.mp4')),
               'source_sha256':hashlib.sha256((SOURCE/(name+'.mp4')).read_bytes()).hexdigest(),
               'source_resolution':list(size),'source_frame_count':len(frames),
               'loop':loop,'loop_candidates':candidates,'frame_count':len(pictures),'idle_index':idle,
               'translation':list(translation),'horizontal_drift_px_per_frame':drift,
               'pixel_size':world_height/height,'records':records}
        report['directions'][direction] = row
        all_images[direction] = pictures
        print(direction,json.dumps({k:v for k,v in row.items() if k not in ['records','loop_candidates']},ensure_ascii=True),flush=True)
        del frames
    if only_direction:
        for direction in VIDEOS:
            if direction not in all_images:
                row = report['directions'][direction]
                all_images[direction] = [np.array(Image.open(OUT/direction/f'walk_{i:02d}.png')) for i in range(row['frame_count'])]
    for target,source in MIRRORS.items():
        folder = OUT/target; folder.mkdir(exist_ok=True)
        pictures = [np.ascontiguousarray(image[:,::-1]) for image in all_images[source]]
        for i,picture in enumerate(pictures): Image.fromarray(picture).save(folder/f'walk_{i:02d}.png')
        row = dict(report['directions'][source]); row['mirror_of'] = source
        report['directions'][target] = row
        all_images[target] = pictures
    (OUT/'extraction.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    preview(all_images,report)


def preview(images,report):
    names = ['down','down_right','right','up_right','up','up_left','left','down_left']
    board = Image.new('RGB',(1400,760),'#263649'); draw = ImageDraw.Draw(board)
    gif_frames = []
    for n in range(48):
        tile = Image.new('RGB',(1400,760),'#263649'); labels = ImageDraw.Draw(tile)
        for i,name in enumerate(names):
            pictures = images[name]
            picture = Image.fromarray(pictures[int(n/48*len(pictures))])
            bound = picture.getbbox(); picture = picture.crop((bound[0]-8,bound[1]-8,bound[2]+8,bound[3]+8))
            picture.thumbnail((330,330),Image.Resampling.LANCZOS)
            x,y = (i%4)*350, (i//4)*380
            tile.paste(picture,(x+(350-picture.width)//2,y+18),picture)
            labels.text((x+25,y+350),f'{name}: {len(pictures)} frames'+(' MIRROR' if name in MIRRORS else ''),fill='white')
        if n==0: board=tile
        gif_frames.append(tile)
    board.save(REVIEW/'01_eight_directions.png')
    gif_frames[0].save(REVIEW/'02_eight_directions_walk.gif',save_all=True,append_images=gif_frames[1:],duration=35,loop=0)
    # Four backgrounds reveal residual white and lost costume detail.
    board = Image.new('RGB',(1440,720),'#263649')
    for i,name in enumerate(VIDEOS):
        rgba = Image.fromarray(images[name][0])
        box = rgba.getbbox(); rgba = rgba.crop((box[0]-10,box[1]-10,box[2]+10,box[3]+10))
        rgba.thumbnail((275,320),Image.Resampling.LANCZOS)
        for row,bg in enumerate(['#162130','#55b79d']):
            patch = Image.new('RGB',(288,360),bg)
            patch.paste(rgba,((288-rgba.width)//2,10),rgba)
            ImageDraw.Draw(patch).text((10,335),name,fill='white')
            board.paste(patch,(i*288,row*360))
    board.save(REVIEW/'03_matte_review.png')


def install():
    path = ROOT/'assets/character/manifest.json'
    backup = ROOT/'备份/20261013_下载视频八方向替换前'
    backup.mkdir(parents=True,exist_ok=True)
    if not (backup/'manifest.json').exists(): (backup/'manifest.json').write_bytes(path.read_bytes())
    manifest = json.loads(path.read_text(encoding='utf-8-sig'))
    report = json.loads((OUT/'extraction.json').read_text(encoding='utf-8'))
    for state in ['walk','idle','interact']: manifest['frames_by_state'][state] = {}
    for name,row in report['directions'].items():
        paths = ['res://'+(OUT/name/f'walk_{i:02d}.png').relative_to(ROOT).as_posix() for i in range(row['frame_count'])]
        manifest['frames_by_state']['walk'][name] = paths
        for state in ['idle','interact']: manifest['frames_by_state'][state][name] = [paths[row['idle_index']]]
    manifest['frame_counts_by_direction'] = {k:r['frame_count'] for k,r in report['directions'].items()}
    manifest['pixel_size_by_direction'] = {k:r['pixel_size'] for k,r in report['directions'].items()}
    manifest['walk_fps'] = FPS
    manifest['walk_fps_by_direction'] = {k:FPS for k in report['directions']}
    # Keep the existing distance-driven cadence, including slower side headings.
    manifest['mirrored_directions'] = MIRRORS
    manifest['surface_profiles_by_direction'] = {}
    manifest['proportion_warp_by_direction'] = {}
    manifest['palette_match_by_direction'] = {}
    manifest['provenance'] = {k: ('RGBA horizontal mirror of '+r['mirror_of'] if 'mirror_of' in r else 'user video '+Path(r['source_file']).name) for k,r in report['directions'].items()}
    manifest['video_extraction'] = 'res://assets/character/download_walk_20261013/extraction.json'
    manifest['video_extraction_by_direction'] = {k:manifest['video_extraction'] for k in report['directions']}
    manifest['runtime_matte_baked'] = True
    manifest['version'] += 1
    manifest['method'] = 'download_video_complete_rgba_frames_fixed_registration'
    manifest['note'] = 'Five source videos, three explicitly mirrored directions; complete native frames, fixed ground registration and rear-clip linear horizontal drift correction, no pose synthesis'
    manifest['mask_note'] = 'Offline connected studio matte and boundary colour unmix; opaque costume RGB retained; no runtime key or outline'
    for key in ['baked_source_manifest','border_cleanup','border_cleanup_source_manifest','inner_matte','inner_matte_source_manifest','white_fringe','white_fringe_source_manifest','source_video','generated_extraction']:
        manifest.pop(key,None)
    path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('INSTALLED',sum(manifest['frame_counts_by_direction'].values()),'full RGBA walk frames',flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--install',action='store_true')
    parser.add_argument('--install-only',action='store_true')
    parser.add_argument('--direction',choices=list(VIDEOS))
    args = parser.parse_args()
    if not args.install_only: extract(args.direction)
    if args.install or args.install_only: install()
