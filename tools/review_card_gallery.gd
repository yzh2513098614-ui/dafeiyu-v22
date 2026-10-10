extends SceneTree
func _initialize()->void: call_deferred("run")
func run()->void:
 root.size=Vector2i(1352,1640)
 root.content_scale_size=Vector2i(1352,1640)
 var back:=ColorRect.new();back.color=Color("eff7f6");back.size=Vector2(1352,1640);root.add_child(back)
 var holder:=Control.new();root.add_child(holder)
 var font:=FontVariation.new();font.base_font=load("res://assets/NotoSansSC.ttf");font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):560.0}
 holder.theme=load("res://battle/battle_skin.gd").theme(font)
 var cards:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json"))
 for i in cards.size():
  var face=load("res://battle/card_face.gd").new();face.configure(cards[i]);face.position=Vector2(20+(i%7)*188,20+(i/7)*268);holder.add_child(face)
 for n in 8: await process_frame
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://预览/卡牌精修_v22/04_全部42张新卡牌.png"))
 print("ALL CARD ART RENDERED: ",cards.size())
 quit()





