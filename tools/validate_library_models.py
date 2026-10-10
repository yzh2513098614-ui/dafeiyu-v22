"""Audit the actual 24 GLBs: normals, bounds, distinct assets and Godot wrappers."""
from pathlib import Path
import json,struct,re
import numpy as np
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'models/library_props'
catalog=json.loads((OUT/'library_catalog.json').read_text(encoding='utf-8'))
assert len(catalog)==24 and len({x['id'] for x in catalog})==24
surfaces=0;triangles=0
for entry in catalog:
    raw=(OUT/(entry['id']+'.glb')).read_bytes();assert raw[:4]==b'glTF'
    length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length]);binary=raw[28+length:]
    def array(index):
        acc=doc['accessors'][index];view=doc['bufferViews'][acc['bufferView']]
        assert acc['componentType']==5126 and acc['type']=='VEC3'
        return np.ndarray((acc['count'],3),dtype='<f4',buffer=binary,offset=view.get('byteOffset',0)+acc.get('byteOffset',0),strides=(view.get('byteStride',12),4))
    points=[]
    for mesh in doc['meshes']:
        for part in mesh['primitives']:
            pos=array(part['attributes']['POSITION']);normal=array(part['attributes']['NORMAL'])
            assert np.isfinite(pos).all() and np.isfinite(normal).all(),entry['id']
            assert np.allclose(np.linalg.norm(normal,axis=1),1,atol=.001),entry['id']
            assert len(pos)>10;points.append(pos);surfaces+=1
            triangles+=doc['accessors'][part['indices']]['count']//3
    points=np.concatenate(points);lo=points.min(axis=0);hi=points.max(axis=0)
    assert lo[1]>=-.035 and np.all(hi-lo>.10),(entry['id'],lo,hi)
    scene=(OUT/(entry['id']+'.tscn')).read_text(encoding='utf-8')
    assert 'res://models/library_props/'+entry['id']+'.glb' in scene
    collider=np.array([float(v) for v in re.search(r'size = Vector3\(([^)]+)\)',scene)[1].split(',')])
    center=np.array([float(v) for v in re.search(r'position = Vector3\(([^)]+)\)',scene)[1].split(',')])
    if entry['collision']=='trunk':
        assert collider[0]<.6 and collider[2]<.6 and center[1]==1
    else:assert np.all(lo>=center-collider/2-.0001) and np.all(hi<=center+collider/2+.0001),entry['id']
    assert not doc.get('images') and not doc.get('textures'),entry['id']+' must be solid geometry, not sprite planes'
    assert all(x['name'].startswith('decor_') for x in doc['materials'])
    assert (ROOT/entry['reference'].removeprefix('res://')).is_file()
    print('PASS',entry['id'],len(doc['meshes']),'surfaces')
print(f'PASS 24 solid GLBs / {surfaces} surfaces / {triangles} triangles; grounded, valid normals and colliders')
