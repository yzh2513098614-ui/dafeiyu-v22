extends RefCounted
## Nondestructive atlas regions; original generated pixels remain in the project.
const REGIONS := [
 Rect2(24,20,386,565), Rect2(435,20,386,565), Rect2(845,20,386,565),
 Rect2(24,616,386,565), Rect2(435,616,386,565), Rect2(845,616,386,565)
]
static func texture(kind:String)->AtlasTexture:
 var index:int={"damage":0,"block":1,"heal":2,"stamina":2,"cleanse":2,"bind":3,"draw":4,"retrieve":4,"energy":5,"amplify":5}.get(kind,4)
 var result:=AtlasTexture.new()
 result.atlas=load("res://assets/battle/ui_painted_v22/refined_frames.png")
 result.region=REGIONS[index]
 result.filter_clip=true
 return result
