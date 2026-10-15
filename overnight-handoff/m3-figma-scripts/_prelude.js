// Shared prelude for use_figma on file PYtXsNlpV1MW2nOVx0wXl4 ("Cleanup Crew — UI (for approval)").
// Prepend to each screen script (00_build.sh does this). UNTESTED: written after the Figma MCP limit hit.
const page = await figma.getNodeByIdAsync('2:5'); await figma.setCurrentPageAsync(page);
const hex = h => ({r:parseInt(h.slice(1,3),16)/255,g:parseInt(h.slice(3,5),16)/255,b:parseInt(h.slice(5,7),16)/255});
const fill = (h,o=1)=>[{type:'SOLID',color:hex(h),opacity:o}];
const sh = (y=6,r=14,a=0.45)=>[{type:'DROP_SHADOW',color:{r:0,g:0,b:0,a},offset:{x:0,y},radius:r,spread:0,visible:true,blendMode:'NORMAL'}];
const F = {type:{family:'Special Elite',style:'Regular'}, cond:{family:'Oswald',style:'Bold'}, condM:{family:'Oswald',style:'Medium'}, hand:{family:'Permanent Marker',style:'Regular'}, mono:{family:'Roboto Mono',style:'Bold'}};
await Promise.all(Object.values(F).map(f=>figma.loadFontAsync(f)));
const T=(p,s,f,sz,c,x,y,o={})=>{const t=figma.createText(); t.fontName=F[f]; t.characters=s; t.fontSize=sz; t.fills=fill(c,o.op??1); p.appendChild(t); if(o.w){t.resize(o.w,t.height); t.textAutoResize='HEIGHT';} if(o.align) t.textAlignHorizontal=o.align; if(o.ls) t.letterSpacing={unit:'PERCENT',value:o.ls}; if(o.lh) t.lineHeight={unit:'PERCENT',value:o.lh}; if(o.name) t.name=o.name; t.x=x; t.y=y; return t;};
const R=(p,x,y,w,h,c,o={})=>{const r=figma.createRectangle(); r.resize(w,h); r.fills=c?fill(c,o.op??1):[]; if(o.r!=null) r.cornerRadius=o.r; if(o.stroke){r.strokes=fill(o.stroke,o.sop??1); r.strokeWeight=o.sw||2; if(o.dash) r.dashPattern=o.dash;} if(o.name) r.name=o.name; if(o.fx) r.effects=o.fx; p.appendChild(r); r.x=x; r.y=y; return r;};
const E=(p,x,y,d,c,o={})=>{const e=figma.createEllipse(); e.resize(d,d); e.fills=c?fill(c,o.op??1):[]; if(o.stroke){e.strokes=fill(o.stroke,o.sop??1); e.strokeWeight=o.sw||2; if(o.dash) e.dashPattern=o.dash;} if(o.name) e.name=o.name; p.appendChild(e); e.x=x; e.y=y; return e;};
const G=(p,name,x,y,w,h,c,o={})=>{const f=figma.createFrame(); f.name=name; f.resize(w,h); f.fills=c?fill(c,o.op??1):[]; if(o.r!=null) f.cornerRadius=o.r; if(o.stroke){f.strokes=fill(o.stroke,o.sop??1); f.strokeWeight=o.sw||2;} if(o.fx) f.effects=o.fx; f.clipsContent=!!o.clip; p.appendChild(f); f.x=x; f.y=y; return f;};
const [cSticky,cStamp,cBtn,cMob,cSlot,cPunch,cTab] = await Promise.all(['5:4','5:7','5:17','5:26','5:31','5:32','5:47'].map(id=>figma.getNodeByIdAsync(id)));
const variant=(set,name)=>set.children.find(c=>c.name===name);
const setText=(inst,name,s)=>{const t=inst.findOne(n=>n.type==='TEXT'&&n.name===name); if(t) t.characters=s; return t;};
const btn=(parent,v,label,x,y,size)=>{const b=variant(cBtn,'Variant='+v).createInstance(); parent.appendChild(b); const t=setText(b,'label',label); if(size) t.fontSize=size; b.x=x; b.y=y; return b;};
const stamp=(parent,s,size,x,y,rot)=>{const st=cStamp.createInstance(); parent.appendChild(st); const t=setText(st,'text',s); t.fontSize=size; st.strokeWeight=Math.max(3,Math.round(size/10)); st.rotation=rot; st.x=x; st.y=y; return st;};
const sticky=(parent,s,x,y,rot,phone)=>{const t=cSticky.createInstance(); parent.appendChild(t); const tt=setText(t,'text',s); if(phone){t.resize(230,t.height); tt.fontSize=16; t.paddingTop=20; t.paddingBottom=12; t.paddingLeft=14; t.paddingRight=14;} t.rotation=rot; t.x=x; t.y=y; return t;};
const scene=(f,W,H,label,dark)=>{const bg=R(f,0,0,W,H,null,{name:'scene backdrop'}); bg.fills=[{type:'GRADIENT_LINEAR',gradientTransform:[[0,1,0],[-1,0,1]],gradientStops:[{position:0,color:{...hex(dark?'#1A1D22':'#232B33'),a:1}},{position:0.55,color:{...hex('#151A20'),a:1}},{position:1,color:{...hex('#0B0D10'),a:1}}]}];
  R(f,0,H*0.62,W,H*0.38,'#0B0D10',{op:0.55,name:'floor'}); T(f,label,'type',Math.max(14,Math.round(18*W/1920)),'#8A8F98',W/2-Math.round(240*W/1920),H*0.80,{w:Math.round(480*W/1920),align:'CENTER',op:0.55,name:'art placeholder label'});};
const topbar=(f,phone)=>{R(f,0,0,phone?200:250,58,null,{stroke:'#8A8F98',sop:0.5,dash:[5,4],sw:1,name:'Roblox top bar (reserved)'});};
const label=(s,x,y,phone)=>T(page,s,'cond',phone?32:40,'#E8C98A',x,y,{name:'frame label'});
const frames=[];
