'use strict';

function createGalStory() {
  const opening = [
    { speaker: '大肥鱼', text: '你来啦。今天的海风刚刚好，要不要一起去港口走走？', portrait: 'happy' },
    { speaker: '旁白', text: '最后一班渡船缓缓靠岸。夕阳落在她蓝色的发梢上，把海风也染得柔软了一点。', portrait: 'happy' },
    { speaker: '大肥鱼', text: '我把补给装进了小口袋。海盐饼、热茶，还有一张很认真写好的便签。', portrait: 'talk' },
    { speaker: '大肥鱼', text: '不用急着找完所有答案。先照顾好自己，再慢慢看看这个小世界。', portrait: 'think' },
    { speaker: '大肥鱼', text: '其实……便签上也没有写什么特别厉害的话。只是想提醒你，今天也有人在这里等你。', portrait: 'shy' },
    { speaker: '大肥鱼', text: '那么，今天想先去哪里？我陪你一起。', portrait: 'happy', choices: true }
  ];
  const choices = [
    { label: '先去咖啡馆补给', lines: [
      { speaker: '大肥鱼', text: '好呀，先吃一口，再慢慢思考。咖啡馆窗边的位置，我已经替你留好了。', portrait: 'happy' },
      { speaker: '旁白', text: '她把小口袋抱得更紧了些。远处的灯亮起来，像是替这个约定点了一个小小的头。', portrait: 'happy' },
      { speaker: '大肥鱼', text: '等热茶端上来，再告诉我今天发生的事吧。我会好好听的。', portrait: 'shy' }
    ] },
    { label: '去码头看看海', lines: [
      { speaker: '大肥鱼', text: '那就往海风吹来的方向走。看着船慢慢靠岸，也算今天的一点小进度。', portrait: 'talk' },
      { speaker: '旁白', text: '你们在栏杆边并肩站了一会儿。海面很宽，今天那些着急的事，忽然都变得很小。', portrait: 'think' },
      { speaker: '大肥鱼', text: '你看，船总会找到靠岸的地方。我们也会的，对吧？', portrait: 'happy' }
    ] },
    { label: '在这里聊一会儿', lines: [
      { speaker: '大肥鱼', text: '当然可以。问题不会跑掉，我们就在这片海风里，多待一会儿。', portrait: 'shy' },
      { speaker: '旁白', text: '她没有再催着你往前走。只是站在你身边，留出一小段可以安心沉默的时间。', portrait: 'shy' },
      { speaker: '大肥鱼', text: '想说什么都可以。就算只是说今天的云很好看，我也很想听。', portrait: 'happy' }
    ] }
  ];
  const state = { cursor: 0, branch: null, entries: [] };
  const clone = value => JSON.parse(JSON.stringify(value));
  const script = () => opening.concat(state.branch === null ? [] : choices[state.branch].lines);
  const current = () => script()[state.cursor];
  function record() { state.entries.push({ ...current(), cursor: state.cursor, branch: state.branch }); }
  function reset() { state.cursor = 0; state.branch = null; state.entries = []; record(); }
  function next() {
    if (current().choices && state.branch === null || state.cursor >= script().length - 1) return false;
    state.cursor++; record(); return true;
  }
  function choose(index) {
    if (!current().choices || state.branch !== null) return false;
    state.entries.push({ speaker: '你', text: choices[index].label, reply: true, cursor: state.cursor, branch: null });
    state.branch = index; state.cursor++; record(); return true;
  }
  function jumpChoices() { reset(); while (state.cursor < opening.length - 1) next(); }
  function rollback(index) {
    const entry = state.entries[index];
    if (!entry || entry.reply) return false;
    state.cursor = entry.cursor; state.branch = entry.branch;
    state.entries = state.entries.slice(0, index + 1); return true;
  }
  function load(snapshot) { Object.assign(state, clone(snapshot)); }
  reset();
  return { state, choices, current, next, choose, jumpChoices, rollback, reset, load, save: () => clone(state), length: () => script().length, atEnd: () => state.branch !== null && state.cursor === script().length - 1 };
}

if (typeof module !== 'undefined' && module.exports) module.exports = { createGalStory };

