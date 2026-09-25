const $=s=>document.querySelector(s), $$=s=>document.querySelectorAll(s);
const loader=$('#loader'), fill=$('#loaderFill'), pct=$('#loaderPct'), ltext=$('#loaderText'), lterm=$('#loaderTerminal');
const loaderSteps=[['BOOTING VO1D CORE','> boot core'],['VERIFYING ROUTE','> route london.edge'],['NEGOTIATING REALITY','> reality handshake'],['ENCRYPTING SESSION','> secure channel ready'],['READY','> connection surface online']];
let lp=0,ls=0;const loading=setInterval(()=>{lp+=Math.floor(Math.random()*8)+4;if(lp>100)lp=100;fill.style.width=lp+'%';pct.textContent=String(lp).padStart(2,'0')+'%';if(ls<loaderSteps.length&&lp>=ls*22+7){ltext.textContent=loaderSteps[ls][0];lterm.innerHTML+=loaderSteps[ls][1]+'<br>';ls++}if(lp===100){clearInterval(loading);setTimeout(()=>loader.classList.add('hide'),430)}},130);
const observer=new IntersectionObserver(entries=>entries.forEach(e=>{if(e.isIntersecting)e.target.classList.add('in')}),{threshold:.12});$$('.reveal').forEach(el=>observer.observe(el));
const sf=$('#starfield'),sx=sf.getContext('2d');let sw=0,sh=0,stars=[];function resizeStars(){const d=Math.min(devicePixelRatio||1,2);sw=sf.clientWidth;sh=sf.clientHeight;sf.width=sw*d;sf.height=sh*d;sx.setTransform(d,0,0,d,0,0);stars=Array.from({length:Math.min(180,Math.floor(sw/5))},()=>({x:Math.random()*sw,y:Math.random()*sh,r:Math.random()*1.2+.15,a:Math.random()*.55+.08}))}function drawStars(){sx.clearRect(0,0,sw,sh);for(const s of stars){sx.globalAlpha=s.a*(.75+.25*Math.sin(Date.now()/900+s.x));sx.fillStyle='#fff';sx.beginPath();sx.arc(s.x,s.y,s.r,0,Math.PI*2);sx.fill()}sx.globalAlpha=1;requestAnimationFrame(drawStars)}resizeStars();drawStars();addEventListener('resize',resizeStars);
const lines=['> Initializing secure tunnel...','> Requesting subscription token...','> Selecting London edge...','> Starting VLESS session...','> REALITY handshake: OK','> Transport: TCP/443','> Protected route established.','> Welcome to VO1D_VPN '];const t=$('#terminalTyping');let line=0,char=0;function typeTerminal(){if(line>=lines.length){t.innerHTML+='<span class="cursor"></span>';return}const current=lines[line];if(char<current.length){t.textContent+=current[char++];setTimeout(typeTerminal,16+Math.random()*22)}else{t.textContent+='\n';line++;char=0;setTimeout(typeTerminal,180)}}const termObs=new IntersectionObserver(es=>es.forEach(e=>{if(e.isIntersecting&&!t.dataset.started){t.dataset.started='1';typeTerminal()}}),{threshold:.35});termObs.observe(t);
const floatCode=$('#floatCode');const floatLines=['<strong>> session</strong> initialize','> route london.edge','> reality handshake','> transport tcp:443','<strong>> status CONFIGURED</strong>'];let fi=0;function floatType(){floatCode.innerHTML=floatLines.slice(0,fi+1).join('<br>');fi=(fi+1)%floatLines.length;setTimeout(floatType,780)}floatType();$('#floatPing').textContent='LON · EDGE';
const spark=$('#spark'),sp=spark.getContext('2d');function sparkResize(){const d=Math.min(devicePixelRatio||1,2);spark.width=spark.clientWidth*d;spark.height=spark.clientHeight*d;sp.setTransform(d,0,0,d,0,0)}function sparkDraw(){const w=spark.clientWidth,h=spark.clientHeight;sp.clearRect(0,0,w,h);sp.strokeStyle='rgba(255,255,255,.45)';sp.lineWidth=1;sp.beginPath();for(let i=0;i<=w;i+=4){const y=h*.62+Math.sin(i*.08+Date.now()/500)*8+Math.sin(i*.019)*11;i?sp.lineTo(i,y):sp.moveTo(i,y)}sp.stroke();requestAnimationFrame(sparkDraw)}sparkResize();sparkDraw();addEventListener('resize',sparkResize);
const nc=$('#networkCanvas'),nx=nc.getContext('2d');let nw=0,nh=0,nodes=[];function netResize(){const d=Math.min(devicePixelRatio||1,2);nw=nc.clientWidth;nh=nc.clientHeight;nc.width=nw*d;nc.height=nh*d;nx.setTransform(d,0,0,d,0,0);nodes=Array.from({length:28},()=>({x:nw*(.15+Math.random()*.7),y:nh*(.44+Math.random()*.4),a:.2+Math.random()*.5}))}function netDraw(){nx.clearRect(0,0,nw,nh);nx.strokeStyle='rgba(255,255,255,.08)';for(let i=0;i<nodes.length;i++){for(let j=i+1;j<nodes.length;j++){const a=nodes[i],b=nodes[j],dx=a.x-b.x,dy=a.y-b.y,d=Math.hypot(dx,dy);if(d<150){nx.globalAlpha=(1-d/150)*.5;nx.beginPath();nx.moveTo(a.x,a.y);nx.lineTo(b.x,b.y);nx.stroke()}}}for(const n of nodes){nx.globalAlpha=n.a;nx.fillStyle='#fff';nx.fillRect(n.x,n.y,1.3,1.3)}nx.globalAlpha=1;requestAnimationFrame(netDraw)}netResize();netDraw();addEventListener('resize',netResize);
addEventListener('scroll',()=>{const y=scrollY;const cf=$('#codeFloat');if(y<innerHeight*.5||y>document.body.scrollHeight-innerHeight*1.4)cf.classList.add('hide');else cf.classList.remove('hide')},{passive:true});

