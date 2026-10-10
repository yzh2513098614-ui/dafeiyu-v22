extends RefCounted
## Distinct activity zones and decoration silhouettes for every room program.
const Lib=preload("res://district/decor_library.gd")

static func dress(holder: Node3D,kind: String,w: float,d: float,door: Vector3) -> void:
 Lib.configure(holder,w,d,door)
 var left: float=-w*.28; var right: float=w*.28
 var rear: float=-d*.29
 var front: float=d*.20
 match kind:
  "restaurant_dining":
   Lib.rug(holder,Vector3(left,0,front),Vector2(4.5,3.0),Color("879d9e"))
   for x in [left,right]: Lib.place(holder,"restaurant_booth_set",Vector3(x,0,rear))
   Lib.place(holder,"restaurant_booth_set",Vector3(right,0,front))
   Lib.place(holder,"restaurant_bistro_set",Vector3(left,0,front))
   Lib.place(holder,"restaurant_service_cart",Vector3(0,0,rear-.3))
   Lib.place(holder,"restaurant_menu_stand",Vector3(-w*.41,0,front+.5))
   Lib.place(holder,"restaurant_herb_rack",Vector3(w*.40,0,-.1),-90)
  "restaurant_patisserie":
   Lib.place(holder,"restaurant_pastry_display",Vector3(left*.55,0,rear))
   Lib.place(holder,"restaurant_pastry_table",Vector3(right,0,rear+.5))
   Lib.place(holder,"restaurant_bistro_set",Vector3(left*.7,0,front))
   Lib.place(holder,"restaurant_service_cart",Vector3(right,0,front))
   Lib.place(holder,"hydrangea_pot",Vector3(-w*.4,0,rear))
  "restaurant_bar":
   Lib.place(holder,"restaurant_coffee_station",Vector3(0,0,rear))
   Lib.place(holder,"restaurant_bistro_set",Vector3(left*.65,0,front))
   Lib.place(holder,"restaurant_pastry_table",Vector3(right,0,-.1))
   Lib.place(holder,"restaurant_menu_stand",Vector3(left,0,rear))
   Lib.place(holder,"sculpted_planter",Vector3(right,0,rear))
  "restaurant_kitchen":
   Lib.place(holder,"restaurant_dish_station",Vector3(left,0,rear))
   Lib.place(holder,"restaurant_kitchen_island",Vector3(0,0,-.2))
   Lib.place(holder,"restaurant_pantry_shelf",Vector3(right,0,rear))
   Lib.place(holder,"restaurant_service_cart",Vector3(left*.7,0,front))
   Lib.place(holder,"restaurant_herb_rack",Vector3(right,0,front))
   Lib.place(holder,"waste_bin",Vector3(-w*.42,0,rear+.8))
  "restaurant_pantry":
   for x in [left,right]: Lib.place(holder,"restaurant_pantry_shelf",Vector3(x,0,rear))
   Lib.place(holder,"restaurant_service_cart",Vector3(left*.7,0,front))
   Lib.place(holder,"restaurant_herb_rack",Vector3(right,0,front))
   Lib.place(holder,"waste_bin",Vector3(w*.40,0,0))
  "restaurant_lounge":
   Lib.rug(holder,Vector3(0,0,-.1),Vector2(5.0,3.4),Color("85999f"))
   Lib.place(holder,"restaurant_booth_set",Vector3(left,0,rear))
   Lib.place(holder,"restaurant_bistro_set",Vector3(right*.5,0,front-.5))
   Lib.place(holder,"lounge_chair",Vector3(right,0,rear),-20)
   Lib.place(holder,"floor_lamp",Vector3(right+1,0,rear))
   Lib.place(holder,"hydrangea_pot",Vector3(-w*.40,0,front))
  "school_lobby":
   Lib.place(holder,"notice_easel",Vector3(0,0,rear))
   Lib.place(holder,"curved_bench",Vector3(left,0,front))
   Lib.place(holder,"school_open_bookshelf",Vector3(right,0,rear))
   Lib.place(holder,"school_globe",Vector3(left,0,rear))
   Lib.place(holder,"hydrangea_pot",Vector3(right,0,front))
  "school_classroom","school_math":
   Lib.place(holder,"school_learning_board",Vector3(0,0,rear))
   for x in [left*.85,right*.85]:
    Lib.place(holder,"school_twin_desks",Vector3(x,0,-.40))
    Lib.place(holder,"school_twin_desks",Vector3(x,0,front+.25))
   Lib.place(holder,"school_globe",Vector3(-w*.4,0,rear))
   Lib.place(holder,"school_projector_cart",Vector3(w*.40,0,rear))
  "school_staff":
   Lib.place(holder,"school_twin_desks",Vector3(left*.60,0,rear))
   Lib.place(holder,"school_open_bookshelf",Vector3(right,0,rear))
   Lib.place(holder,"lounge_chair",Vector3(left,0,front),15)
   Lib.place(holder,"restaurant_pastry_table",Vector3(0,0,front))
   Lib.place(holder,"notice_easel",Vector3(right,0,front))
  "school_library","school_language":
   Lib.rug(holder,Vector3(0,0,front),Vector2(4.8,3.0),Color("8faaa5"))
   for x in [left,right]: Lib.place(holder,"school_open_bookshelf",Vector3(x,0,rear))
   Lib.place(holder,"school_twin_desks",Vector3(0,0,-.3))
   Lib.place(holder,"lounge_chair",Vector3(left*.85,0,front),18)
   Lib.place(holder,"lounge_chair",Vector3(right*.85,0,front),-18)
   Lib.place(holder,"floor_lamp",Vector3(-w*.40,0,front-.5))
   Lib.place(holder,"school_globe",Vector3(0,0,rear))
  "school_science":
   for x in [left*.80,right*.80]: Lib.place(holder,"school_science_bench",Vector3(x,0,-.5))
   Lib.place(holder,"school_learning_board",Vector3(0,0,rear))
   Lib.place(holder,"school_lab_stool",Vector3(left,0,front))
   Lib.place(holder,"school_lab_stool",Vector3(right,0,front))
   Lib.place(holder,"school_storage_cubbies",Vector3(-w*.41,0,rear))
  "school_observatory":
   Lib.rug(holder,Vector3(-1.6,0,-.3),Vector2(4.8,4.0),Color("768da6"))
   Lib.place(holder,"school_telescope",Vector3(-1.6,0,-.3),25)
   Lib.place(holder,"school_globe",Vector3(left,0,rear))
   Lib.place(holder,"school_science_bench",Vector3(right,0,rear))
   Lib.place(holder,"school_twin_desks",Vector3(right*.8,0,front))
   Lib.place(holder,"school_projector_cart",Vector3(left,0,front))
  "school_art","school_craft":
   Lib.place(holder,"school_artist_easel",Vector3(left,0,rear),-12)
   Lib.place(holder,"school_artist_easel",Vector3(0,0,rear),8)
   Lib.place(holder,"school_storage_cubbies",Vector3(right,0,rear))
   Lib.place(holder,"school_twin_desks",Vector3(left*.80,0,front))
   Lib.place(holder,"school_art_cart",Vector3(right*.70,0,front))
   Lib.place(holder,"hydrangea_pot",Vector3(-w*.40,0,-.1))
  "school_media":
   Lib.place(holder,"school_learning_board",Vector3(0,0,rear))
   Lib.place(holder,"school_projector_cart",Vector3(left,0,-.3))
   Lib.place(holder,"school_twin_desks",Vector3(right*.70,0,front))
   Lib.place(holder,"school_open_bookshelf",Vector3(right,0,rear))
   Lib.place(holder,"school_lab_stool",Vector3(left,0,front))
  "school_store":
   for x in [left,right]: Lib.place(holder,"school_storage_cubbies",Vector3(x,0,rear))
   Lib.place(holder,"school_art_cart",Vector3(left*.8,0,front))
   Lib.place(holder,"school_projector_cart",Vector3(right*.8,0,front))
   Lib.place(holder,"school_globe",Vector3(0,0,rear))
  "hospital_lobby","hospital_triage":
   Lib.place(holder,"hospital_reception_desk",Vector3(0,0,rear))
   Lib.place(holder,"hospital_waiting_seats",Vector3(left,0,front))
   if w>14: Lib.place(holder,"hospital_waiting_seats",Vector3(right,0,front))
   Lib.place(holder,"hospital_sanitizer_stand",Vector3(right,0,0))
   Lib.place(holder,"notice_easel",Vector3(left,0,rear))
   Lib.place(holder,"sculpted_planter",Vector3(w*.41,0,rear))
  "hospital_nurse":
   Lib.place(holder,"hospital_reception_desk",Vector3(0,0,rear))
   Lib.place(holder,"hospital_supply_shelf",Vector3(left,0,front))
   Lib.place(holder,"hospital_medicine_cart",Vector3(right,0,front))
   Lib.place(holder,"hospital_monitor_trolley",Vector3(left,0,rear))
   Lib.place(holder,"hospital_sanitizer_stand",Vector3(right,0,rear))
  "hospital_consult","hospital_treatment":
   Lib.place(holder,"hospital_exam_bay",Vector3(left*.50,0,rear))
   Lib.place(holder,"hospital_monitor_trolley",Vector3(right,0,rear))
   Lib.place(holder,"hospital_medicine_cart",Vector3(right,0,front))
   Lib.place(holder,"hospital_oxygen_trolley",Vector3(-w*.4,0,rear))
   Lib.place(holder,"hospital_sanitizer_stand",Vector3(left,0,front))
  "hospital_pharmacy","hospital_lab":
   for x in [left,right]: Lib.place(holder,"hospital_supply_shelf",Vector3(x,0,rear))
   Lib.place(holder,"hospital_medicine_cart",Vector3(left*.7,0,front))
   Lib.place(holder,"school_science_bench",Vector3(right*.55,0,front))
   Lib.place(holder,"hospital_sanitizer_stand",Vector3(-w*.40,0,0))
  "hospital_imaging":
   Lib.place(holder,"hospital_scanner",Vector3(0,0,-.7))
   Lib.place(holder,"hospital_monitor_trolley",Vector3(right,0,rear))
   Lib.place(holder,"hospital_privacy_screen",Vector3(left,0,rear),90)
   Lib.place(holder,"hospital_sanitizer_stand",Vector3(left,0,front))
  "hospital_ward","hospital_recovery":
   for x in [left*.8,right*.8]: Lib.place(holder,"hospital_exam_bay",Vector3(x,0,rear+.35))
   Lib.place(holder,"hospital_iv_stand",Vector3(left+1.5,0,0))
   Lib.place(holder,"hospital_medicine_cart",Vector3(right,0,front))
   Lib.place(holder,"lounge_chair",Vector3(left,0,front),15)
   Lib.place(holder,"hydrangea_pot",Vector3(-w*.41,0,rear+.5))
  "hospital_waiting","hospital_quiet":
   Lib.rug(holder,Vector3(0,0,front),Vector2(4.7,3.1),Color("94aaa7"))
   Lib.place(holder,"hospital_waiting_seats",Vector3(left,0,rear))
   Lib.place(holder,"hospital_waiting_seats",Vector3(right,0,rear))
   Lib.place(holder,"restaurant_bistro_set",Vector3(left*.7,0,front))
   Lib.place(holder,"lounge_chair",Vector3(right,0,front),-20)
   Lib.place(holder,"floor_lamp",Vector3(w*.40,0,front))
   Lib.place(holder,"hydrangea_pot",Vector3(0,0,rear))
 # Small purpose-specific accents finish the room without filling its aisle.
 if kind in ["restaurant_pantry","restaurant_kitchen"]:
  Lib.place(holder,"retro_fridge",Vector3(w*.41,0,-.2))
  Lib.place(holder,"fire_extinguisher",Vector3(-w*.41,0,-.2))
 if kind in ["school_lobby","school_classroom","school_math","hospital_lobby","hospital_nurse","hospital_waiting"]:
  Lib.place(holder,"floor_clock",Vector3(w*.41,0,rear+.15))
 if kind in ["restaurant_lounge","school_library","school_staff","hospital_ward","hospital_quiet"]:
  Lib.place(holder,"coat_stand",Vector3(w*.41,0,-.1))
 if kind in ["school_craft","school_store","hospital_pharmacy","hospital_lab"]:
  Lib.place(holder,"woven_crate",Vector3(-w*.40,0,front-.3))
 if kind in ["school_staff","hospital_triage","hospital_consult","hospital_treatment"]:
  Lib.place(holder,"waste_bin",Vector3(w*.40,0,-.2))
