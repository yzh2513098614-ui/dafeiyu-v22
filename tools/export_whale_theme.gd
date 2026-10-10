extends SceneTree
const WhaleSkin = preload("res://ui/whale_skin.gd")
func _initialize() -> void:
 var font := FontVariation.new()
 font.base_font=load("res://assets/NotoSansSC.ttf")
 font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):650.0}
 var result:=ResourceSaver.save(WhaleSkin.theme(font),"res://assets/ui/whale_theme.tres")
 print("WHale UI theme exported: ",result)
 quit(result)
