"""Measure all opaque animation silhouettes in world metres; never edit artwork."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'assets/character/manifest.json').read_text(encoding='utf-8-sig'))
bands = [[.34, .65], [.65, 1.0], [1.0, 1.35], [1.35, 1.7], [1.7, 2.05], [2.05, 2.45]]
radii = [0.0] * len(bands)
count = 0
for direction in manifest['atlas_order']:
    paths = set(p for state in manifest['frames_by_state'].values() for p in state[direction])
    density = manifest.get('pixel_size_by_direction', {}).get(direction, manifest['pixel_size'])
    warp = manifest.get('proportion_warp_by_direction', {}).get(direction, {})
    for path in paths:
        alpha = np.asarray(Image.open(ROOT / path.removeprefix('res://')).convert('RGBA'))[:, :, 3]
        yy, xx = np.nonzero(alpha >= 64)
        y = yy / alpha.shape[0]
        width = np.ones(y.shape)
        if warp.get('enabled'):
            def smooth(a, b, v):
                t = np.clip((v-a)/(b-a), 0, 1)
                return t*t*(3-2*t)
            head, body, ground = warp['head_end'], warp['body_end'], manifest['ground'][1]/alpha.shape[0]
            width += smooth(head, .585, y)*(1-smooth(.86, .925, y))*(warp['body_width']+warp['skirt_width']*np.exp(-((y-.745)/.085)**2))
            y += warp['body_extension']*(smooth(head, body, y)-1)+warp['leg_extension']*(smooth(body, ground, y)-1)
        height = .056 + (manifest['ground'][1] - y*alpha.shape[0])*density
        radius = np.abs(xx-manifest['ground'][0])*density*width
        for i, (low, high) in enumerate(bands):
            mask = (height >= low-.025) & (height <= high+.025)
            if mask.any(): radii[i] = max(radii[i], float(radius[mask].max()))
        count += 1
profile = {'source_frames': count, 'alpha_threshold': 64, 'margin': .025,
           'bands': [{'bottom': low, 'top': high, 'radius': round(r+.025, 4)} for (low, high), r in zip(bands, radii) if r > 0]}
out = ROOT / 'assets/character/collision_profile.json'
out.write_text(json.dumps(profile, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(profile))
