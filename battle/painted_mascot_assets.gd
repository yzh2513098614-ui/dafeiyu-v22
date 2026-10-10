extends RefCounted
## Keep the generated atlas intact; each illustration keeps its original proportions.
const ATLAS := "res://assets/battle/ui_painted_v22/kit/mascot_and_results.png"
const REGIONS := {
 "healthy": Rect2(100, 8, 642, 612),
 "worried": Rect2(750, 87, 599, 534),
 "win": Rect2(24, 627, 722, 520),
 "lose": Rect2(750, 676, 599, 474),
}
static var _cache: Dictionary = {}
static func illustration(kind: String) -> Texture2D:
 if _cache.has(kind): return _cache[kind]
 if not REGIONS.has(kind): return null
 var texture := AtlasTexture.new()
 texture.atlas = load(ATLAS)
 texture.region = REGIONS[kind]
 texture.filter_clip = true
 _cache[kind] = texture
 return texture
