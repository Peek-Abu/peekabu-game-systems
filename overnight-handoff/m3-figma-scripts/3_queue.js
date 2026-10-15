// 3 · Queue pad status (desktop + phone). Block Y = 4400.
for (const n of [...page.children]) if (/^3[ab] ·/.test(n.name) || (n.type==='TEXT' && /^3[ab] ·/.test(n.characters))) n.remove();
const Y=4400;
const crew=['Sam','Alex','you',null];
{ const W=1920,H=1080; const f=G(page,'3a · Queue pad — desktop',0,Y+80,W,H,'#0E1116',{clip:true}); frames.push(f.id);
  scene(f,W,H,'art: truck bed with crew standing in it (graybox), pending'); topbar(f);
  R(f,560,330,800,300,'#2A3038',{r:12,stroke:'#8A8F98',sop:0.5,dash:[8,6],sw:2,name:'truck bed placeholder'});
  crew.forEach((c,i)=>{ if(!c) return; const x=640+i*220; R(f,x,400,90,200,'#3A4049',{r:20,name:'crew placeholder'}); const p=G(f,'Name tag',x-25,350,140,36,'#0E1116',{r:6,op:0.8}); T(p,c,'cond',20,c==='you'?'#FFE45C':'#E6F5E8',0,4,{w:140,align:'CENTER'}); });
  const card=G(f,'Queue card',(W-760)/2,H-48-256,760,256,'#F4ECD6',{r:6,fx:sh()});
  R(card,0,0,760,40,'#C8202F'); T(card,'TRUCK 2 — HARLOW & FINCH JOB','cond',22,'#F4ECD6',24,6,{ls:6});
  T(card,'CREW','type',20,'#24211C',28,58); T(card,'3 / 4','cond',64,'#24211C',28,80);
  crew.forEach((c,i)=>{ const x=200+i*92; R(card,x,70,80,80,c?'#24211C':null,{r:6,stroke:'#24211C',sw:2,dash:c?[]:[6,4],op:c?0.9:1}); T(card,c||'open','type',16,c?'#F4ECD6':'#8A7F6A',x,104,{w:80,align:'CENTER'}); });
  T(card,'DEPARTS IN','type',20,'#24211C',580,58); T(card,'0:11','mono',56,'#24211C',576,80);
  btn(card,'Go','DEPART NOW',200,164,26);
  T(card,'Step off the bed to leave · timer resets when someone joins','type',16,'#5B4A2E',440,176,{w:300});
  label('3a · Queue pad — desktop',0,Y);
}
{ const W=844,H=390,PY=Y+80+1080+140; const f=G(page,'3b · Queue pad — phone',0,PY,W,H,'#0E1116',{clip:true}); frames.push(f.id);
  scene(f,W,H,'art: truck bed + crew, pending'); topbar(f,true);
  R(f,48,12,W-96,H-32,null,{stroke:'#4C9BFF',sop:0.35,dash:[4,4],sw:1,name:'safe area (annotation)'});
  const card=G(f,'Queue card (compact)',(W-420)/2,10,420,104,'#F4ECD6',{r:6,fx:sh(4,8)});
  R(card,0,0,8,104,'#C8202F');
  T(card,'TRUCK 2 · CREW','type',15,'#24211C',22,8); T(card,'3 / 4','cond',40,'#24211C',22,28);
  crew.forEach((c,i)=>{ const x=130+i*40; R(card,x,40,32,32,c?'#24211C':null,{r:4,stroke:'#24211C',sw:2,dash:c?[]:[4,3]}); });
  T(card,'Sam · Alex · you','type',14,'#5B4A2E',130,78);
  T(card,'DEPARTS IN','type',15,'#24211C',300,8); T(card,'0:11','mono',36,'#24211C',300,30);
  E(f,60,230,120,null,{stroke:'#8A8F98',sop:0.35,dash:[5,5],sw:1,name:'Roblox thumbstick zone (keep clear)'});
  E(f,749,300,70,null,{stroke:'#8A8F98',sop:0.6,dash:[5,4],sw:2,name:'Roblox Jump (reserved)'}); T(f,'jump','type',14,'#8A8F98',767,326,{op:0.7});
  btn(f,'Go','DEPART NOW',500,290,22);
  T(f,'Step off the truck bed to leave','type',14,'#E6F5E8',500,262,{op:0.75});
  label('3b · Queue pad — phone',0,PY-60,true);
}
return {frames};
