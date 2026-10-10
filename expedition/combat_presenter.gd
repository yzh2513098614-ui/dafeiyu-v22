extends Node3D
## Only draws cells and replays the simulator's event log.
const Grid=preload("res://expedition/tactical_grid.gd")
const Shadow=preload("res://combat/ground_shadow.gd")
var game
var engine
var origin:=Vector3.ZERO
var enemy_sprite: Sprite3D
var enemy_shadow: MeshInstance3D
var sprites: Dictionary={}
var shadows: Dictionary={}
var badges: Dictionary={}
var cells: Array=[]
var outlines: Array=[]
var executing:=false
var fast:=false
var previous_player:=Vector3.ZERO

func configure(owner_game, simulator, board_origin: Vector3) -> void:
	game=owner_game;engine=simulator;origin=board_origin
	for y in 8:
		for x in 8:
			var tile:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(1.36,1.36);tile.mesh=plane;tile.position=world_position(Vector2i(x,y))+Vector3(0,.055,0)
			var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=Color(.47,.72,.80,.12) if engine.grid.walkable(Vector2i(x,y)) else Color(.40,.47,.53,.12);tile.material_override=mat;tile.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(tile);cells.append(tile)
			var edges: Array=[]
			if engine.grid.walkable(Vector2i(x,y)):
				for spec in [[Vector3(1.42,.012,.025),Vector3(0,0,-.71)],[Vector3(1.42,.012,.025),Vector3(0,0,.71)],[Vector3(.025,.012,1.42),Vector3(-.71,0,0)],[Vector3(.025,.012,1.42),Vector3(.71,0,0)]]:
					var line:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=spec[0];line.mesh=box;line.position=world_position(Vector2i(x,y))+Vector3(0,.070,0)+spec[1]
					var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.albedo_color=Color("a7c76b") if engine.grid.at_exit(Vector2i(x,y)) else Color("5bb0c3");line.material_override=ink;line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(line);edges.append(line)
			outlines.append(edges)
	for id in engine.enemy_ids(false):
		var sprite:=Sprite3D.new();sprite.texture=load(engine.data.enemies[engine.units[id].kind].art);sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.shaded=false;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.3
		var used: Rect2i=sprite.texture.get_image().get_used_rect();sprite.pixel_size=1.55/maxi(1,used.size.y);sprite.position.y=(used.end.y-sprite.texture.get_height()*.5)*sprite.pixel_size+.07
		sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(sprite);sprites[id]=sprite
		shadows[id]=Shadow.attach(self,1.55,.062)
		var badge:=Label3D.new();badge.font=game._game_font();badge.font_size=25;badge.pixel_size=.008;badge.billboard=BaseMaterial3D.BILLBOARD_ENABLED;badge.outline_size=5;badge.modulate=Color("c7e6ed");add_child(badge);badges[id]=badge
	enemy_sprite=sprites.enemy;enemy_shadow=shadows.enemy
	sync_positions()
	previous_player=game.player.position

func _process(delta: float) -> void:
	if not game:return
	var travel: Vector3=game.player.position-previous_player
	if executing:
		if travel.length()>.001:game.facing=game._direction_name(game._character_screen_travel(travel))
		game._advance_character_gait(travel,delta)
	previous_player=game.player.position

func world_position(p: Vector2i) -> Vector3:
	return origin+Vector3(p.x*1.5,0,p.y*1.5)

func pick(point: Vector3) -> Vector2i:
	return Vector2i(roundi((point.x-origin.x)/1.5),roundi((point.z-origin.z)/1.5))

func select(p: Vector2i) -> void:
	for i in cells.size():
		var mat: StandardMaterial3D=cells[i].material_override
		var c:=Vector2i(i%8,i/8)
		mat.albedo_color=Color(.75,.66,.35,.38) if c==p else (Color(.47,.72,.80,.13) if engine.grid.walkable(c) else Color(.4,.47,.53,.10))
		for line in outlines[i]:line.material_override.albedo_color=Color("edc66b") if c==p else (Color("a7c76b") if engine.grid.at_exit(c) else Color("5bb0c3"))

func sync_positions() -> void:
	game.player.position=world_position(Grid.cell(engine.units.player.pos))
	var health: Dictionary={};var shields_now: Dictionary={}
	for id in engine.enemy_ids(false):
		var at: Vector3=world_position(Grid.cell(engine.units[id].pos));sprites[id].position.x=at.x;sprites[id].position.z=at.z
		shadows[id].position.x=at.x;shadows[id].position.z=at.z;badges[id].position=at+Vector3(0,1.9,0)
		health[id]=engine.units[id].hp;shields_now[id]=engine.units[id].shield
	show_health(health,shields_now)

func show_health(health: Dictionary, shields_now: Dictionary) -> void:
	for id in engine.enemy_ids(false):
		var alive: bool=int(health[id])>0
		sprites[id].visible=alive;shadows[id].visible=alive;badges[id].visible=alive
		badges[id].text="%d · %d/%d%s"%[engine.enemy_ids(false).find(id)+1,health[id],engine.units[id].max_hp,"  盾%d"%int(shields_now.get(id,0)) if int(shields_now.get(id,0))>0 else ""]

