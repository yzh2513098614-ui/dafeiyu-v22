extends RefCounted
## Pure spatial rules. No nodes, animation timing or physics side effects.
var side := 8
var blocked: Array = []
var cover: Array = []
var escape_cells: Array = []
var blocked_edges: Array = []

func _init(walls: Array = [], shelters: Array = []) -> void:
	blocked = walls.duplicate(true)
	cover = shelters.duplicate(true)

static func cell(value: Variant) -> Vector2i:
	if value is Vector2i: return value
	return Vector2i(int(value[0]), int(value[1]))

static func packed(value: Vector2i) -> Array:
	return [value.x, value.y]

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < side and p.y < side

func walkable(p: Vector2i) -> bool:
	return inside(p) and not packed(p) in blocked

func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x) + absi(a.y-b.y)

static func edge(a: Vector2i,b: Vector2i) -> Array:
	return [packed(a),packed(b)] if a.y*8+a.x<b.y*8+b.x else [packed(b),packed(a)]

func can_step(a: Vector2i,b: Vector2i) -> bool:
	return walkable(a) and walkable(b) and distance(a,b)==1 and not edge(a,b) in blocked_edges

func path(a: Vector2i, b: Vector2i, maximum: int, occupied: Array = []) -> Array:
	if not walkable(b): return []
	var queue: Array = [a]
	var parents: Dictionary = {a:a}
	var depths: Dictionary = {a:0}
	var cursor := 0
	while cursor < queue.size():
		var at: Vector2i = queue[cursor]; cursor += 1
		if at == b:
			var result: Array = [b]
			while at != a:
				at = parents[at]; result.push_front(at)
			return result
		if int(depths[at]) >= maximum: continue
		for d in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var next: Vector2i = at+d
			if can_step(at,next) and not parents.has(next) and not next in occupied:
				parents[next]=at; depths[next]=int(depths[at])+1; queue.append(next)
	return []

func sight(a: Vector2i, b: Vector2i) -> bool:
	# Supercover sampling: a line touching a solid corner is blocked as well.
	var delta := Vector2(b-a)
	var steps := maxi(absi(b.x-a.x), absi(b.y-a.y))*8
	var previous: Vector2i=a
	for i in range(1, steps+1):
		var at := Vector2(a)+Vector2(.5,.5)+delta*float(i)/maxi(1,steps)
		var p := Vector2i(floori(at.x),floori(at.y))
		if p != a and p != b and not walkable(p): return false
		if p!=previous:
			if distance(previous,p)==1 and not can_step(previous,p):return false
			if distance(previous,p)==2:
				var x_side:=Vector2i(p.x,previous.y);var y_side:=Vector2i(previous.x,p.y)
				if not can_step(previous,x_side) or not can_step(x_side,p) or not can_step(previous,y_side) or not can_step(y_side,p):return false
		previous=p
	return true

func at_exit(p: Vector2i) -> bool:
	return walkable(p) and (p.x==0 or p.y==0 or p.x==side-1 or p.y==side-1 or packed(p) in escape_cells)
