"""Re-matte existing eye pixels from their source frames, retaining registration."""
import argparse
import json

import numpy as np
from PIL import Image

import import_download_walk_videos as walk


def restore(apply=False):
    report_path = walk.OUT/'extraction.json'
    report = json.loads(report_path.read_text(encoding='utf-8'))
    totals = {}
    for direction in ('down', 'down_right', 'right'):
        frames, pixels, restored = 0, 0, 0
        row = report['directions'][direction]
        for index, record in enumerate(row['records']):
            source = walk.RAW/direction/f"source_{record['source_frame']:03d}.png"
            rgb = np.array(Image.open(source).convert('RGB'))
            eyes = walk.iris_protection(rgb, direction)
            boxes = [rec['source_box'] for rec in record['hair_background_holes']]
            if not any(eyes[y0:y1,x0:x1].any() for x0,y0,x1,y1 in boxes): continue
            rgba, metrics = walk.matte(rgb, direction)
            target = walk.OUT/direction/f'walk_{index:02d}.png'
            before = np.array(Image.open(target))
            after = walk.pack(rgba, record['translation'])
            changed = np.any(before!=after, axis=2)
            if not changed.any(): continue
            # A new matte may recover mixed pixels within four pixels of an
            # old highlight hole. No head/body/foot pixel may change.
            protected = walk.ndi.binary_dilation(eyes, iterations=8)
            allowed = walk.pack(np.repeat(protected[:,:,None], 4, axis=2), record['translation'])[:,:,0]
            assert not (changed & ~allowed).any(), f'Non-eye change: {direction} {index}'
            assert np.all(after[:,:,3]>=before[:,:,3]), f'Removed alpha: {direction} {index}'
            frames += 1
            pixels += int(changed.sum())
            restored += int(((after[:,:,3]==255) & (before[:,:,3]<255)).sum())
            if apply:
                Image.fromarray(after).save(target)
                record.update(metrics)
        totals[direction] = {'frames':frames, 'changed_pixels':pixels, 'restored_opaque_pixels':restored}
        print('EYE_HIGHLIGHTS', direction, totals[direction], flush=True)
        if apply and frames:
            row_totals = report['hair_gap_repair']['directions'][direction]
            row_totals['holes'] = sum(len(rec['hair_background_holes']) for rec in row['records'])
            row_totals['removed_source_pixels'] = sum(rec['hair_background_pixels'] for rec in row['records'])
    if apply and any(row['frames'] for row in totals.values()):
        for direction, source in walk.MIRRORS.items():
            if not totals.get(source, {}).get('frames'): continue
            for path in sorted((walk.OUT/source).glob('walk_*.png')):
                Image.open(path).transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(walk.OUT/direction/path.name)
            report['directions'][direction] = dict(report['directions'][source], mirror_of=source)
            report['hair_gap_repair']['directions'][direction] = dict(report['hair_gap_repair']['directions'][source])
        previous = report.get('eye_highlight_repair', {}).get('directions', {})
        accumulated = {direction:{key:value+previous.get(direction, {}).get(key, 0)
                                  for key,value in row.items()} for direction,row in totals.items()}
        report['eye_highlight_repair'] = {'method':'source RGB and opaque iris alpha; small iris components excluded from hair-gap matte', 'directions':accumulated}
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8', newline='\n')
        import bake_character_blink
        bake_character_blink.bake()
    return totals


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    restore(parser.parse_args().apply)
