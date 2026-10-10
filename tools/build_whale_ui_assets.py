from pathlib import Path
p=Path(__file__).resolve().parents[1]/'assets'/'ui'
styles={
 'panel':('#fff9ed','#344475','#c3cae6'), 'paper':('#fffdf7','#879bc5','#d8e2f1'),
 'sky':('#e4f2ff','#7793bd','#c3d8f0'), 'status':('#e8f5ee','#86afab','#c5ddd5'),
 'button':('#f6fbff','#425386','#b7c7e8'), 'hover':('#d9ecff','#405a91','#9cbae5'),
 'pressed':('#6487cd','#304677','#4064a3'), 'disabled':('#e1e7ee','#9da9c1','#ccd4e1'),
 'row':('#f1f7ff','#94a7cb','#d7e3f3'), 'selected':('#d9e8ff','#566eab','#a8bae3'),
 'card':('#eef6ff','#91a6ca','#c5d7ef'), 'quote':('#eef0fc','#a2a6d0','#d5d8f0')}
outer='8,0 40,0 40,4 44,4 44,8 48,8 48,40 44,40 44,44 40,44 40,48 8,48 8,44 4,44 4,40 0,40 0,8 4,8 4,4 8,4'
inner='12,4 36,4 36,8 40,8 40,12 44,12 44,36 40,36 40,40 36,40 36,44 12,44 12,40 8,40 8,36 4,36 4,12 8,12 8,8 12,8'
for name,(fill,border,shadow) in styles.items():
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48" shape-rendering="crispEdges"><polygon points="{outer}" fill="{border}"/><polygon points="{inner}" fill="{fill}"/><path d="M12 8H36V12H12Z M8 12H12V32H8Z" fill="#ffffff" opacity=".8"/><path d="M12 36H36V40H12Z M36 12H40V36H36Z" fill="{shadow}"/></svg>'
 (p/(name+'.svg')).write_text(svg)
icons={
 'star':'<path fill="#dfac5d" d="M12 0h8v8h8v8h-8v8h-8v-8H4V8h8z"/><path fill="#ffe9a5" d="M12 4h4v8h8v4h-8v4h-4v-4H8v-4h4z"/>',
 'heart':'<path fill="#435584" d="M4 4h8v4h8V4h8v4h4v12h-4v4h-4v4h-4v4h-8v-4H8v-4H4v-4H0V8h4z"/><path fill="#edb1c0" d="M4 8h8v4h8V8h8v12h-4v4h-4v4h-8v-4H8v-4H4z"/>',
 'bag':'<path fill="#344475" d="M8 0h16v4h4v8h4v20H0V12h4V4h4z"/><path fill="#c7deff" d="M8 4h16v8h-4V8h-8v4H8z M4 16h24v12H4z"/><path fill="#fff9ed" d="M12 16h8v4h4v4H8v-4h4z"/>',
 'chest':'<path fill="#344475" d="M4 4h24v4h4v24H0V8h4z"/><path fill="#a8c9ef" d="M4 8h24v20H4z"/><path fill="#fff6dc" d="M4 16h24v4H4z"/><path fill="#5777b7" d="M12 12h8v12h-8z"/><path fill="#ffdc8b" d="M12 16h8v4h-8z"/>',
 'book':'<path fill="#344475" d="M0 4h12v4h8V4h12v24H20v4h-8v-4H0z"/><path fill="#fff9ed" d="M4 8h8v16H4z M20 8h8v16h-8z"/><path fill="#99b8df" d="M8 12h4v4H8z M20 12h4v4h-4z"/>',
 'arrow_up':'<path fill="#40568c" d="M12 4h8v4h4v4h4v4H4v-4h4V8h4z"/>',
 'arrow_down':'<path fill="#40568c" d="M4 12h24v4h-4v4h-4v4h-8v-4H8v-4H4z"/>',
 'wave':'<path fill="#5579bd" d="M0 16h4v-4h8v4h8v-4h8v4h4v12H0z"/><path fill="#d8efff" d="M0 20h8v-4h8v4h8v-4h8v12H0z"/>'}
for name,path in icons.items():(p/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32" shape-rendering="crispEdges">{path}</svg>')