/* ===== V4 INTERACTION ENGINE ===== */
const root=document.documentElement;
const progressEl=$('#scrollProgress'), glow=$('#cursorGlow'), planet=$('.planet'), heroCopy=$('.hero-copy'), monolith=$('.monolith'), halo=$('.halo'), seq=$('.sequence'), seqLine=$('.sequence-line');
let pointerX=innerWidth/2,pointerY=innerHeight/2,scrollTick=false;

if(matchMedia('(hover:hover) and (pointer:fine)').matches){
  document.body.classList.add('has-pointer');
  addEventListener('pointermove',e=>{
    pointerX=e.clientX; pointerY=e.clientY;
    glow.style.left=pointerX+'px'; glow.style.top=pointerY+'px';
    const nx=(pointerX/innerWidth-.5), ny=(pointerY/innerHeight-.5);
    if(heroCopy) heroCopy.style.transform=`translate3d(${nx*-8}px,${ny*-6}px,0)`;
    if(planet) planet.style.transform=`translateX(-50%) translate3d(${nx*16}px,${ny*10}px,0) scale(1.01)`;
  },{passive:true});
}

function clamp(v,a=0,b=1){return Math.max(a,Math.min(b,v))}
function onVisualScroll(){
  scrollTick=false;
  const max=document.documentElement.scrollHeight-innerHeight;
  const p=max>0?scrollY/max:0;
  if(progressEl) progressEl.style.width=(p*100).toFixed(2)+'%';

  if(planet){
    const hp=clamp(scrollY/(innerHeight*1.12));
    planet.style.filter=`brightness(${1-hp*.28})`;
    planet.style.opacity=String(.92-hp*.45);
  }
  if(monolith){
    const rect=monolith.parentElement.getBoundingClientRect();
    const local=clamp((innerHeight-rect.top)/(innerHeight+rect.height));
    const ry=-13+(local-.5)*14;
    const ty=(local-.5)*-34;
    monolith.style.transform=`perspective(900px) translateY(${ty}px) rotateY(${ry}deg)`;
    monolith.style.boxShadow=`${-10-local*10}px 0 ${40+local*40}px rgba(255,255,255,${.16+local*.12}),0 0 ${80+local*80}px rgba(255,255,255,.07)`;
    if(halo) halo.style.transform=`rotate(${local*110}deg) scale(${.96+local*.08})`;
  }
  if(seq&&seqLine){
    const r=seq.getBoundingClientRect();
    const sp=clamp((innerHeight-r.top)/(r.height+innerHeight*.35));
    seqLine.style.setProperty('--sequence-progress',sp);
  }
  const railItems=$$('.section-rail span');
  let active='home';
  ['home','privacy','technology','features','network'].forEach(id=>{
    const el=document.getElementById(id);
    if(el&&el.getBoundingClientRect().top<innerHeight*.52)active=id;
  });
  railItems.forEach(n=>n.classList.toggle('active',n.dataset.target===active));
}
addEventListener('scroll',()=>{if(!scrollTick){scrollTick=true;requestAnimationFrame(onVisualScroll)}},{passive:true});onVisualScroll();

$$('.section-rail span').forEach(n=>n.addEventListener('click',()=>document.getElementById(n.dataset.target)?.scrollIntoView({behavior:'smooth'})));

