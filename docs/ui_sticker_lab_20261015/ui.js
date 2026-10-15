'use strict';

function createDemo(data) {
  const capacity = 64;
  const items = Object.fromEntries(data.items.map(item => [item.id, item]));
  const state = { page: 'components', mode: 'bag' };
  const makeSlots = entries => {
    const slots = Array(capacity).fill(null);
    entries.forEach(([id, count], index) => { slots[index] = { id, count }; });
    return slots;
  };
  function reset() {
    Object.assign(state, {
      bag: makeSlots([['sea_biscuit', 3], ['token_cracker', 2], ['retry_tea', 2], ['first_aid', 1], ['prompt_pen', 1], ['context_note', 1], ['fish_badge', 1], ['sea_shell', 4], ['soft_linen', 2], ['tide_compass', 1]]),
      chest: makeSlots([['sea_shell', 3], ['sea_soup', 2], ['lemon_water', 3], ['sea_biscuit', 2], ['prompt_pen', 1], ['soft_linen', 5]]),
      vitals: { health: 82, stamina: 65, hunger: 42, mood: 100 },
      equipment: {}, category: 'all', pages: { bag: 0, chest: 0 },
      selected: { source: 'bag', index: 0 }
    });
  }
  reset();
  const occupied = source => state[source].filter(Boolean).length;
  function selectedItem() {
    if (!state.selected) return null;
    const slot = state[state.selected.source][state.selected.index];
    return slot ? { ...items[slot.id], ...slot, ...state.selected } : null;
  }
  function transfer(source, index, all = false) {
    const slot = state[source][index];
    if (!slot) return { ok: false, message: '先选一个物品吧。' };
    const destination = source === 'bag' ? 'chest' : 'bag';
    let target = state[destination].findIndex(entry => entry && entry.id === slot.id);
    if (target < 0) target = state[destination].findIndex(entry => !entry);
    if (target < 0) return { ok: false, message: destination === 'bag' ? '小口袋装满了，先整理一个空格吧。' : '宝箱装满了，先留一个空格吧。' };
    const count = all ? slot.count : 1;
    if (!state[destination][target]) state[destination][target] = { id: slot.id, count: 0 };
    state[destination][target].count += count;
    slot.count -= count;
    if (!slot.count) state[source][index] = null;
    return { ok: true, message: `${items[slot.id].name} ×${count}，${destination === 'bag' ? '已经收进口袋。' : '已经放进宝箱。'}` };
  }
  function use() {
    const item = selectedItem();
    if (!item || item.source !== 'bag') return { ok: false, message: '先把它收进背包吧。' };
    if (item.action === 'consume') {
      const changed = Object.entries(item.effects).some(([vital, amount]) => amount > 0 && state.vitals[vital] < 100);
      if (!changed) return { ok: false, message: '现在已经精神满满啦，补给先留着。' };
      Object.entries(item.effects).forEach(([vital, amount]) => { state.vitals[vital] = Math.min(100, state.vitals[vital] + amount); });
      const slot = state.bag[item.index];
      if (--slot.count === 0) state.bag[item.index] = null;
      return { ok: true, message: `${item.name}用好了。${item.summary.split('\n')[0]}` };
    }
    if (item.action === 'equip') {
      state.equipment[item.equipmentSlot] = item.id;
      return { ok: true, message: `已装备${item.name} · ${item.summary}` };
    }
    return { ok: true, message: item.use || item.description };
  }
  function discard() {
    const selected = state.selected;
    if (!selected || selected.source !== 'bag' || !state.bag[selected.index]) return false;
    if (--state.bag[selected.index].count === 0) state.bag[selected.index] = null;
    return true;
  }
  function preset(name) {
    state.pages = { bag: 0, chest: 0 };
    if (name === 'normal') reset();
    if (name === 'full') state.vitals = { health: 100, stamina: 100, hunger: 100, mood: 100 };
    if (name === 'low') state.vitals = { health: 16, stamina: 12, hunger: 8, mood: 18 };
    if (name === 'zero') state.vitals = { health: 0, stamina: 0, hunger: 0, mood: 0 };
    if (name === 'empty-bag') { state.bag = Array(capacity).fill(null); state.selected = null; }
    if (name === 'full-bag') {
      const ids = data.items.slice(0, 8).map(item => item.id);
      state.bag = Array.from({ length: capacity }, (_, index) => ({ id: ids[index % ids.length], count: 2 + index % 7 }));
      state.selected = { source: state.mode === 'chest' ? 'chest' : 'bag', index: 0 };
    }
    if (name === 'empty-chest') { state.mode = 'chest'; state.chest = Array(capacity).fill(null); state.selected = { source: 'bag', index: 0 }; }
  }
  return { state, items, capacity, reset, occupied, selectedItem, transfer, use, discard, preset };
}

