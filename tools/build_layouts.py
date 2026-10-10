from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
def item(id,x,y,sort_y=None):
 d={'id':id,'x':x,'y':y}
 if sort_y is not None:d['sort_y']=sort_y
 return d
layouts=[('bedroom','晨光卧室','oak','beige_wainscot',(710,735),[
 ('window_oak',388,262),('window_city',980,262),('curtains_ivory',390,278),('painting_whale',682,224),('clock',1268,217),('door_ivory',1160,285),('lamp_wall',175,230),('shelf_books',786,240),
 ('bed_navy',364,610),('nightstand',220,490),('lamp_table',220,407,490),('books',220,420,490),('wardrobe',550,480),('plant_broadleaf',1210,416),
 ('desk_oak',974,486),('monitor',986,397,486),('keyboard',978,429,486),('whale_mug',1052,410,486),('office_chair',980,585),('waste_bin',1120,535),
 ('armchair_sage',1115,804),('side_table',1224,785),('tea_tray',1224,707,785),('lamp_floor',1230,670),('bookcase',190,790),('entry_bench',410,865),('basket',515,860),('slippers',365,653),('plant_snake',550,410),('cushion',1113,750,804),('whale_plush',402,432,610),('folded_blanket',411,538,610),('flowers',917,405,486)]),
 ('studio','蓝光工作室','concrete','plaster_ivory',(710,745),[
 ('window_city',430,266),('window_city',1000,266),('door_glass',720,282),('rail_cyan',710,144),('light_cyan',1100,172),('clock',1280,205),('painting_mountain',190,219),
 ('fridge',220,465),('sink_counter',360,458),('stove_counter',488,458),('counter_blank',616,458),('espresso',608,378,458),('upper_cabinet',430,244),('plate_rack',560,250),
 ('desk_white',1080,480),('monitor',1093,391,480),('keyboard',1080,423,480),('plant_fiddle',1240,485),('office_chair',1080,585),('bookcase',840,488),('lamp_table',992,399,480),
 ('loveseat_navy',405,776),('coffee_table',410,890),('tea_tray',440,818,890),('open_book',355,829,890),('armchair_navy',700,820),('side_table',845,811),('whale_plush',845,751,811),('lamp_floor',790,690),('plant_broadleaf',195,760),('shoe_cabinet',1200,860),('coat_rack',1240,720),('mirror',1080,226)]),
 ('reading_cafe','木色阅读室','pale_oak','plaster_mint',(710,735),[
 ('window_oak',390,262),('window_oak',720,262),('door_walnut',1120,285),('lamp_wall',185,217),('painting_mountain',995,223),('shelf_books',620,218),('plant_hanging',1260,258),
 ('bookcase',190,536),('bookcase',350,536),('cubby',535,487),('fern',540,408,487),('bakery_case',880,482),('bar_cabinet',1040,482),('espresso',1040,345,482),('vending_machine',1230,490),
 ('dining_round',385,749),('chair_oak',266,811),('chair_white',510,804),('tea_tray',392,633,749),('flowers',353,647,749),('dining_white',968,763),('chair_oak',940,867),('chair_white',1080,867),('open_book',944,633,763),('whale_mug',1026,648,763),
 ('sofa_cream',665,565),('cushion',700,508,565),('books',587,478,487),('armchair_sage',680,856),('side_table',800,858),('lantern',800,785,858),('plant_broadleaf',1220,810),('menu_easel',1120,590),('tea_trolley',185,848),('basket',575,874)])]
for key,name,floor,wall,spawn,props in layouts:
 data={'name':name,'floor':floor,'wall':wall,'spawn':spawn,'items':[item(*prop) for prop in props]}
 (root/'layouts'/f'{key}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
print('Built 3 layouts')
