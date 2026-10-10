from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
def p(id,x,y,z,angle=0):return {'id':id,'pos':[x,y,z],'angle':angle}
layouts=[('bedroom','晨光卧室','oak','beige_wainscot',[0,0,1.0],[
 p('window_oak',-3.5,1.0,-3.17),p('curtains_ivory',-3.5,.84,-3.12),p('window_city',2.4,1.14,-3.17),p('door_ivory',4.78,0,-3.16),p('painting_whale',-.1,1.66,-3.16),p('shelf_books',1.13,1.75,-3.13),p('clock',5.7,2.13,-3.16),p('lamp_wall',-5.97,1.82,-2.42,90),
 p('bed_navy',-3.40,0,-.16),p('nightstand',-5.10,0,-2.1),p('lamp_table',-5.1,.73,-2.5),p('books',-4.89,.73,-2.40),p('wardrobe',-1.2,0,-2.32),p('plant_broadleaf',5.25,0,-1.80),
 p('desk_oak',2.4,0,-2.13),p('monitor',2.48,.97,-2.94),p('keyboard',2.35,.97,-2.55),p('whale_mug',3.18,.98,-2.61),p('office_chair',2.40,0,-.85),p('waste_bin',3.78,0,-1.58),
 p('armchair_sage',4.33,0,2.37),p('side_table',5.45,0,2.50),p('tea_tray',5.45,.66,2.01),p('lamp_floor',5.37,0,.63),p('bookcase',-5.33,0,1.62,90),p('entry_bench',-3.2,0,3.10),p('basket',-1.88,0,2.76),p('slippers',-3.52,0,.57),p('plant_snake',-.86,0,-1.06),p('cushion',4.38,.71,1.75),p('whale_plush',-3.1,.85,-2.17),p('folded_blanket',-3.15,.83,-.92),p('flowers',1.51,.97,-2.78)]),
 ('studio','蓝光工作室','concrete','plaster_ivory',[0,0,.8],[
 p('window_city',-3.9,1.12,-3.17),p('window_city',2.7,1.12,-3.17),p('door_glass',.03,0,-3.16),p('rail_cyan',.1,2.61,-3.14),p('clock',5.55,2.10,-3.16),p('painting_mountain',-5.97,1.70,-2.42,90),
 p('fridge',-5.14,0,-2.15),p('sink_counter',-3.71,0,-2.15),p('stove_counter',-2.34,0,-2.15),p('counter_blank',-.97,0,-2.15),p('espresso',-.97,1.03,-2.57),p('plate_rack',-2.8,1.92,-3.13),
 p('desk_white',3.3,0,-2.14),p('monitor',3.45,.97,-2.94),p('keyboard',3.32,.97,-2.55),p('plant_fiddle',5.36,0,-2.20),p('office_chair',3.28,0,-.84),p('bookcase',1.15,0,-2.65),p('lamp_table',2.35,.97,-2.74),
 p('loveseat_navy',-3.58,0,1.13),p('coffee_table',-3.58,0,2.61),p('tea_tray',-3.15,.55,2.1),p('open_book',-4.07,.55,2.18),p('armchair_navy',-.30,0,2.57),p('side_table',1.44,0,2.58),p('whale_plush',1.43,.68,2.16),p('lamp_floor',.60,0,1.28),p('plant_broadleaf',-5.20,0,1.15),p('shoe_cabinet',5.3,0,3.01),p('coat_rack',5.34,0,1.3),p('mirror',4.37,1.83,-3.15)]),
 ('reading_cafe','木色阅读室','pale_oak','plaster_mint',[0,0,.6],[
 p('window_oak',-3.42,1,-3.17),p('window_oak',.75,1,-3.17),p('door_walnut',4.25,0,-3.16),p('lamp_wall',-5.97,1.87,-2.35,90),p('painting_mountain',2.58,1.72,-3.15),p('plant_hanging',5.5,1.36,-3.13),
 p('bookcase',-5.08,0,-2.62),p('bookcase',-5.33,0,1.56,90),p('cubby',-2.06,0,-2.58),p('fern',-2.03,1.43,-2.86),p('bakery_case',2.12,0,-1.75),p('bar_cabinet',3.91,0,-2.17),p('espresso',3.9,1.03,-2.57),p('vending_machine',5.45,0,-2.16),
 p('dining_round',-3.32,0,1.83),p('chair_oak',-3.32,0,2.93),p('chair_white',-3.32,0,-.45,180),p('tea_tray',-3.13,.89,1.02),p('flowers',-3.74,.90,.80),p('dining_white',3.10,0,2.22),p('chair_oak',2.45,0,3.18),p('chair_white',3.78,0,3.18),p('open_book',2.67,.91,1.75),p('whale_mug',3.67,.91,1.64),
 p('sofa_cream',-.17,0,-.68),p('cushion',.25,.70,-1.43),p('books',-2.34,1.45,-2.84),p('armchair_sage',-.18,0,3.04),p('side_table',1.31,0,2.93),p('lantern',1.3,.68,2.48),p('plant_broadleaf',5.2,0,2.35),p('menu_easel',4.34,0,-.42),p('tea_trolley',-5.13,0,3.06),p('basket',-1.57,0,2.89)])]
(root/'layouts_3d').mkdir(exist_ok=True)
for key,name,floor,wall,spawn,items in layouts:
 (root/'layouts_3d'/f'{key}.json').write_text(json.dumps({'name':name,'floor':floor,'wall':wall,'spawn':spawn,'items':items},ensure_ascii=False,indent=2))
print('3 world-space layouts generated')