if (typeof module !== 'undefined' && module.exports) module.exports = { createDemo };

if (typeof document !== 'undefined') {
  const data = JSON.parse(document.getElementById('demo-data').textContent);
  const demo = createDemo(data);
  const state = demo.state;
  const $ = id => document.getElementById(id);
  const escape = value => String(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  const icon = (name, extra = '') => `<svg ${extra} aria-hidden="true"><use href="#i-ui-${name}"/></svg>`;
  const vitalNames = { health: '生命', stamina: '体力', hunger: '饱食', mood: '心情' };
  const vitalIcons = { health: 'heart', stamina: 'bolt', hunger: 'fish', mood: 'smile' };
  const colors = { health: ['#f4407e', '#ffe3ec'], stamina: ['#23cbd4', '#dcf8f9'], hunger: ['#feb633', '#fff2dc'], mood: ['#638eff', '#e4ecff'] };
  const categories = { all: '全部', supplies: '补给', tools: '工具', stories: '线索', materials: '材料' };
  const categoryIcons = { all: 'grid', supplies: 'fish', tools: 'bolt', stories: 'book', materials: 'star' };
  let motions = {};
  let toastTimer;
  let previousFocus;
  let activePreset = 'normal';
  function toast(message) {
    clearTimeout(toastTimer);
    $('toast').textContent = message; $('toast').hidden = false;
    toastTimer = setTimeout(() => { $('toast').hidden = true; }, 2600);
  }
  function markMotions(before) {
    Object.keys(vitalNames).forEach(vital => {
      const difference = state.vitals[vital] - before[vital];
      if (difference) motions[vital] = { from: before[vital], delta: difference, at: Date.now() };
    });
    setTimeout(renderMeters, 410); setTimeout(renderMeters, 610);
  }
  function meterHTML(vital) {
    const value = state.vitals[vital];
    const low = value > 0 && value <= 20;
    const zero = value === 0;
    const motion = motions[vital];
    const elapsed = motion ? (Date.now() - motion.at) / 1000 : 1;
    const gain = motion && motion.delta > 0 && elapsed < .4;
    const ghost = motion && motion.delta < 0 && elapsed < .6 ? value + (motion.from - value) * (1 - elapsed / .6) : value;
    const reading = gain ? `+${motion.delta}` : zero ? '0 !' : value >= 100 ? '满' : `${value} / 100${low ? ' !' : ''}`;
    const [color, tint] = colors[vital];
    const health = vital === 'health';
    return `<div class="meter ${low ? 'low' : ''} ${zero ? 'zero' : ''} ${gain ? 'heal' : ''}" style="--meter-color:${color};--meter-tint:${tint};--fill:${value}%;--ghost:${ghost}%;--alert-ring:${health ? '#ffd7e4' : '#ffe9c2'};--alert-shadow:${health ? '#f4407e' : '#feb633'};--alert-ink:${health ? '#974154' : '#8a5a17'}"><span class="meter-icon">${icon(vitalIcons[vital])}</span><span class="meter-caption">${vitalNames[vital]}</span><span class="meter-track" role="progressbar" aria-label="${vitalNames[vital]}" aria-valuenow="${value}" aria-valuemin="0" aria-valuemax="100"><span class="meter-inner"><span class="meter-ghost" style="animation-duration:${Math.max(0, .6 - elapsed)}s"></span><span class="meter-fill"></span><span class="meter-accent"></span></span></span><span class="meter-value ${gain ? 'gain' : value >= 100 ? 'full' : ''}">${reading}</span></div>`;
  }
  function renderMeters() {
    const html = Object.keys(vitalNames).map(meterHTML).join('');
    $('component-meters').innerHTML = html; $('inventory-meters').innerHTML = html;
  }
  function renderPresets() {
    const config = {
      components: { title: '共用组件', states: [['normal', '普通读数'], ['full', '全部满值'], ['low', '低值提醒'], ['zero', '归零空槽']], guide: '点击按钮，看按压反馈；减少体力，看消耗拖尾；增加饱食，看恢复闪头。' },
      inventory: { title: '背包与宝箱', states: [['normal', '默认物品'], ['empty-bag', '空背包'], ['full-bag', '背包装满'], ['empty-chest', '空宝箱']], guide: '选一个物品，查看故事和效果。切到宝箱模式，试试收取、放入或全部收取。' },
      dialogue: { title: 'Galgame 对话演出', states: [['normal', '对白与立绘'], ['narration', '旁白演出'], ['choices', '分支选择'], ['automatic', '自动阅读'], ['backlog', '对白回看'], ['hidden-ui', '隐藏界面']], guide: '第一次点击补全当前句，下一次继续。Ctrl 快进到选项；A 自动、Q 快存、L 快读、H 查看立绘。设置里可调整阅读节奏。' }
    }[state.page];
    $('inspector-title').textContent = config.title; $('interaction-guide').textContent = config.guide;
    $('state-presets').innerHTML = config.states.map(([id, label]) => `<button class="state-button ${activePreset === id ? 'selected' : ''}" data-action="preset" data-preset="${id}" aria-pressed="${activePreset === id}">${label}</button>`).join('');
  }
  function visibleSlots(source) {
    return state[source].map((slot, index) => ({ slot, index })).filter(entry => entry.slot && (state.category === 'all' || demo.items[entry.slot.id].category === state.category));
  }
  function renderGrid(source) {
    const entries = visibleSlots(source);
    const perPage = state.mode === 'chest' ? 12 : 20;
    const pages = Math.max(1, Math.ceil(entries.length / perPage));
    state.pages[source] = Math.min(state.pages[source], pages - 1);
    const slice = entries.slice(state.pages[source] * perPage, (state.pages[source] + 1) * perPage);
    const content = slice.map(({ slot, index }) => {
      const item = demo.items[slot.id];
      const selected = state.selected && state.selected.source === source && state.selected.index === index;
      return `<button class="item-slot ${selected ? 'selected' : ''}" data-category="${item.category}" data-action="select-item" data-source="${source}" data-index="${index}" aria-label="${escape(item.name)}，${slot.count}个" aria-pressed="${Boolean(selected)}"><span class="slot-index" aria-hidden="true">${selected ? icon('check') : String(index + 1).padStart(2, '0')}</span><span class="quantity">×${slot.count}</span><span class="slot-art"><img src="${item.icon}" alt=""></span><span class="slot-name">${escape(item.name)}</span></button>`;
    }).join('');
    const blanks = '<div class="item-slot empty" aria-hidden="true"><span>＋</span></div>'.repeat(perPage - slice.length);
    const empty = !slice.length ? `<div class="empty-state">${icon(source === 'bag' ? 'bag' : 'star')}<b>${demo.occupied(source) ? '这一类还没有物品' : source === 'bag' ? '小口袋轻轻的' : '宝箱已经收拾好啦'}</b><small>${source === 'bag' ? '把喜欢的东西，慢慢装进来。' : '需要的时候，再放一些补给进来。'}</small></div>` : '';
    const pagination = Array.from({ length: pages }, (_, page) => `<button class="page-button ${state.pages[source] === page ? 'selected' : ''}" data-action="grid-page" data-source="${source}" data-index="${page}" aria-label="${source === 'bag' ? '背包' : '宝箱'}第${page + 1}页" aria-current="${state.pages[source] === page ? 'page' : 'false'}">${String(page + 1).padStart(2, '0')}</button>`).join('');
    return `<div class="inventory-grid-panel ${source === 'chest' ? 'chest-tray' : 'bag-tray'}"><div class="grid-panel-heading"><span>${icon(source === 'bag' ? 'bag' : 'grid')}${source === 'bag' ? '随身背包' : '码头补给箱'}</span><small>${demo.occupied(source)} / ${demo.capacity} 格</small></div><div class="inventory-grid">${content}${blanks}${empty}</div><div class="pagination"><span class="page-label">第 ${state.pages[source] + 1} / ${pages} 页</span><div class="page-list">${pagination}</div><span class="page-count">${entries.length} 组物品</span></div></div>`;
  }
  function renderDetail() {
    const item = demo.selectedItem();
    const detail = $('item-detail');
    detail.classList.toggle('detail-empty', !item);
    if (!item) { detail.innerHTML = `<div class="detail-topline"><span>物品档案</span><span>ITEM NOTES</span></div><div class="detail-placeholder">${icon('bag')}<h2>给小物品留个位置</h2><p>点击左边的物品<br>看看它的故事与用途。</p><span>每一件，都值得好好收藏。</span></div>`; return; }
    const equipped = Object.values(state.equipment).includes(item.id);
    const useLabel = item.action === 'consume' ? '使用一份' : item.action === 'equip' ? equipped ? '已经装备' : '装备起来' : item.action === 'read' ? '读一读' : '看看它';
    const cannotConsume = item.action === 'consume' && Object.entries(item.effects).every(([vital]) => state.vitals[vital] >= 100);
    const useButton = `<button class="sticker-button small ${state.mode === 'chest' ? 'secondary-action' : 'primary-action'}" data-action="use" ${cannotConsume || equipped ? 'disabled' : ''}>${icon(equipped ? 'check' : categoryIcons[item.category])}${useLabel}</button>`;
    const primary = state.mode === 'chest' ? `<button class="sticker-button small accent-yellow" data-action="transfer">${item.source === 'chest' ? '收取一个' : '放入一个'}${icon('arrow')}</button>` : useButton;
    detail.innerHTML = `<div class="detail-topline"><span>物品档案</span><span class="detail-source">${icon(item.source === 'chest' ? 'grid' : 'bag')}${item.source === 'chest' ? '宝箱里' : '背包里'}</span></div><div class="detail-art" data-category="${item.category}"><img src="${item.icon}" alt="${escape(item.name)}"><span class="detail-stack">持有 <b>×${item.count}</b></span>${equipped ? `<span class="equipped-stamp">${icon('check')}已装备</span>` : ''}</div><div class="detail-heading"><span class="detail-kind">${escape(item.kind)}</span><h2>${escape(item.name)}</h2></div><div class="detail-copy" tabindex="0" aria-label="物品说明"><p class="detail-description">${escape(item.description)}</p><div class="detail-effects"><span>${icon(categoryIcons[item.category])}${item.action === 'consume' ? '补给效果' : item.action === 'equip' ? '装备效果' : '物品用途'}</span>${escape(item.summary).replace(/\n/g, '<br>')}</div><p class="detail-quote">「${escape(item.quote)}」</p></div><div class="detail-actions">${primary}${state.mode === 'chest' && item.source === 'bag' ? useButton : ''}${item.source === 'bag' ? '<button class="plain-button" data-action="discard">放下一个…</button>' : ''}</div>`;
  }
  function renderInventory() {
    const chest = state.mode === 'chest';
    $('inventory-title').textContent = chest ? '把小确幸，收进口袋' : '随身小口袋';
    document.querySelectorAll('.mode-tabs button').forEach(button => {
      const chosen = button.dataset.action === (chest ? 'mode-chest' : 'mode-bag');
      button.classList.toggle('selected', chosen); button.setAttribute('aria-pressed', String(chosen));
    });
    $('inventory-categories').innerHTML = Object.entries(categories).map(([id, label]) => `<button class="category ${state.category === id ? 'selected' : ''}" data-action="category" data-category="${id}" aria-pressed="${state.category === id}">${icon(categoryIcons[id])}${label}</button>`).join('');
    const occupied = demo.occupied('bag');
    $('bag-capacity').textContent = `${occupied} / ${demo.capacity} 格`;
    $('inventory-load').classList.toggle('is-full', occupied >= demo.capacity);
    $('bag-capacity-fill').style.setProperty('width', `${occupied / demo.capacity * 100}%`);
    $('inventory-grids').classList.toggle('chest-mode', chest);
    $('inventory-grids').innerHTML = renderGrid('bag') + (chest ? renderGrid('chest') : '');
    $('take-all').hidden = !chest; $('take-all').disabled = !demo.occupied('chest');
    $('inventory-hint').textContent = demo.occupied('bag') >= demo.capacity ? '背包已满 · 同类物品仍可叠加，新物品需要空格。' : chest ? '选中物品，收取或放入一个。' : '点击物品，看看它的小故事。';
    renderDetail(); renderMeters();
  }
  function switchPage(page) {
    state.page = page; activePreset = 'normal'; gal.pause(); closeModal();
    const captions = { components: '01 / 共用组件', inventory: '02 / 背包与宝箱', dialogue: '03 / 对话界面' };
    document.querySelectorAll('.nav-button').forEach(button => { const active = button.dataset.nav === page; button.classList.toggle('active', active); if (active) button.setAttribute('aria-current', 'page'); else button.removeAttribute('aria-current'); });
    Object.keys(captions).forEach(id => { $(`screen-${id}`).hidden = id !== page; });
    $('page-caption').textContent = captions[page];
    $('scene').dataset.page = page; $('viewport').dataset.page = page;
    $('canvas-dimensions').textContent = page === 'dialogue' ? '16:9 · 1448 × 815' : '1448 × 1086';
    $('scene-footer-copy').textContent = page === 'components' ? '厚白包边 · 浅蓝内框 · 分层底座' : page === 'inventory' ? '物品、故事和一点点补给，都有自己的位置。' : '慢慢说，今天还很长。';
    window.history.replaceState(null, '', `#${page}`);
    renderPresets(); renderInventory();
    if (page === 'dialogue') gal.enter();
    fitCanvas();
  }
  function openModal(id) {
    previousFocus = document.activeElement; $(id).hidden = false;
    $(id).querySelector('button').focus();
  }
  function closeModal() {
    const open = !$('backlog-modal').hidden || !$('discard-modal').hidden || !$('gal-settings-modal').hidden;
    $('backlog-modal').hidden = true; $('discard-modal').hidden = true; $('gal-settings-modal').hidden = true;
    if (open && previousFocus && previousFocus.isConnected) previousFocus.focus();
    if (open) gal.resume();
  }
  const gal = createGalDialogue({ data, $, escape, icon, toast, openModal, closeModal });
  function applyPreset(name) {
    activePreset = name; motions = {}; closeModal();
    if (state.page === 'dialogue') {
      gal.preset(name);
    } else { demo.preset(name); renderInventory(); }
    renderPresets(); renderMeters();
  }
  document.addEventListener('click', event => {
    if (event.target.classList.contains('modal-overlay')) { closeModal(); return; }
    const button = event.target.closest('button');
    if (!button || button.disabled) return;
    if (button.dataset.nav) { switchPage(button.dataset.nav); return; }
    const action = button.dataset.action;
    if (state.page === 'dialogue' && gal.handle(action, button)) return;
    if (action === 'preset') { applyPreset(button.dataset.preset); return; }
    if (action === 'reset') { demo.reset(); motions = {}; gal.reset(); activePreset = 'normal'; closeModal(); renderInventory(); renderPresets(); toast('小口袋和对话，都回到最初啦。'); }
    if (action === 'sample') toast(`「${button.textContent.trim()}」· 点击反馈到了。`);
    if (action === 'open-bag') switchPage('inventory');
    if (action === 'demo-tab') { button.parentElement.querySelectorAll('button').forEach(item => { item.classList.toggle('selected', item === button); item.setAttribute('aria-pressed', String(item === button)); }); toast(`切到「${button.textContent}」啦。`); }
    if (['spend', 'heal', 'component-rest'].includes(action)) {
      const before = { ...state.vitals };
      if (action === 'spend') state.vitals.stamina = Math.max(0, state.vitals.stamina - 12);
      if (action === 'heal') state.vitals.hunger = Math.min(100, state.vitals.hunger + 20);
      if (action === 'component-rest') { state.vitals.stamina = Math.min(100, state.vitals.stamina + 35); state.vitals.health = Math.min(100, state.vitals.health + 10); toast('休息了一会儿，精神又好了一点。'); }
      markMotions(before); renderMeters();
    }
    if (action === 'mode-bag' || action === 'mode-chest') { state.mode = action === 'mode-chest' ? 'chest' : 'bag'; if (state.selected?.source === 'chest' && state.mode === 'bag') state.selected = { source: 'bag', index: 0 }; state.pages = { bag: 0, chest: 0 }; renderInventory(); }
    if (action === 'category') { state.category = button.dataset.category; state.pages = { bag: 0, chest: 0 }; renderInventory(); }
    if (action === 'grid-page') { state.pages[button.dataset.source] = Number(button.dataset.index); renderInventory(); }
    if (action === 'select-item') { state.selected = { source: button.dataset.source, index: Number(button.dataset.index) }; renderInventory(); }
    if (action === 'use') { const before = { ...state.vitals }; const result = demo.use(); markMotions(before); renderInventory(); toast(result.message); }
    if (action === 'transfer' && state.selected) { const result = demo.transfer(state.selected.source, state.selected.index); renderInventory(); toast(result.message); }
    if (action === 'take-all') {
      let count = 0; let message = '';
      state.chest.forEach((slot, index) => { if (!slot) return; const result = demo.transfer('chest', index, true); if (result.ok) count++; else message = result.message; });
      renderInventory(); toast(count ? `收好了 ${count} 组物品。${message}` : message || '宝箱已经空啦。');
    }
    if (action === 'discard' && demo.selectedItem()) { $('discard-copy').textContent = `${demo.selectedItem().name}会少一个。也可以先把它留在口袋里。`; openModal('discard-modal'); }
    if (action === 'confirm-discard') { demo.discard(); closeModal(); renderInventory(); toast('已经放下一个物品。'); }
    if (action === 'close-modal') closeModal();
    if (action === 'background-day' || action === 'background-night') { document.body.dataset.background = action.slice(11); document.querySelectorAll('.background-button').forEach(item => item.classList.toggle('selected', item === button)); }
  });
  $('effects-toggle').addEventListener('change', event => { document.body.dataset.effects = event.target.checked ? 'on' : 'off'; });
  document.addEventListener('keydown', event => {
    const modal = [$('backlog-modal'), $('discard-modal'), $('gal-settings-modal')].find(element => !element.hidden);
    if (modal) {
      if (event.key === 'Escape') { event.preventDefault(); closeModal(); }
      if (event.key === 'Tab') { const controls = [...modal.querySelectorAll('button:not([disabled]),input,select,textarea,a[href]')]; const first = controls[0]; const last = controls[controls.length - 1]; if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); } else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); } }
      return;
    }
    if (state.page === 'dialogue') gal.handleKey(event);
  });
  document.addEventListener('keyup', event => gal.keyUp(event));
  function fitCanvas() {
    const scale = $('viewport').clientWidth / 1448;
    $('scene').style.setProperty('--scale', scale);
    $('scale-label').textContent = `${Math.round(scale * 100)}% 等比预览`;
  }
  new ResizeObserver(fitCanvas).observe($('viewport'));
  document.addEventListener('visibilitychange', () => { if (document.hidden) gal.pause(); else if (state.page === 'dialogue') gal.enter(); });
  const initialPage = location.hash.slice(1);
  switchPage(['components', 'inventory', 'dialogue'].includes(initialPage) ? initialPage : 'dialogue');
  fitCanvas();
}
