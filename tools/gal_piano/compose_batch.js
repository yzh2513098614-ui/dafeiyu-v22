// Six separately written themes and developments. Node authors the event scores
// and editable MIDI; piano sound generation is performed entirely by Godot.
const fs = require('fs');
const path = require('path');
const major = [
 ['Cadd9',36,[48,55,60,62]], ['G/B',35,[47,55,59,62]],
 ['Am7',33,[45,52,55,60]], ['Fmaj7',41,[53,57,60,64]],
 ['Dm9',38,[50,57,60,64]], ['G6',43,[55,59,62,64]],
 ['C/E',40,[52,55,60,64]], ['Gsus–G',43,[55,60,62,67]]
];
const minor = [
 ['Am9',33,[45,52,59,60]], ['Fmaj7',41,[53,57,60,64]],
 ['Cmaj9',36,[48,55,59,62]], ['G6',43,[55,59,62,64]],
 ['Dm7',38,[50,57,60,65]], ['Am/E',40,[52,57,60,64]],
 ['Fadd9',41,[53,57,60,67]], ['E7',40,[52,56,59,62]]
];
const recipes = [
 {id:'gal_piano_daily',title:'海风课间',use:'日常 · 明亮流动',key:'D major',bpm:94,shift:2,wet:0.24,mode:'flow',harmony:major,
  theme:[
   'E5:0.5 G5:0.5 E5:0.75 D5:0.25 C5:1 D5:0.5 E5:0.5',
   'D5:0.75 B4:0.25 G4:0.5 B4:0.5 D5:1 G5:1',
   'E5:0.5 A5:0.5 G5:0.5 E5:0.5 C5:1 B4:0.5 A4:0.5',
   'A4:0.5 C5:0.5 E5:0.75 G5:0.25 E5:1 C5:1',
   'F5:0.5 E5:0.5 D5:0.75 C5:0.25 A4:1 D5:1',
   'B4:0.5 D5:0.5 E5:1 G5:0.75 F5:0.25 D5:1',
   'E5:0.75 G5:0.25 C6:1 B5:0.5 G5:0.5 E5:1',
   'D5:0.5 C5:0.5 B4:1 A4:0.5 B4:0.5 G4:0.5 R:0.5'],
  development:[
   'G5:0.5 C6:0.5 B5:0.75 G5:0.25 E5:1 G5:1',
   'B5:0.5 A5:0.5 G5:1 F5:0.5 D5:0.5 G5:1',
   'A5:1 C6:0.5 B5:0.5 A5:0.75 G5:0.25 E5:1',
   'A5:0.75 G5:0.25 E5:0.5 C5:0.5 F5:1 E5:1',
   'F5:0.5 A5:0.5 G5:1 F5:0.5 E5:0.5 D5:1',
   'D5:0.5 G5:0.5 B5:1 A5:0.5 G5:0.5 D5:1',
   'E5:1 G5:0.5 E5:0.5 D5:1 C5:1',
   'A4:0.5 B4:0.5 D5:1 C5:0.5 B4:0.5 G4:0.5 R:0.5']},
 {id:'gal_piano_indoor',title:'窗边的热茶',use:'室内 · 温柔对话',key:'F major',bpm:88,shift:5,wet:0.29,mode:'gentle',harmony:[major[0],major[3],major[6],major[2],major[4],major[5],major[0],major[7]],
  theme:[
   'G4:1 E4:0.5 G4:0.5 C5:1 B4:0.5 G4:0.5',
   'A4:1 G4:0.5 E4:0.5 F4:0.75 A4:0.25 C5:1',
   'G4:0.5 C5:0.5 B4:1 G4:0.5 E4:0.5 G4:1',
   'A4:1 C5:0.5 E5:0.5 D5:0.75 C5:0.25 A4:1',
   'F4:1 A4:0.5 C5:0.5 D5:1 C5:0.5 A4:0.5',
   'B4:0.75 A4:0.25 G4:1 D5:1 B4:1',
   'C5:1 B4:0.5 G4:0.5 E4:1 G4:1',
   'A4:0.5 G4:0.5 D4:1 B4:0.75 A4:0.25 G4:0.5 R:0.5'],
  development:[
   'E5:1 G5:0.5 E5:0.5 D5:1 C5:1',
   'C5:0.5 E5:0.5 A5:1 G5:0.5 E5:0.5 C5:1',
   'B4:0.5 C5:0.5 E5:1 G5:1 E5:1',
   'E5:0.75 D5:0.25 C5:0.5 A4:0.5 B4:1 C5:1',
   'D5:1 F5:0.5 E5:0.5 D5:0.5 C5:0.5 A4:1',
   'B4:0.5 D5:0.5 G5:1 E5:0.5 D5:0.5 B4:1',
   'C5:1 G4:1 E4:0.5 G4:0.5 C5:1',
   'B4:1 A4:0.5 G4:0.5 D4:1 G4:0.5 R:0.5']},
 {id:'gal_piano_night',title:'灯塔替我记得',use:'夜晚 · 克制的思念',key:'D# minor',bpm:86,shift:6,wet:0.31,mode:'gentle',harmony:minor,
  theme:[
   'A4:1 E5:0.5 C5:0.5 B4:1 A4:0.5 R:0.5',
   'C5:0.75 A4:0.25 G4:1 E4:0.5 F4:0.5 A4:1',
   'G4:0.5 C5:0.5 E5:1 D5:0.75 B4:0.25 C5:1',
   'B4:1 D5:0.5 G5:0.5 F5:0.5 D5:0.5 B4:1',
   'A4:1 F5:0.5 E5:0.5 D5:1 C5:0.5 A4:0.5',
   'B4:0.75 C5:0.25 E5:1 C5:0.5 A4:0.5 E4:1',
   'A4:0.5 C5:0.5 G5:1 E5:1 C5:1',
   'B4:1 G#4:0.5 E4:0.5 B4:1 G#4:0.5 R:0.5'],
  development:[
   'E5:1 A5:0.5 G5:0.5 E5:0.75 C5:0.25 B4:1',
   'A4:0.5 C5:0.5 E5:1 G5:0.75 E5:0.25 C5:1',
   'G5:1 E5:0.5 D5:0.5 C5:1 B4:1',
   'D5:0.5 G5:0.5 B5:1 A5:0.5 G5:0.5 D5:1',
   'A5:1 G5:0.5 F5:0.5 E5:1 D5:1',
   'E5:0.75 C5:0.25 B4:1 A4:0.5 C5:0.5 E5:1',
   'C5:1 A4:0.5 G4:0.5 F4:1 A4:1',
   'G#4:1 B4:0.5 D5:0.5 B4:1 E4:0.5 R:0.5']},
 {id:'gal_piano_rain',title:'雨声里的约定',use:'回忆 · 雨夜告白',key:'A minor',bpm:90,shift:0,wet:0.34,mode:'flow',harmony:[minor[0],minor[2],minor[1],minor[3],minor[4],minor[5],minor[6],minor[7]],
  theme:[
   'E5:0.75 C5:0.25 B4:0.5 A4:0.5 C5:1 E5:1',
   'G5:0.5 E5:0.5 D5:0.75 C5:0.25 B4:1 G4:1',
   'A4:0.75 C5:0.25 E5:1 D5:0.5 C5:0.5 A4:1',
   'D5:0.5 G5:0.5 F5:1 D5:0.75 B4:0.25 G4:1',
   'F5:1 E5:0.5 D5:0.5 C5:1 A4:1',
   'E5:0.75 C5:0.25 A4:0.5 B4:0.5 C5:1 E5:1',
   'G5:1 E5:0.5 C5:0.5 A4:1 C5:1',
   'B4:0.75 G#4:0.25 E4:1 G#4:0.5 B4:0.5 D5:0.5 R:0.5'],
  development:[
   'A5:1 G5:0.5 E5:0.5 C5:0.5 B4:0.5 A4:1',
   'G5:0.75 E5:0.25 C6:1 B5:0.5 G5:0.5 E5:1',
   'A5:0.5 G5:0.5 E5:1 C5:0.75 A4:0.25 C5:1',
   'B5:1 A5:0.5 G5:0.5 F5:1 D5:1',
   'F5:0.75 E5:0.25 D5:0.5 F5:0.5 A5:1 G5:1',
   'E5:1 C5:0.5 B4:0.5 A4:1 E5:1',
   'C5:0.5 E5:0.5 G5:1 E5:0.75 C5:0.25 A4:1',
   'B4:1 D5:0.5 B4:0.5 G#4:1 E4:0.5 R:0.5']},
 {id:'gal_piano_tension',title:'潮汐之前',use:'紧张 · 决意与交战',key:'B minor',bpm:108,shift:2,wet:0.18,mode:'pulse',harmony:[minor[0],minor[7],minor[4],minor[7],minor[1],minor[2],minor[4],minor[7]],
  theme:[
   'A4:0.5 E5:0.5 B4:0.5 C5:0.5 A4:1 E5:0.5 R:0.5',
   'G#4:0.5 B4:0.5 D5:0.5 E5:0.5 D5:1 B4:0.5 G#4:0.5',
   'A4:0.5 D5:0.5 F5:0.75 E5:0.25 D5:1 A4:1',
   'B4:0.5 G#4:0.5 E4:0.5 G#4:0.5 B4:1 D5:1',
   'A4:0.75 C5:0.25 F5:0.5 E5:0.5 C5:1 A4:1',
   'G4:0.5 C5:0.5 E5:0.5 G5:0.5 E5:1 C5:1',
   'F5:0.5 E5:0.5 D5:1 A4:0.5 C5:0.5 D5:1',
   'D5:0.5 B4:0.5 G#4:0.5 E4:0.5 B4:1 G#4:0.5 R:0.5'],
  development:[
   'E5:0.5 A5:0.5 G5:0.5 E5:0.5 C5:1 A4:1',
   'B5:0.5 G#5:0.5 E5:0.5 D5:0.5 B4:1 E5:1',
   'F5:0.5 A5:0.5 D6:0.75 C6:0.25 A5:1 F5:1',
   'G#5:0.5 B5:0.5 D6:0.5 B5:0.5 G#5:1 E5:1',
   'A5:1 G5:0.5 F5:0.5 E5:0.5 C5:0.5 A4:1',
   'G5:0.5 E5:0.5 C5:1 B4:0.5 C5:0.5 E5:1',
   'F5:0.75 E5:0.25 D5:0.5 A4:0.5 D5:1 F5:1',
   'D5:0.5 B4:0.5 G#4:1 B4:0.5 D5:0.5 E5:0.5 R:0.5']},
 {id:'gal_piano_hope',title:'明天仍有晴空',use:'释怀 · 归来与结尾',key:'F# major',bpm:96,shift:6,wet:0.28,mode:'flow',harmony:[major[3],major[5],major[6],major[2],major[4],major[5],major[0],major[7]],
  theme:[
   'A4:0.5 C5:0.5 F5:1 E5:0.5 C5:0.5 A4:1',
   'B4:0.5 D5:0.5 G5:0.75 E5:0.25 D5:1 B4:1',
   'G4:0.5 C5:0.5 E5:1 G5:0.5 E5:0.5 C5:1',
   'E5:1 A5:0.5 G5:0.5 E5:0.75 C5:0.25 A4:1',
   'A4:0.5 D5:0.5 F5:1 E5:0.5 D5:0.5 C5:1',
   'B4:0.75 D5:0.25 E5:0.5 G5:0.5 F5:1 D5:1',
   'E5:0.5 G5:0.5 C6:1 B5:0.5 G5:0.5 E5:1',
   'D5:1 B4:0.5 A4:0.5 G4:1 D5:0.5 R:0.5'],
  development:[
   'C6:1 A5:0.5 G5:0.5 F5:1 E5:1',
   'B5:0.75 A5:0.25 G5:0.5 E5:0.5 D5:1 G5:1',
   'G5:0.5 C6:0.5 B5:1 G5:0.5 E5:0.5 C5:1',
   'A5:1 G5:0.5 E5:0.5 C5:0.5 E5:0.5 A5:1',
   'A5:0.5 G5:0.5 F5:1 E5:0.5 D5:0.5 C5:1',
   'D5:0.5 G5:0.5 B5:1 A5:0.75 G5:0.25 D5:1',
   'E5:1 D5:0.5 C5:0.5 G4:1 C5:1',
   'B4:0.75 A4:0.25 G4:1 D5:1 G4:0.5 R:0.5']}
];
function pitch(name) {
 if(name==='R') return -1;
 const m=name.match(/^([A-G])(#|b)?([0-8])$/);
 if(!m) throw new Error('Bad note '+name);
 return (Number(m[3])+1)*12+{C:0,D:2,E:4,F:5,G:7,A:9,B:11}[m[1]]+(m[2]==='#'?1:m[2]==='b'?-1:0);
}
function phrase(s) {
 const rows=s.split(' ').map(t=>{const [n,d]=t.split(':');return [pitch(n),Number(d)];});
 if(Math.abs(rows.reduce((s,n)=>s+n[1],0)-4)>1e-6) throw new Error('Not four beats: '+s);
 return rows;
}
function compose(r, index) {
 const notes=[], bars=[];
 let t=0.16, event=0;
 const add=(p,time,duration,velocity,role,beat,release)=>{
  notes.push({midi:p+r.shift,time:Math.max(0,time+0.005*Math.sin((event++ +index*29)*1.618)),duration,
   velocity:Math.max(22,Math.min(94,velocity+1.8*Math.sin(event*2.31))),role,beat,release});
 };
 const playPhrase=(rows,bar,time,spb,level)=>{
  let beat=0;
  for(const [p,d] of rows) {
   if(p>=0) add(p,time+beat*spb,d*spb*0.94,level+3*Math.sin(beat*Math.PI/4)-(beat>=3?2:0),'melody',bar*4+beat,r.mode==='pulse'?0.24:0.50);
   beat+=d;
  }
 };
 for(let bar=0;bar<32;bar++) {
  const ending=bar>=28, intro=bar<4, develop=bar>=20&&bar<28;
  const bpm=r.bpm*(bar===30?0.94:bar===31?0.85:1), spb=60/bpm;
  const h=ending?(bar===31?[r.key.includes('minor')?'Am(add9)':'Cmaj9',r.key.includes('minor')?33:36,r.key.includes('minor')?[45,52,59,60]:[48,55,59,64]]:r.harmony[[0,1,7][bar-28]]):r.harmony[intro?[0,1,2,7][bar]:(bar-4)%8];
  bars.push({bar:bar+1,time:t,duration:4*spb,bpm,chord:h[0]+' (transpose '+r.shift+')'});
  const base=intro||ending?35:develop?49:43;
  add(h[1],t,spb*(r.mode==='pulse'?1.7:3.35),base+4,'bass',bar*4,r.mode==='pulse'?0.33:0.60);
  if(r.mode==='pulse'&&!intro&&!ending) add(h[1]+12,t+2*spb,spb*0.70,base,'bass',bar*4+2,0.23);
  const count=intro||ending||r.mode==='gentle'&&!develop?4:8;
  const order=bar>=12&&bar<20?[0,2,1,3,2,1,3,1]:[0,1,2,1,3,2,1,2];
  if(bar!==31) for(let k=0;k<count;k++) {
   let p=h[2][order[k]];
   if(h[0].includes('Gsus')&&k>=count/2&&p===60) p=59;
   add(p,t+k*4/count*spb+0.012,spb*(r.mode==='pulse'?0.25:0.70),base+(k%4===0?2:-2),'arpeggio',bar*4+k*4/count,r.mode==='pulse'?0.22:0.64);
  }
  else h[2].forEach((p,k)=>add(p,t+k*0.014,spb*3.6,32-k,'arpeggio',bar*4,0.72));
  // Quiet upper broken tones connect phrases, with a drop of register in A.
  if(!ending&&r.mode!=='pulse') for(let k=0;k<(r.mode==='gentle'?2:4);k++) {
   let p=h[2][[3,2,1,2][k]]+(intro?24:12);
   while(p+r.shift>90) p-=12;
   add(p,t+(k*0.5+0.5)*spb,spb*0.36,intro?41:34,'ornament',bar*4+k*0.5+0.5,0.36);
  }
  if(intro) {
   const p=phrase(r.theme[bar*2]).filter(n=>n[0]>=0);
   add(p[0][0],t+2*spb,spb*0.92,55,'melody',bar*4+2,0.5);
   add(p[1][0],t+3*spb,spb*0.90,51,'melody',bar*4+3,0.5);
  } else if(ending) {
   const tonic=r.key.includes('minor')?69:72;
   const rows=bar===31?[[tonic+4,1],[tonic+2,1],[tonic,2]]:phrase(r.theme[[0,4,7][bar-28]]);
   // Minor final phrase uses a minor third above the tonic.
   if(bar===31&&r.key.includes('minor')) rows[0][0]=tonic+3;
   playPhrase(rows,bar,t,spb,58-(bar-28)*4);
  } else {
   const rows=phrase(develop?r.development[bar-20]:r.theme[(bar-4)%8]);
   if(bar>=12&&bar<20) {
    // Reprise changes its final note and adds a quiet octave shadow on long notes.
    rows.forEach((row,k)=>{if(k===rows.length-1&&row[0]>=0&&row[1]>=1&&bar%2===0&&row[0]+12+r.shift<=90) row[0]+=12;});
    if(bar%2===0) add(rows.find(n=>n[0]>=0)[0]-12,t,spb*1.1,36,'arpeggio',bar*4,0.55);
   }
   playPhrase(rows,bar,t,spb,develop?82:bar>=12?75:71);
  }
  t+=4*spb;
 }
 notes.sort((a,b)=>a.time-b.time||a.midi-b.midi);
 return {id:r.id,title:r.title,use:r.use,key:r.key,bpm:r.bpm,beats_per_bar:4,bar_count:32,room_wet:r.wet,pedal:r.mode!=='pulse',
  sections:[{name:'引子',start:0,end:4},{name:'主题',start:4,end:12},{name:'变奏',start:12,end:20},{name:'发展',start:20,end:28},{name:'尾声',start:28,end:32}],
  bars,notes,music_duration:t,duration:t+3.8};
}
function vlq(n) {n=Math.max(0,Math.round(n));const bytes=[n&127];while((n>>=7)>0) bytes.unshift((n&127)|128);return Buffer.from(bytes);}
function midi(score) {
 const ppq=480, events=[{tick:0,data:Buffer.from([0xff,0x58,4,4,2,24,8])},{tick:0,data:Buffer.from([0xc0,0])}];
 const tempo=Math.round(60000000/score.bpm);
 events.push({tick:0,data:Buffer.from([0xff,0x51,3,(tempo>>16)&255,(tempo>>8)&255,tempo&255])});
 const title=Buffer.from(score.title,'utf8');events.push({tick:0,data:Buffer.concat([Buffer.from([255,3]),vlq(title.length),title])});
 const scale=ppq*score.bpm/60;
 if(score.pedal) {
  for(const b of score.bars) {
   events.push({tick:Math.max(0,Math.round((b.time-0.03)*scale)),data:Buffer.from([0xb0,64,0])});
   events.push({tick:Math.round((b.time+0.06)*scale),data:Buffer.from([0xb0,64,80])});
  }
  events.push({tick:Math.round(score.music_duration*scale),data:Buffer.from([0xb0,64,0])});
 }
 for(const n of score.notes) {
  events.push({tick:Math.round(n.time*scale),data:Buffer.from([0x90,n.midi,Math.round(n.velocity)])});
  events.push({tick:Math.round((n.time+n.duration)*scale),data:Buffer.from([0x80,n.midi,0])});
 }
 events.sort((a,b)=>a.tick-b.tick||(a.data[0]===0x80?-1:b.data[0]===0x80?1:0));
 let previous=0;const chunks=[];
 for(const e of events) {chunks.push(vlq(e.tick-previous),e.data);previous=e.tick;}
 chunks.push(Buffer.from([0,255,47,0]));const track=Buffer.concat(chunks);
 const header=Buffer.alloc(14);header.write('MThd');header.writeUInt32BE(6,4);header.writeUInt16BE(0,8);header.writeUInt16BE(1,10);header.writeUInt16BE(ppq,12);
 const trackHeader=Buffer.alloc(8);trackHeader.write('MTrk');trackHeader.writeUInt32BE(track.length,4);
 return Buffer.concat([header,trackHeader,track]);
}
const root=path.resolve(__dirname,'../..'), midiDir=path.join(root,'assets/music/midi');
fs.mkdirSync(midiDir,{recursive:true});
const scores=recipes.map(compose);
for(const s of scores) {
 if(s.notes.some(n=>n.midi<0||n.midi>127)) throw new Error('MIDI range '+s.id);
 fs.writeFileSync(path.join(midiDir,s.id+'.mid'),midi(s));
 console.log('COMPOSED '+s.id+' '+s.title+' '+s.key+' '+s.bpm+' BPM '+s.notes.length+' notes '+s.duration.toFixed(2)+' seconds');
}
fs.writeFileSync(path.join(__dirname,'batch_scores.json'),JSON.stringify(scores,null,2)+'\n');