if(matchMedia('(hover:hover) and (pointer:fine)').matches){
  $$('.terminal').forEach((card,idx)=>{
    card.addEventListener('pointermove',e=>{
      const r=card.getBoundingClientRect(),x=(e.clientX-r.left)/r.width-.5,y=(e.clientY-r.top)/r.height-.5;
      card.style.transform=`perspective(900px) rotateX(${-y*7}deg) rotateY(${x*9+(idx===0?3:idx===2?-3:0)}deg) translateY(-4px)`;
    });
    card.addEventListener('pointerleave',()=>card.style.transform=idx===0?'rotateY(5deg)':idx===2?'rotateY(-5deg)':'');
  });
  $$('.feature').forEach(card=>{
    card.addEventListener('pointermove',e=>{
      const r=card.getBoundingClientRect(),x=(e.clientX-r.left)/r.width,y=(e.clientY-r.top)/r.height;
      card.style.setProperty('--mx',(x*100)+'%'); card.style.setProperty('--my',(y*100)+'%');
      card.style.transform=`perspective(700px) rotateX(${(.5-y)*4}deg) rotateY(${(x-.5)*5}deg) translateY(-7px)`;
    });
    card.addEventListener('pointerleave',()=>card.style.transform='');
  });
}

const counters=$$('.stat b');
const counterObs=new IntersectionObserver(entries=>entries.forEach(e=>{
  if(!e.isIntersecting||e.target.dataset.counted)return;
  e.target.dataset.counted='1';
  const raw=e.target.textContent.trim();
  if(!/^\d+$/.test(raw))return;
  const end=Number(raw),start=performance.now(),dur=850;
  function frame(now){const k=clamp((now-start)/dur);const eased=1-Math.pow(1-k,4);e.target.textContent=Math.round(end*eased);if(k<1)requestAnimationFrame(frame);else e.target.textContent=raw}
  requestAnimationFrame(frame);
}),{threshold:.7});
counters.forEach(x=>counterObs.observe(x));

document.querySelectorAll('a[href^="#"]').forEach(a=>a.addEventListener('click',e=>{
  const target=a.getAttribute('href'); if(!target||target==='#')return;
  const el=document.querySelector(target); if(!el)return;
  e.preventDefault(); el.scrollIntoView({behavior:'smooth',block:'start'});
}));

document.addEventListener('visibilitychange',()=>{if(document.hidden)document.body.classList.add('page-paused');else document.body.classList.remove('page-paused')});


/* ===== V5 FINAL INTERACTIONS ===== */
const navAnchors=[...document.querySelectorAll('.navlinks a')];
function updateActiveNav(){
  let active='home';
  ['privacy','technology','features','network'].forEach(id=>{
    const el=document.getElementById(id);
    if(el&&el.getBoundingClientRect().top<innerHeight*.42)active=id;
  });
  navAnchors.forEach(a=>a.classList.toggle('active',a.getAttribute('href')==='#'+active));
}
addEventListener('scroll',updateActiveNav,{passive:true});updateActiveNav();

if(matchMedia('(hover:hover) and (pointer:fine)').matches){
  document.querySelectorAll('.primary,.mega,.tg-btn').forEach(btn=>{
    btn.addEventListener('pointermove',e=>{
      const r=btn.getBoundingClientRect();
      const x=(e.clientX-r.left-r.width/2)*.08;
      const y=(e.clientY-r.top-r.height/2)*.14;
      btn.style.transform=`translate3d(${x}px,${y-2}px,0)`;
    });
    btn.addEventListener('pointerleave',()=>btn.style.transform='');
  });
}

const arch=document.querySelector('.architecture');
if(arch){
  const archObs=new IntersectionObserver(entries=>entries.forEach(e=>{
    if(!e.isIntersecting)return;
    e.target.classList.add('architecture-live');
  }),{threshold:.25});
  archObs.observe(arch);
}

let lastScrollY=scrollY;
addEventListener('scroll',()=>{
  const y=scrollY,delta=y-lastScrollY; lastScrollY=y;
  const nav=document.querySelector('.nav');
  if(!nav)return;
  if(y>innerHeight*.9&&delta>8)nav.style.transform='translate(-50%,-86px)';
  else if(delta<-4||y<innerHeight*.65)nav.style.transform='translate(-50%,0)';
},{passive:true});

document.querySelectorAll('.feature,.arch-node,.terminal').forEach(el=>{
  el.addEventListener('focusin',()=>el.classList.add('focus-visual'));
  el.addEventListener('focusout',()=>el.classList.remove('focus-visual'));
});
