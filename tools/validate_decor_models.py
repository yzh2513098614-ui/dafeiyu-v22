"""Audit the exported assets, not merely the source recipes."""
from pathlib import Path
import json, re, struct
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"models"/"themed_props"
catalog=json.loads((OUT/"decor_catalog.json").read_text(encoding="utf-8"))
assert len(catalog)==50
meshes=0
for item in catalog:
    raw=(OUT/(item["id"]+".glb")).read_bytes()
    assert raw[:4]==b"glTF"
    json_size=struct.unpack_from("<I",raw,12)[0]
    doc=json.loads(raw[20:20+json_size])
    binary=raw[28+json_size:]
    def array(index):
        acc=doc["accessors"][index]; view=doc["bufferViews"][acc["bufferView"]]
        offset=view.get("byteOffset",0)+acc.get("byteOffset",0)
        assert acc["componentType"]==5126 and acc["type"]=="VEC3"
        return np.ndarray((acc["count"],3),dtype="<f4",buffer=binary,
                          offset=offset,strides=(view.get("byteStride",12),4))
    points=[]
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            pos=array(prim["attributes"]["POSITION"])
            normal=array(prim["attributes"]["NORMAL"])
            assert np.isfinite(pos).all() and np.isfinite(normal).all(),item["id"]
            assert np.allclose(np.linalg.norm(normal,axis=1),1,atol=.001),item["id"]
            points.append(pos); meshes+=1
    points=np.concatenate(points)
    lo=points.min(axis=0); hi=points.max(axis=0)
    assert lo[1]>=-.035 and np.all(hi-lo>.025),item["id"]
    wrapper=(OUT/(item["id"]+".tscn")).read_text(encoding="utf-8")
    collider=np.array([float(v) for v in re.search(r"size = Vector3\(([^)]+)\)",wrapper)[1].split(",")])
    center=np.array([float(v) for v in re.search(r"position = Vector3\(([^)]+)\)",wrapper)[1].split(",")])
    assert np.all(lo>=center-collider/2-.0001) and np.all(hi<=center+collider/2+.0001),item["id"]
    assert all(m["name"].startswith("decor_") for m in doc["materials"])
print(f"PASS 50 exported GLBs, {meshes} meshes: finite geometry, unit normals, grounded bounds, complete colliders")
