// 2 · Depot contract board (desktop + phone). Block Y = 2400.
for (const n of [...page.children]) if (/^2[ab] ·/.test(n.name) || (n.type==='TEXT' && /^2[ab] ·/.test(n.characters))) n.remove();
const Y=2400;
{ // desktop
  const W=1920,H=1080; const f=G(page,'2a · Depot contract board — desktop',0,Y+80,W,H,'#0E1116',{clip:true}); frames.push(f.id);
  scene(f,W,H,'art: depot garage (graybox), pending',true); topbar(f);
  R(f,0,0,W,H,'#0E1116',{op:0.55,name:'scrim'});
  const board=G(f,'Pinboard',170,96,1580,900,'#6B4A2B',{r:10,stroke:'#3B2716',sw:10,fx:sh(10,30,0.6)});
  T(board,'TONIGHT\'S JOB','cond',30,'#F4ECD6',40,24,{ls:8});
  const tab=cTab.createInstance(); board.appendChild(tab); tab.x=40; tab.y=84; setText(tab,'label','WORK ORDER #0471');
  const wo=G(board,'Work order',40,128,880,730,'#E8C98A',{r:6,fx:sh()}); wo.topLeftRadius=0;
  T(wo,'HARLOW & FINCH LTD. — 4TH FLOOR OFFICES','cond',34,'#24211C',36,28);
  T(wo,'Full clearance before Monday\'s sale. By order of the bank.','type',22,'#24211C',36,80,{w:800});
  const rows=[['QUOTA','350 clearance (rubbish bags, dust bags, recycling)'],['SHIFT','7:00 on the clock. Clock out at the truck any time.'],['FINDER\'S FEE','Salvage you load is auctioned. The crew keeps the fee.'],['CREW','1–4 per truck. Board a truck bed to join.'],['NOTES','Building reported empty.']];
  rows.forEach((r,i)=>{ const y=140+i*96; R(wo,36,y,808,2,'#C9A564'); T(wo,r[0],'cond',22,'#5B4A2E',36,y+14,{ls:6}); T(wo,r[1],'type',24,'#24211C',250,y+14,{w:590}); });
  stamp(wo,'APPROVED',54,560,600,-7);
  sticky(board,'Lights on the 4th floor again?? — night guard',560,600,3);
  // last shift card (returning player)
  const card=G(board,'Last shift card',980,128,540,420,'#F4ECD6',{r:4,fx:sh()}); card.rotation=1.5;
  R(card,0,0,540,40,'#C8202F'); T(card,'YOUR LAST SHIFT — TRUCK 2','cond',22,'#F4ECD6',20,6,{ls:6});
  const L=[['Cleared','362 / 350'],['Finder\'s fee','+215'],['Times rehired','2'],['Salvage found','6 of 9']];
  L.forEach((l,i)=>{ T(card,l[0],'type',24,'#24211C',28,70+i*58); T(card,l[1],'cond',32,'#24211C',330,62+i*58,{w:180,align:'RIGHT'}); });
  stamp(card,'QUOTA MET',34,300,320,-6);
  R(board,1228,118,40,16,'#B0B4BA',{r:3,name:'paper clip'});
  const how=G(board,'How to start',980,600,540,150,'#0E1116',{r:6,op:0.85});
  T(how,'Stand in a truck bed to join its crew. Anyone aboard can press DEPART NOW.','type',22,'#E6F5E8',24,20,{w:492,lh:130});
  btn(board,'Secondary','CLOSE  [Esc]',1300,780,24);
  label('2a · Depot contract board — desktop',0,Y);
}
{ // phone
  const W=844,H=390,PY=Y+80+1080+140; const f=G(page,'2b · Depot contract board — phone',0,PY,W,H,'#0E1116',{clip:true}); frames.push(f.id);
  scene(f,W,H,'',true); topbar(f,true); R(f,0,0,W,H,'#0E1116',{op:0.55,name:'scrim'});
  const board=G(f,'Pinboard',48,62,W-96,H-62-20,'#6B4A2B',{r:8,stroke:'#3B2716',sw:5});
  const wo=G(board,'Work order',12,12,440,280,'#E8C98A',{r:6,fx:sh(4,8)});
  T(wo,'WORK ORDER #0471','cond',18,'#5B4A2E',14,8,{ls:4});
  T(wo,'Harlow & Finch — full clearance','cond',20,'#24211C',14,34);
  const rows=[['QUOTA','350 clearance'],['SHIFT','7:00 · clock out at the truck'],['FEE','Salvage → finder\'s fee'],['CREW','1–4 per truck']];
  rows.forEach((r,i)=>{ const y=74+i*44; R(wo,14,y,412,1,'#C9A564'); T(wo,r[0],'cond',15,'#5B4A2E',14,y+10,{ls:4}); T(wo,r[1],'type',16,'#24211C',96,y+10,{w:330}); });
  stamp(wo,'APPROVED',24,300,236,-7);
  const card=G(board,'Last shift card',466,12,228,200,'#F4ECD6',{r:4,fx:sh(4,8)});
  R(card,0,0,228,28,'#C8202F'); T(card,'LAST SHIFT','cond',16,'#F4ECD6',12,4,{ls:6});
  [['Cleared','362/350'],['Fee','+215'],['Rehired','2'],['Salvage','6/9']].forEach((l,i)=>{T(card,l[0],'type',15,'#24211C',12,38+i*38); T(card,l[1],'cond',18,'#24211C',120,34+i*38,{w:96,align:'RIGHT'});});
  btn(board,'Secondary','CLOSE',530,236,18);
  label('2b · Depot contract board — phone',0,PY-60,true);
}
return {frames};
