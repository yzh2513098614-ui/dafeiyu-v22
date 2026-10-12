extends SceneTree
## Bake lighting data only. The original drawing and alpha are never changed.
const OUTPUT="res://assets/character/diagonal_edge_surface_20261012/"
const WIDTH:=12.0
const DIAGONAL:=1.41421356

func _initialize() -> void:
	call_deferred("bake")

func write_import(path: String) -> void:
	if FileAccess.file_exists(path+".import"):
		var existing:=ConfigFile.new()
		existing.load(path+".import")
		existing.set_value("params","compress/mode",0)
		existing.set_value("params","compress/normal_map",0)
		existing.set_value("params","mipmaps/generate",true)
		existing.set_value("params","process/fix_alpha_border",false)
		existing.set_value("params","process/premult_alpha",false)
		existing.set_value("params","detect_3d/compress_to",0)
		existing.save(path+".import")
		return
	var cached: String="res://.godot/imported/"+path.get_file()+"-"+path.md5_text()+".ctex"
	var content: String='[remap]\nimporter="texture"\ntype="CompressedTexture2D"\npath="%s"\n\n[deps]\nsource_file="%s"\ndest_files=["%s"]\n\n[params]\ncompress/mode=0\ncompress/normal_map=0\nmipmaps/generate=true\nprocess/fix_alpha_border=false\nprocess/premult_alpha=false\nprocess/size_limit=0\ndetect_3d/compress_to=0\n'%[cached,path,cached]
	var file:=FileAccess.open(path+".import",FileAccess.WRITE)
	file.store_string(content);file.close()

func bake_map(source: Image) -> Image:
	source=source.duplicate()
	source.resize(512,576,Image.INTERPOLATE_LANCZOS)
	var w:=source.get_width()
	var h:=source.get_height()
	var distance:=PackedFloat32Array()
	distance.resize(w*h)
	for y in h:
		for x in w:
			distance[y*w+x]=10000.0 if source.get_pixel(x,y).a>=.42 and x>0 and y>0 and x<w-1 and y<h-1 else 0.0
	for y in range(1,h-1):
		for x in range(1,w-1):
			var p:=y*w+x
			distance[p]=minf(distance[p],minf(minf(distance[p-1]+1.0,distance[p-w]+1.0),minf(distance[p-w-1]+DIAGONAL,distance[p-w+1]+DIAGONAL)))
	for y in range(h-2,0,-1):
		for x in range(w-2,0,-1):
			var p:=y*w+x
			distance[p]=minf(distance[p],minf(minf(distance[p+1]+1.0,distance[p+w]+1.0),minf(distance[p+w-1]+DIAGONAL,distance[p+w+1]+DIAGONAL)))
	var result:=Image.create(w,h,false,Image.FORMAT_RGBA8)
	result.fill(Color(.5,.5,1.0,0.0))
	for y in range(2,h-2):
		for x in range(2,w-2):
			var p:=y*w+x
			if distance[p]<=0.0 or distance[p]>=WIDTH:continue
			var gradient:=Vector2((distance[p+2]-distance[p-2])*.25,(distance[p+2*w]-distance[p-2*w])*.25)
			var edge:=1.0-smoothstep(0.0,WIDTH,distance[p])
			var normal:=Vector3(-gradient.x*.90*edge,gradient.y*.90*edge,1.0).normalized()
			result.set_pixel(x,y,Color(normal.x*.5+.5,normal.y*.5+.5,normal.z*.5+.5,edge))
	return result

func bake() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var manifest_text:=FileAccess.get_file_as_string("res://assets/character/manifest.json")
	manifest_text=manifest_text.replace("\r\n","\n")
	var manifest: Dictionary=JSON.parse_string(manifest_text)
	var records: Array=[]
	var left_maps: Array=[]
	var right_maps: Array=[]
	for i in manifest.frames_by_state.walk.up_left.size():
		var path: String=manifest.frames_by_state.walk.up_left[i]
		var normal:=bake_map(Image.load_from_file(path))
		var left:=OUTPUT+"up_left_%02d.png"%i
		var right:=OUTPUT+"up_right_%02d.png"%i
		normal.save_png(left)
		normal.flip_x()
		for y in normal.get_height():
			for x in normal.get_width():
				var value:=normal.get_pixel(x,y)
				value.r=1.0-value.r
				normal.set_pixel(x,y,value)
		normal.save_png(right)
		write_import(left);write_import(right)
		left_maps.append(left);right_maps.append(right)
		for direction in ["up_left","up_right"]:
			var original: String=manifest.frames_by_state.walk[direction][i]
			records.append({"path":original,"sha256":FileAccess.get_sha256(original)})
		print("BAKED EDGE SURFACE ",i)
	for direction in ["up_left","up_right"]:
		var profile: Dictionary=manifest.surface_profiles_by_direction[direction]
		profile.edge_surface_maps=left_maps if direction=="up_left" else right_maps
		profile.edge_surface_strength=1.0
		profile.edge_vignette_strength=.24
	# Keep the existing manifest formatting and numeric metadata intact.
	var pattern:=RegEx.new()
	pattern.compile('(?s)("tail_split": \\[.*?\\])(?:,\\s*"edge_surface_maps":.*?"edge_vignette_strength":\\s*[0-9.]+)?')
	var matches:=pattern.search_all(manifest_text)
	for i in range(matches.size()-1,-1,-1):
		var match: RegExMatch=matches[i]
		var paths: Array=left_maps if i==0 else right_maps
		var lines:=PackedStringArray()
		for path in paths:lines.append('        "'+str(path)+'"')
		var replacement: String=match.get_string(1)+',\n      "edge_surface_maps": [\n'+',\n'.join(lines)+'\n      ],\n      "edge_surface_strength": 1.0,\n      "edge_vignette_strength": 0.24'
		manifest_text=manifest_text.substr(0,match.get_start())+replacement+manifest_text.substr(match.get_end())
	var file:=FileAccess.open("res://assets/character/manifest.json",FileAccess.WRITE)
	file.store_string(manifest_text);file.close()
	file=FileAccess.open(OUTPUT+"source_hashes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"  ")+"\n");file.close()
	print("EDGE SURFACE BAKE: 52 maps, 24 source pixels wide, originals preserved")
	quit()
