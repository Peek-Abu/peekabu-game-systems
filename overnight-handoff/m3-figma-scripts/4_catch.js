// 4 · Catch overlay (desktop: scare, spectate, Rehired card; phone: spectate, Rehired card). Block Y = 6400.
for (const n of [...page.children]) if (/^4[a-e] ·/.test(n.name) || (n.type==='TEXT' && /^4[a-e] ·/.test(n.characters))) n.remove();
const Y=6400;
const rehiredCard=(parent,x,y,w,phone)=>{ const s=w/760; const h=Math.round(600*s);
  const c=G(parent,'Rehired card',x,y,w,h,'#F4ECD6',{r:4,fx:sh(10,30,0.6)});
  R(c,0,0,w,Math.round(48*s),'#24211C'); T(c,'HARLOW & FINCH — HUMAN RESOURCES','cond',phone?14:22,'#F4ECD6',Math.round(24*s),Math.round(10*s),{ls:6});
  T(c,'NOTICE OF RE-EMPLOYMENT','type',phone?15:22,'#5B4A2E',Math.round(40*s),Math.round(76*s));
  T(c,'Rehired.','type',phone?56:104,'#24211C',Math.round(36*s),Math.round(108*s),{name:'headline'});
  const lines=phone?['Caught at 3:42 by Mr. Harlow','Dropped: Monitor, Plaque (where you landed)']:['Name: you','Employment ended: 3:42 (caught by Mr. Harlow)','Re-hired: 3:50, no questions asked','Dropped: Monitor, Plaque — left where you landed'];
  lines.forEach((l,i)=>{ const ly=Math.round((phone?250:270)*s)+i*(phone?24:44); R(c,Math.round(40*s),ly+(phone?20:34),w-Math.round(80*s),1,'#C9B994'); T(c,l,'type',phone?15:22,'#24211C',Math.round(40*s),ly); });
  stamp(c,'REHIRED',phone?30:60,Math.round(440*s),Math.round(120*s),8);
  T(c,'Respawning at the loading bay…','type',phone?14:20,'#8A7F6A',Math.round(40*s),h-Math.round(phone?34:50)*1);
  return c; };
{ const W=1920,H=1080;
  // 4a scare beat
  const a=G(page,'4a · Catch — scare beat (0.6 s, desktop)',0,Y+80,W,H,'#050506',{clip:true}); frames.push(a.id);
  const v=R(a,0,0,W,H,null,{name:'vignette'}); v.fills=[{type:'GRADIENT_RADIAL',gradientTransform:[[1,0,0],[0,1,0]],gradientStops:[{position:0,color:{r:0.2,g:0.03,b:0.03,a:0.0}},{position:1,color:{r:0.35,g:0.02,b:0.02,a:0.9}}]}];
  R(a,(W-640)/2,(H-640)/2,640,640,'#1A1D22',{r:12,stroke:'#8A8F98',sop:0.6,dash:[10,8],sw:2,name:'art placeholder'});
  T(a,'art: Mr. Harlow stretched-grin close-up (kid-safe, no gore) — Flux, pending','type',24,'#AEB3BA',(W-560)/2,500,{w:560,align:'CENTER'});
  const bub=G(a,'Speech bubble',1320,250,420,120,'#F4ECD6',{r:24,fx:sh()}); T(bub,'You\'re FIRED!','cond',52,'#C8202F',0,26,{w:420,align:'CENTER'});
  T(a,'Camera snaps to his face · nearby lights die · distorted sting · then the ragdoll throw. No HUD during this beat.','type',20,'#AEB3BA',(W-900)/2,H-90,{w:900,align:'CENTER',op:0.8});
  label('4a · Catch — scare beat (desktop)',0,Y);
  // 4b spectate
  const b=G(page,'4b · Catch — spectating (desktop)',2020,Y+80,W,H,'#0E1116',{clip:true}); frames.push(b.id);
  scene(b,W,H,'art: teammate\'s view (graybox), pending'); topbar(b); R(b,0,0,W,H,'#0E1116',{op:0.25});
  const sp=G(b,'Spectate label',(W-520)/2,96,520,96,'#12305C',{r:8,op:0.92,fx:sh()});
  T(sp,'<','cond',40,'#9CC7FF',24,18); T(sp,'>','cond',40,'#9CC7FF',476,18);
  T(sp,'SPECTATING','type',18,'#9CC7FF',0,10,{w:520,align:'CENTER'}); T(sp,'Sam','cond',40,'#E6F5E8',0,34,{w:520,align:'CENTER'});
  T(b,'Back on the clock in 0:06','type',28,'#E6F5E8',(W-500)/2,H-130,{w:500,align:'CENTER'});
  T(b,'Q / E  switch teammate','type',18,'#E6F5E8',(W-400)/2,H-80,{w:400,align:'CENTER',op:0.6});
  label('4b · Catch — spectating (desktop)',2020,Y);
  // 4c rehired
  const c=G(page,'4c · Catch — "Rehired." card (desktop)',4040,Y+80,W,H,'#0E1116',{clip:true}); frames.push(c.id);
  scene(c,W,H,''); R(c,0,0,W,H,'#050506',{op:0.82,name:'scrim'});
  rehiredCard(c,(W-760)/2,(H-600)/2,760,false);
  label('4c · Catch — "Rehired." card (desktop)',4040,Y);
}
{ const W=844,H=390,PY=Y+80+1080+140;
  const d=G(page,'4d · Catch — spectating (phone)',0,PY,W,H,'#0E1116',{clip:true}); frames.push(d.id);
  scene(d,W,H,'art: teammate view, pending'); topbar(d,true);
  const sp=G(d,'Spectate label',(W-300)/2,10,300,64,'#12305C',{r:8,op:0.92});
  T(sp,'SPECTATING','type',14,'#9CC7FF',0,4,{w:300,align:'CENTER'}); T(sp,'Sam','cond',28,'#E6F5E8',0,20,{w:300,align:'CENTER'});
  const prev=variant(cMob,'Size=Small, State=Default').createInstance(); d.appendChild(prev); setText(prev,'label','<'); prev.x=48; prev.y=160;
  const next=variant(cMob,'Size=Small, State=Default').createInstance(); d.appendChild(next); setText(next,'label','>'); next.x=W-48-72; next.y=160;
  T(d,'Back on the clock in 0:06','type',18,'#E6F5E8',(W-300)/2,H-52,{w:300,align:'CENTER'});
  label('4d · Catch — spectating (phone)',0,PY-60,true);
  const e=G(page,'4e · Catch — "Rehired." card (phone)',1000,PY,W,H,'#0E1116',{clip:true}); frames.push(e.id);
  scene(e,W,H,''); R(e,0,0,W,H,'#050506',{op:0.82,name:'scrim'});
  rehiredCard(e,(W-440)/2,12,440,true);
  label('4e · Catch — "Rehired." card (phone)',1000,PY-60,true);
}
return {frames};