func select_actor(id: String) -> void:
	select(Grid.cell(engine.units[id].pos))
	for actor in badges:badges[actor].modulate=Color("edc66b") if actor==id else Color("c7e6ed")

func replay(log: Array, on_event: Callable) -> void:
	executing=true
	for tile in cells:tile.visible=false
	for edges in outlines:
		for line in edges:line.visible=false
	var cursor:=0
	while cursor<log.size():
		var event: Dictionary=log[cursor];cursor+=1
		on_event.call(event)
		if event.kind=="move":
			var moves: Array=[event]
			while cursor<log.size() and log[cursor].kind=="move" and log[cursor].slot==event.slot:
				moves.append(log[cursor]);on_event.call(log[cursor]);cursor+=1
			await _move_together(moves)
		elif event.kind in ["attack","shield","scan","jam","health","cache","cleanse","charge"]:
			_effect(event)
			if event.kind=="cache":
				var actor: Node3D=game.player if event.side=="player" else sprites[event.side]
				var at: Vector3=world_position(Grid.cell(event.positions[event.side]));actor.position.x=at.x;actor.position.z=at.z
		if event.kind in ["health","shield","defeated"]:show_health(event.health,event.shields)
		if not fast: await get_tree().create_timer(.13).timeout
	sync_positions();executing=false
	for tile in cells:tile.visible=true
	for edges in outlines:
		for line in edges:line.visible=true

func _move_together(moves: Array) -> void:
	var routes: Dictionary={};var maximum:=0
	for event in moves:
		var actor: Node3D=game.player if event.side=="player" else sprites[event.side]
		var path: Array=engine.grid.path(pick(actor.position),Grid.cell(event.positions[event.side]),2)
		routes[event.side]=path;maximum=maxi(maximum,path.size())
	for step in range(1,maximum):
		var tween:=create_tween();tween.set_parallel()
		for id in routes:
			var actor: Node3D=game.player if id=="player" else sprites[id]
			var path: Array=routes[id]
			var end: Vector3=world_position(path[mini(step,path.size()-1)]);end.y=actor.position.y
			tween.tween_property(actor,"position",end,.01 if fast else .10)
			if id!="player":
				tween.tween_property(shadows[id],"position",Vector3(end.x,.062,end.z),.01 if fast else .10)
				tween.tween_property(badges[id],"position",Vector3(end.x,1.9,end.z),.01 if fast else .10)
		await tween.finished

func _effect(event: Dictionary) -> void:
	var actor_point: Vector3=world_position(Grid.cell(event.positions[event.side]))
	var other:=str(event.get("target_actor",""))
	var point: Vector3=world_position(Grid.cell(event.positions[other])) if event.kind=="attack" else actor_point
	var text:=Label3D.new();text.text="-%d"%event.value if event.kind=="attack" else str(event.note)+("  %d"%event.value if int(event.value)>0 else "");text.font=game._game_font();text.font_size=28;text.billboard=BaseMaterial3D.BILLBOARD_ENABLED;text.no_depth_test=true;text.position=point+Vector3(0,2.35,0);text.modulate=Color("97d0dd") if event.kind in ["shield","scan","cache"] else Color("edb486");add_child(text)
	var tween:=create_tween();tween.set_parallel();tween.tween_property(text,"position:y",3.0,.7);tween.tween_property(text,"modulate:a",0.0,.7);tween.chain().tween_callback(text.queue_free)
	if event.kind in ["shield","scan","jam","cache","cleanse","charge"]:_pulse(point,event.kind)
	if event.kind=="health":
		var sprite: SpriteBase3D=game.avatar if event.side=="player" else sprites[event.side]
		var original: Color=sprite.modulate;sprite.modulate=Color(1.0,.75,.77)
		var flash:=create_tween();flash.tween_property(sprite,"modulate",original,.24)
	if event.kind=="attack":
		var end: Vector3=world_position(Grid.cell(event.positions[other]))+Vector3(0,.7,0)
		var beam:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.09;sphere.height=.18;beam.mesh=sphere;beam.position=actor_point+Vector3(0,.7,0)
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("74bedc") if event.side=="player" else Color("e4ac78");beam.material_override=material;add_child(beam)
		var travel:=create_tween();travel.tween_property(beam,"position",end,.2);travel.tween_callback(beam.queue_free)

func _pulse(point: Vector3, kind: String) -> void:
	var ring:=MeshInstance3D.new();var mesh:=TorusMesh.new();mesh.inner_radius=.51;mesh.outer_radius=.60;mesh.rings=24;mesh.ring_segments=8;ring.mesh=mesh;ring.position=point+Vector3(0,.12,0)
	var color: Color={"shield":Color("8cc4e0"),"scan":Color("80d4be"),"jam":Color("bf97dc"),"cache":Color("9ea7dd"),"cleanse":Color("bbe0b2"),"charge":Color("e4ac78")}.get(kind,Color("8cc4e0"))
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color=color;ring.material_override=mat;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ring)
	var tween:=create_tween();tween.set_parallel();tween.tween_property(ring,"scale",Vector3(2.1,1,2.1),.55);tween.tween_property(mat,"albedo_color:a",0.0,.55);tween.chain().tween_callback(ring.queue_free)
