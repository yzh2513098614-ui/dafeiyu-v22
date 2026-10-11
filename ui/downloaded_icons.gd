extends RefCounted
## User-provided icons. Source filenames and SHA256 are in the asset manifest.
const PATHS: Dictionary={
 "map":"res://assets/ui/downloaded_20261011/map.png",
 "backpack":"res://assets/ui/downloaded_20261011/backpack.png",
 "tasks":"res://assets/ui/downloaded_20261011/tasks.png",
 "chat":"res://assets/ui/downloaded_20261011/chat.png",
 "shop":"res://assets/ui/downloaded_20261011/shop.png",
 "music":"res://assets/ui/downloaded_20261011/music.png",
 "deck":"res://assets/ui/downloaded_20261011/deck.png",
 "settings":"res://assets/ui/downloaded_20261011/settings.png",
 "mail":"res://assets/ui/downloaded_20261011/mail.png",
 "gift":"res://assets/ui/downloaded_20261011/gift.png",
 "mana":"res://assets/ui/downloaded_20261011/mana.png",
 "attack":"res://assets/ui/downloaded_20261011/attack.png",
 "shield":"res://assets/ui/downloaded_20261011/shield.png",
 "energy":"res://assets/ui/downloaded_20261011/energy.png",
 "heal":"res://assets/ui/downloaded_20261011/heal.png"
}
const ALIASES: Dictionary={"block_counter":"shield","defend":"shield","multihit":"mana"}

static func path_for(key: String) -> String:
 var canonical:=str(ALIASES.get(key,key))
 var editable=preload("res://ui/candy_skin.gd").editable_theme()
 if editable!=null and editable.has_icon(canonical,"GameIcons"):
  var icon:Texture2D=editable.get_icon(canonical,"GameIcons")
  if icon!=null:return icon.resource_path
 return str(PATHS.get(canonical,""))
