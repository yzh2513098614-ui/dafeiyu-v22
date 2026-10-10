from pathlib import Path
import json

ROOT = Path(__file__).resolve().parent
INK = '#403853'
PINK = '#F48BB7'
MINT = '#7ADCC4'
GOLD = '#FFE071'
CREAM = '#FFF7DD'
BLUE = '#6469DF'

def svg(body, width=512, height=512, view='0 0 256 256'):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="{view}"><g stroke="{INK}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>'

icons = {
'backpack': ('背包', f'''
<path d="M93 72V52Q128 24 163 52V72" fill="none"/>
<path d="M79 92L59 97Q46 124 52 188L79 195M177 92L197 97Q210 124 204 188L177 195" fill="{PINK}"/>
<rect x="65" y="62" width="126" height="152" rx="31" fill="{MINT}"/>
<path d="M73 177Q128 203 183 177V188Q182 207 160 207H96Q75 207 73 188Z" fill="#48BBA9" stroke="none"/>
<path d="M70 88Q128 110 186 88L185 122Q128 146 71 122Z" fill="{PINK}"/>
<path d="M99 116Q108 99 119 110Q128 92 137 110Q148 99 157 116L148 138H108Z" fill="{GOLD}"/>
<path d="M112 116L120 129M128 110V129M144 116L137 129" stroke-width="5" fill="none"/>
<rect x="88" y="154" width="80" height="37" rx="13" fill="{CREAM}"/>
<path d="M94 78L110 77M101 167H145" stroke="white" stroke-width="7"/>
'''),
'tasks': ('任务', f'''
<path d="M73 46H178Q194 46 194 63V204Q194 219 178 219H73Q56 219 56 204V64Q56 46 73 46Z" fill="{GOLD}"/>
<path d="M179 64V192Q179 207 164 207H77" fill="none" stroke="#D8AF45" stroke-width="10"/>
<rect x="102" y="30" width="53" height="37" rx="13" fill="{MINT}"/>
<rect x="76" y="88" width="31" height="31" rx="8" fill="{CREAM}"/>
<path d="M80 103L91 112L106 91" fill="none" stroke="{BLUE}" stroke-width="7"/>
<path d="M125 100H165M125 116H150" fill="none" stroke-width="7"/>
<rect x="76" y="143" width="31" height="31" rx="8" fill="{PINK}"/>
<path d="M125 153H165M125 169H150" fill="none" stroke-width="7"/>
<path d="M72 59L84 59" stroke="white" stroke-width="7"/>
'''),
'chat': ('对话', f'''
<path d="M54 43H174Q195 43 195 64V140Q195 161 174 161H105L65 190L68 161H54Q32 161 32 139V65Q32 43 54 43Z" fill="{MINT}"/>
<path d="M59 143H171Q180 143 181 133" fill="none" stroke="#4CB7A9" stroke-width="9"/>
<path d="M143 121H205Q223 121 223 139V184Q223 199 206 199H198L204 219L177 199H143Q126 199 126 182V138Q126 121 143 121Z" fill="{PINK}"/>
<circle cx="69" cy="99" r="7" fill="{INK}" stroke="none"/><circle cx="106" cy="99" r="7" fill="{INK}" stroke="none"/><circle cx="143" cy="99" r="7" fill="{INK}" stroke="none"/>
<path d="M152 158H197M153 176H180M53 62H92" fill="none" stroke="{CREAM}" stroke-width="7"/>
'''),
'map': ('导览', f'''
<path d="M35 63L94 42L158 62L219 42V192L158 214L94 194L35 214Z" fill="{CREAM}"/>
<path d="M94 43L158 64V210L94 192Z" fill="{MINT}"/>
<path d="M158 64L215 48V186L158 208Z" fill="#F7CD82" stroke="none"/>
<path d="M94 43V194M158 63V211" fill="none" stroke-width="6"/>
<path d="M56 171Q81 126 122 153Q152 176 179 146" fill="none" stroke="{PINK}" stroke-width="9" stroke-dasharray="11 16"/>
<path d="M145 92Q145 60 174 60Q206 60 206 92Q206 113 174 139Q145 113 145 92Z" fill="{PINK}"/>
<circle cx="175" cy="91" r="11" fill="{CREAM}" stroke-width="6"/>
<path d="M49 80L71 72" stroke="white" stroke-width="7"/>
'''),
'shop': ('商店', f'''
<path d="M83 77V64Q128 20 173 64V77" fill="none" stroke-width="12"/>
<path d="M63 77H193L211 206Q211 219 197 219H59Q44 219 45 206Z" fill="{BLUE}"/>
<path d="M62 191Q128 207 197 191L198 206H58Z" fill="#484EB9" stroke="none"/>
<path d="M64 77H192L196 117H60Z" fill="{PINK}"/>
<circle cx="85" cy="95" r="6" fill="{INK}" stroke="none"/><circle cx="171" cy="95" r="6" fill="{INK}" stroke="none"/>
<path d="M83 147Q96 137 110 147T138 147T170 147M91 167Q103 159 116 167T142 167" fill="none" stroke="{GOLD}" stroke-width="9"/>
<path d="M66 125L63 151" stroke="{CREAM}" stroke-width="7"/>
'''),
'music': ('音乐', f'''
<circle cx="113" cy="138" r="82" fill="{BLUE}"/>
<path d="M61 98Q69 75 94 70M55 114L54 126" fill="none" stroke="{CREAM}" stroke-width="8"/>
<circle cx="113" cy="138" r="45" fill="{PINK}"/>
<circle cx="113" cy="138" r="12" fill="{CREAM}" stroke-width="6"/>
<path d="M169 46L220 35V128L198 133V70L169 77Z" fill="{GOLD}"/>
<ellipse cx="183" cy="146" rx="20" ry="15" fill="{MINT}"/>
<path d="M198 128V146" fill="none" stroke-width="8"/>
'''),
'deck': ('卡牌', f'''
<rect x="45" y="61" width="114" height="153" rx="18" fill="{BLUE}" transform="rotate(-12 102 135)"/>
<rect x="92" y="45" width="114" height="153" rx="18" fill="{PINK}" transform="rotate(10 149 121)"/>
<rect x="72" y="64" width="113" height="154" rx="18" fill="{MINT}"/>
<rect x="87" y="80" width="83" height="123" rx="10" fill="{CREAM}" stroke-width="5"/>
<path d="M128 101L138 124L163 127L144 145L149 169L128 158L107 169L112 145L93 127L118 124Z" fill="{GOLD}" stroke-width="6"/>
<path d="M102 184H153" stroke="{PINK}" stroke-width="7"/>
'''),
'settings': ('设置', f'''
<path d="M107 35H149L157 62L179 76L207 69L228 105L208 126V151L228 171L207 207L179 200L157 214L149 239H107L99 214L77 200L49 207L28 171L48 151V126L28 105L49 69L77 76L99 62Z" fill="{MINT}" transform="translate(0 -9)"/>
<circle cx="128" cy="128" r="53" fill="{PINK}"/>
<circle cx="128" cy="128" r="23" fill="{CREAM}"/>
<path d="M108 87Q117 82 129 82M76 103L70 115" fill="none" stroke="white" stroke-width="7"/>
'''),
'mail': ('邮件', f'''
<rect x="34" y="67" width="188" height="136" rx="22" fill="{GOLD}"/>
<path d="M38 190L95 143M218 190L163 143" fill="none" stroke="#BF9648" stroke-width="7"/>
<path d="M37 79L111 141Q128 153 145 141L218 79" fill="{CREAM}"/>
<path d="M115 115Q125 104 135 115Q153 110 151 125Q150 139 127 148Q105 134 104 122Q103 109 115 115Z" fill="{PINK}" stroke-width="6"/>
<path d="M49 177V188H68" fill="none" stroke="white" stroke-width="7"/>
'''),
'gift': ('礼物', f'''
<path d="M128 70Q65 83 66 49Q66 17 94 36Z" fill="{MINT}"/>
<path d="M128 70Q191 83 190 49Q190 17 162 36Z" fill="{MINT}"/>
<rect x="49" y="99" width="158" height="118" rx="15" fill="{PINK}"/>
<path d="M55 190H201V205Q201 211 194 211H62Q55 211 55 205Z" fill="#D9649D" stroke="none"/>
<rect x="37" y="73" width="182" height="49" rx="12" fill="{PINK}"/>
<path d="M108 76H148V216H108Z" fill="{GOLD}" stroke-width="7"/>
<path d="M53 87H77M66 137V163" fill="none" stroke="{CREAM}" stroke-width="7"/>
'''),
'calendar': ('日历', f'''
<rect x="43" y="49" width="170" height="167" rx="23" fill="{CREAM}"/>
<path d="M49 91V71Q49 55 66 55H190Q207 55 207 71V91Z" fill="{PINK}" stroke="none"/>
<path d="M46 96H210M82 33V69M174 33V69" fill="none"/>
<path d="M73 129H88M113 129H128M73 169H88" fill="none" stroke="#9C92AC" stroke-width="9"/>
<rect x="144" y="117" width="45" height="44" rx="10" fill="{MINT}" stroke-width="6"/>
<path d="M154 138L164 146L181 130" fill="none" stroke-width="5"/>
<path d="M114 168H129M153 185H183" fill="none" stroke="{PINK}" stroke-width="7"/>
'''),
'shell': ('贝壳', f'''
<path d="M100 202Q55 182 34 139Q20 112 46 95Q42 57 78 57Q104 23 128 49Q152 23 178 57Q214 57 210 95Q237 112 222 139Q201 182 156 202Z" fill="{GOLD}"/>
<path d="M38 130Q74 180 128 184Q186 180 218 130Q198 184 155 202H101Q58 184 38 130Z" fill="#F4B45C" stroke="none"/>
<path d="M100 188L59 113M116 183L87 80M128 181V74M140 183L169 80M156 188L197 113" fill="none" stroke="#B48369" stroke-width="6"/>
<path d="M100 183Q128 169 156 183L163 209Q128 226 93 209Z" fill="{PINK}" stroke-width="7"/>
<path d="M59 86L68 77M98 62L107 58" stroke="{CREAM}" stroke-width="8"/>
'''),
}

