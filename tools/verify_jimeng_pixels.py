"""Independent exact-pixel and fixed-floor verification of the video deliverables."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
meta=json.loads((ROOT/'assets/character/jimeng_v20/video_extraction.json').read_text(encoding='utf-8'))
report=[]
for direction,entries in meta['records'].items():
    for n,entry in enumerate(entries):
        out=np.array(Image.open(ROOT/meta['frames'][direction][n].removeprefix('res://')).convert('RGBA'))
        source=np.array(Image.open(ROOT/f'art_source/jimeng_20261001/frame_{entry["source_frame"]:04d}.png').convert('RGB'))
        yy,xx=np.where(out[:,:,3]>0);dx,dy=entry['translation']
        exact=np.array_equal(out[yy,xx,:3],source[yy-dy,xx-dx,:])
        retained=len(yy)==entry['foreground_pixels'];ground=int(yy.max()+1)==1080
        if not exact or not retained or not ground:raise RuntimeError(direction+' failed pixel/pivot preservation')
        report.append({'direction':direction,'source_frame':entry['source_frame'],'rgb_exact':True,'retained_pixels':len(yy),'floor_y':1080})
path=ROOT/'assets/character/jimeng_v20/video_pixel_verification.json'
path.write_text(json.dumps({'passed':len(report),'frames':report},indent=2),encoding='utf-8')
print('VIDEO RGB AND FLOOR CHECKS',len(report),'PASSED',len(report),'FAILED 0')