function createGalDialogue({ data, $, escape, icon, toast, openModal, closeModal }) {
  const story = createGalStory();
  const settings = { speed: 3, wait: 2, font: 30, opacity: 94 };
  const speedLabels = ['即显', '很慢', '舒缓', '标准', '轻快', '很快'];
  const characterDelays = [0, 65, 45, 30, 20, 12];
  let typeTimer = null;
  let playbackTimer = null;
  let count = 0;
  let automatic = false;
  let skipping = false;
  let heldSkip = false;
  let active = false;
  let uiHidden = false;
  let quickSlot = null;
  let lastPortrait = '';
  const chars = () => Array.from(story.current().text);
  const complete = () => count >= chars().length;
  const isModalOpen = () => !$('backlog-modal').hidden || !$('gal-settings-modal').hidden;
  function cancelTimers() { clearTimeout(typeTimer); clearTimeout(playbackTimer); typeTimer = null; playbackTimer = null; }
  function renderControls() {
    $('auto-button').classList.toggle('selected', automatic);
    $('auto-button').setAttribute('aria-pressed', String(automatic));
    $('skip-button').classList.toggle('selected', skipping);
    $('skip-button').setAttribute('aria-pressed', String(skipping));
    $('quick-load-button').disabled = !quickSlot;
    $('playback-status').hidden = !automatic && !skipping;
    $('playback-status').textContent = skipping ? 'SKIP ▸▸' : 'AUTO ▸';
    $('continue-button').hidden = complete() && Boolean(story.current().choices);
    $('continue-button').innerHTML = story.atEnd() && complete() ? '回到开头<span>↻</span>' : '<span>◆</span>';
    $('continue-button').setAttribute('aria-label', complete() ? story.atEnd() ? '回到开头' : '继续对话' : '显示完整对白');
  }
  function stopModes() { automatic = false; skipping = false; heldSkip = false; clearTimeout(playbackTimer); playbackTimer = null; renderControls(); }
  function renderChoices() {
    const visible = complete() && Boolean(story.current().choices);
    $('reply-options').hidden = !visible; $('choice-veil').hidden = !visible;
    $('reply-options').innerHTML = visible ? '<p class="choice-heading">把这一刻，交给你的选择。</p>' + story.choices.map((choice, index) => `<button class="sticker-button reply-button" data-action="reply" data-index="${index}"><span class="reply-number">0${index + 1}</span>${escape(choice.label)}${icon('arrow')}</button>`).join('') : '';
  }
  function schedulePlayback() {
    clearTimeout(playbackTimer); playbackTimer = null;
    if (!active || !complete() || uiHidden || isModalOpen()) return;
    if (story.current().choices || story.atEnd()) { stopModes(); return; }
    if (automatic || skipping) playbackTimer = setTimeout(() => {
      playbackTimer = null;
      story.next(); showLine(skipping);
    }, skipping ? 170 : settings.wait * 1000);
  }
  function finishTyping() {
    clearTimeout(typeTimer); typeTimer = null; count = chars().length;
    $('dialogue-text').textContent = story.current().text;
    $('dialogue-text').classList.remove('typing');
    $('dialogue-announcement').textContent = `${story.current().speaker}：${story.current().text}`;
    renderChoices(); renderControls(); schedulePlayback();
  }
  function typeNext() {
    if (!active || uiHidden || isModalOpen()) return;
    const text = chars();
    count = Math.min(count + 1, text.length);
    $('dialogue-text').textContent = text.slice(0, count).join('');
    if (count === text.length) { finishTyping(); return; }
    const punctuationPause = /[。！？…]/.test(text[count - 1]) ? 210 : /[，、；]/.test(text[count - 1]) ? 95 : 0;
    typeTimer = setTimeout(typeNext, characterDelays[settings.speed] + punctuationPause);
  }
  function setPortrait(key) {
    const portrait = $('portrait');
    if (lastPortrait !== key) {
      const previous = $('portrait-previous');
      previous.src = portrait.src || data.assets[key];
      previous.hidden = true; void previous.offsetWidth; previous.hidden = false;
      portrait.classList.remove('portrait-enter');
      portrait.src = data.assets[key]; void portrait.offsetWidth; portrait.classList.add('portrait-enter');
      lastPortrait = key;
    }
    portrait.style.setProperty('--speaker-brightness', story.current().speaker === '旁白' ? '.88' : '1');
  }
  function showLine(instant = false) {
    cancelTimers(); count = 0;
    const line = story.current();
    $('speaker-name').textContent = line.speaker;
    $('dialogue-box').classList.toggle('narration', line.speaker === '旁白');
    $('dialogue-progress').textContent = `第一章 · ${String(story.state.cursor + 1).padStart(2, '0')} / ${String(story.length()).padStart(2, '0')}`;
    $('dialogue-text').textContent = '';
    setPortrait(line.portrait); renderChoices(); renderControls();
    if (instant || settings.speed === 0 || skipping) finishTyping();
    else { $('dialogue-text').classList.add('typing'); typeNext(); }
  }
  function advance() {
    if (uiHidden) { hideUI(false); return; }
    if (!complete()) { finishTyping(); return; }
    if (story.current().choices) return;
    if (story.atEnd()) { stopModes(); story.reset(); showLine(); return; }
    story.next(); showLine(skipping);
  }
  function setAuto(on) {
    automatic = on; skipping = false; heldSkip = false;
    clearTimeout(playbackTimer); renderControls(); schedulePlayback();
  }
  function setSkip(on) {
    automatic = false; skipping = on;
    clearTimeout(playbackTimer); renderControls();
    if (on) finishTyping();
  }
  function hideUI(hidden) {
    if (hidden) { finishTyping(); stopModes(); }
    uiHidden = hidden;
    $('screen-dialogue').classList.toggle('dialogue-ui-hidden', hidden);
    $('restore-ui').hidden = !hidden;
    if (!hidden) renderControls();
  }
  function showBacklog() {
    finishTyping(); stopModes(); cancelTimers();
    $('backlog-list').innerHTML = story.state.entries.map((entry, index) => `<div class="backlog-entry ${entry.reply ? 'reply-entry' : ''}"><b>${escape(entry.speaker)}</b><p>${escape(entry.text)}</p>${entry.reply ? '' : `<button class="backlog-return" data-action="gal-rollback" data-index="${index}">回到这句 ↶</button>`}</div>`).join('');
    openModal('backlog-modal');
  }
  function quickSave() {
    quickSlot = story.save(); renderControls();
    toast(`记住了 · ${String(story.state.cursor + 1).padStart(2, '0')} / ${String(story.length()).padStart(2, '0')} · ${story.current().speaker}`);
  }
  function quickLoad() {
    if (!quickSlot) return;
    stopModes(); hideUI(false); story.load(quickSlot); showLine(true);
    toast('回到刚才记住的这一句。');
  }
  function pause() { cancelTimers(); stopModes(); active = false; }
  function enter() { active = true; hideUI(false); showLine(); }
  function resume() {
    if (!active || uiHidden || isModalOpen()) return;
    if (!complete()) typeNext(); else schedulePlayback();
  }
  function reset() { stopModes(); hideUI(false); quickSlot = null; story.reset(); showLine(!active); }
  function preset(name) {
    stopModes(); hideUI(false);
    if (name === 'backlog') { showBacklog(); return; }
    story.reset();
    if (name === 'choices') { story.jumpChoices(); showLine(true); return; }
    if (name === 'narration') story.next();
    showLine(name === 'hidden-ui');
    if (name === 'automatic') setAuto(true);
    if (name === 'hidden-ui') hideUI(true);
  }
  function handle(action, button) {
    if (action === 'next') advance();
    else if (action === 'skip') setSkip(!skipping);
    else if (action === 'auto') setAuto(!automatic);
    else if (action === 'reply') {
      stopModes(); story.choose(Number(button.dataset.index)); showLine();
    } else if (action === 'backlog') showBacklog();
    else if (action === 'quick-save') quickSave();
    else if (action === 'quick-load') quickLoad();
    else if (action === 'hide-ui') hideUI(true);
    else if (action === 'restore-ui') hideUI(false);
    else if (action === 'gal-settings') { cancelTimers(); stopModes(); openModal('gal-settings-modal'); }
    else if (action === 'gal-rollback') { story.rollback(Number(button.dataset.index)); closeModal(); showLine(true); }
    else return false;
    return true;
  }
  function handleKey(event) {
    if (!active || isModalOpen() || event.repeat || event.target.closest('input,textarea,select')) return false;
    if (event.key === 'Control') { if (!skipping) { heldSkip = true; setSkip(true); } return true; }
    const key = event.key.toLowerCase();
    if (key === 'h') hideUI(!uiHidden);
    else if (key === 'q') quickSave();
    else if (key === 'l') quickLoad();
    else if (key === 'a') setAuto(!automatic);
    else if ((event.code === 'Space' || event.key === 'Enter') && !event.target.closest('button,a')) advance();
    else return false;
    event.preventDefault(); return true;
  }
  function keyUp(event) { if (event.key === 'Control' && heldSkip) { heldSkip = false; setSkip(false); } }
  function applySettings() {
    $('scene').style.setProperty('--gal-font', `${settings.font}px`);
    $('scene').style.setProperty('--gal-opacity', settings.opacity / 100);
    $('gal-speed-value').textContent = speedLabels[settings.speed];
    $('gal-wait-value').textContent = `${settings.wait} 秒`;
    $('gal-font-value').textContent = settings.font;
    $('gal-opacity-value').textContent = `${settings.opacity}%`;
  }
  for (const [id, key] of [['gal-text-speed', 'speed'], ['gal-auto-wait', 'wait'], ['gal-font-size', 'font'], ['gal-box-opacity', 'opacity']]) {
    $(id).addEventListener('input', event => { settings[key] = Number(event.target.value); applySettings(); if (key === 'speed' && settings.speed === 0) finishTyping(); });
  }
  $('screen-dialogue').addEventListener('click', event => {
    if (event.target.closest('button,input,a,.gal-quick-menu,.reply-options,.dialogue-place')) return;
    if (active && !isModalOpen()) advance();
  });
  applySettings(); showLine(true);
  return { pause, enter, resume, reset, preset, handle, handleKey, keyUp };
}
