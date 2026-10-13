extends Node
## Independent real-time eyelids; never advances or resets a walking frame.
const CACHE_LIMIT:=12
var config: Dictionary={}
var phase:="open"
var waiting:=0.0
var elapsed:=-1.0
var completed:=0
var rng:=RandomNumberGenerator.new()
var refresh: Callable
var textures: Dictionary={}

func configure(settings: Dictionary,on_change: Callable) -> void:
 config=settings;refresh=on_change;rng.randomize()
 waiting=rng.randf_range(config.interval_min,config.interval_max)
 refresh.call()

func _process(delta: float) -> void:advance(delta)

func begin_blink() -> void:
 elapsed=0.0
 _set_phase("half")

func advance(delta: float) -> void:
 if elapsed<0.0:
  waiting-=delta
  if waiting<=0.0:begin_blink()
  return
 elapsed+=delta
 var closing: float=config.closing_time
 var closed: float=config.closed_time
 var opening: float=config.opening_time
 if elapsed<closing:_set_phase("half")
 elif elapsed<closing+closed:_set_phase("closed")
 elif elapsed<closing+closed+opening:_set_phase("half")
 else:
  elapsed=-1.0;completed+=1
  waiting=rng.randf_range(config.interval_min,config.interval_max)
  _set_phase("open")

func _set_phase(value: String) -> void:
 if phase==value:return
 phase=value;refresh.call()

func texture_for(source: Texture2D) -> Texture2D:
 if phase=="open":return source
 var variants: Dictionary=config.variants.get(source.resource_path,{})
 if variants.is_empty():return source # No visible eyes in a rear-facing picture.
 var path: String=variants[phase]
 if not textures.has(path):
  # A few whole-frame variants stay resident, not hundreds of GPU textures.
  if textures.size()>=CACHE_LIMIT:textures.erase(textures.keys()[0])
  textures[path]=ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE)
 return textures[path]