for key, (name, body) in icons.items():
    (ROOT/'icons'/f'{key}.svg').write_text(svg(body), encoding='utf-8')

whale = f'''<path d="M42 112Q48 46 147 44Q250 45 259 119Q261 129 284 134Q303 110 327 94Q333 139 313 158Q326 180 340 191Q301 202 279 176Q224 219 138 201Q67 187 42 146Z" fill="{MINT}"/>
<path d="M52 144Q133 181 252 138Q222 198 139 191Q73 180 52 144Z" fill="{CREAM}" stroke="none"/>
<path d="M134 163Q151 146 168 160Q161 184 139 185Z" fill="#42BBA7" stroke-width="5"/>
<path d="M104 79Q95 88 89 107" stroke="white" stroke-width="12" fill="none"/>
<path d="M150 111Q161 96 173 111" fill="none" stroke-width="7"/>
<ellipse cx="187" cy="127" rx="17" ry="9" fill="{PINK}" stroke="none"/>
<path d="M143 132Q151 145 168 136" fill="none" stroke-width="5"/>
<path d="M121 32Q116 12 129 5Q141 15 138 31M145 34Q154 8 171 16Q168 35 154 39" fill="{BLUE}" stroke-width="5"/>
<path d="M49 169Q68 181 75 194Q53 201 43 189" fill="{MINT}" stroke-width="6"/>
'''
(ROOT/'whale.svg').write_text(svg(whale,720,440,'0 0 360 220'),encoding='utf-8')
manifest = {'method':'original procedural SVG + Godot Control rendering','palette':{'outline':INK,'pink':PINK,'mint':MINT,'yellow':GOLD,'cream':CREAM,'blue':BLUE},'icons':[{'id':key,'name':name,'svg':f'icons/{key}.svg','png':f'icons/{key}.png','size':[512,512]} for key,(name,_) in icons.items()], 'ui':'native layered StyleBoxFlat, independent prototype; current game not replaced'}
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'BUILT {len(icons)} original SVG icons and whale illustration')
