window.SV={
  esc(s){return String(s).replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]))},
  seg(x1,y1,x2,y2,c='#2563eb',w=3,dash=''){return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${c}" stroke-width="${w}" ${dash?`stroke-dasharray="${dash}"`:''}/>`},
  dot(x,y,c='#2563eb',r=5){return `<circle cx="${x}" cy="${y}" r="${r}" fill="${c}"/>`},
  poly(p,fill='none',stroke='#2563eb',w=3){return `<polygon points="${p.map(x=>x.join(',')).join(' ')}" fill="${fill}" stroke="${stroke}" stroke-width="${w}" stroke-linejoin="round"/>`},
  vlabel(x,y,t,c='#172033',fs=16){return `<text x="${x}" y="${y}" fill="${c}" font-size="${fs}" class="svgtext" text-anchor="middle">${t}</text>`},
  fbox(rows){return `<div class="fbox">${rows.map(r=>`<div class="frow" style="--color:${r.color||'#2563eb'};--border:${r.border||'#dbe4ef'};--fill:${r.fill||'#fff'}"><label>${r.label}</label><div>\\(${r.tex}\\)</div>${r.note?`<note>${r.note}</note>`:''}</div>`).join('')}</div>`},
  plane({x0=45,y0=25,w=350,h=220,xmin=-5,xmax=5,ymin=-4,ymax=4,step=1}){const X=x=>x0+(x-xmin)*w/(xmax-xmin),Y=y=>y0+(ymax-y)*h/(ymax-ymin);let s='';for(let x=Math.ceil(xmin);x<=xmax;x+=step)s+=this.seg(X(x),y0,X(x),y0+h,'#e2e8f0',1);for(let y=Math.ceil(ymin);y<=ymax;y+=step)s+=this.seg(x0,Y(y),x0+w,Y(y),'#e2e8f0',1);s+=this.seg(X(xmin),Y(0),X(xmax),Y(0),'#64748b',2)+this.seg(X(0),Y(ymin),X(0),Y(ymax),'#64748b',2);return{X,Y,svg:s}},
  stepper(h,vb,steps){h.innerHTML=`<div class="stepper"><div id="fig"></div><div class="steptext" id="st"></div><input id="ss" type="range" min="0" max="${steps.length-1}" step="1" value="0"></div>`;const draw=()=>{const k=+h.querySelector('#ss').value;h.querySelector('#fig').innerHTML=`<svg viewBox="${vb}" style="width:100%;max-height:275px">${steps[k].d(k)}</svg>`;h.querySelector('#st').innerHTML=`${k+1}/${steps.length}　${steps[k].t}`};h.querySelector('#ss').oninput=draw;draw()}
};
