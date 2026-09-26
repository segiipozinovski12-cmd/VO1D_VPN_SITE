const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const tg=window.Telegram?.WebApp;
const state={me:null,tab:'home',busy:false,privacy:null};


const music=$('#bgMusic'),musicPlayer=$('#musicPlayer'),musicDrag=$('#musicDrag'),
      musicToggle=$('#musicToggle'),musicCollapse=$('#musicCollapse'),
      musicState=$('#musicState'),musicIcon=$('#musicIcon'),musicProgress=$('#musicProgress');
let musicUserPaused=false,musicDragState=null;

function musicStorageGet(key,fallback=null){
  try{const v=localStorage.getItem(key);return v===null?fallback:JSON.parse(v)}catch(e){return fallback}
}
function musicStorageSet(key,value){
  try{localStorage.setItem(key,JSON.stringify(value))}catch(e){}
}
function syncMusicUI(label){
  if(!music||!musicPlayer)return;
  const playing=!music.paused&&!music.ended&&!music.error;
  musicPlayer.classList.toggle('paused',!playing);
  musicPlayer.classList.toggle('unavailable',!!music.error);
  if(musicIcon)musicIcon.textContent=playing?'Ⅱ':'▶';
  if(musicState){
    if(label)musicState.textContent=label;
    else if(music.error)musicState.textContent='SLOWED · TRACK NEEDED';
    else musicState.textContent=playing?'SLOWED · PLAYING':'SLOWED · PAUSED';
  }
}
async function tryStartMusic(){
  if(!music||musicUserPaused||music.error)return;
  music.volume=.42;
  try{
    await music.play();
    syncMusicUI();
  }catch(e){
    syncMusicUI('SLOWED · TAP TO PLAY');
  }
}
async function toggleMusic(){
  if(!music)return;
  haptic('light');
  if(music.error){syncMusicUI('SLOWED · TRACK NEEDED');return}
  if(music.paused){
    musicUserPaused=false;
    try{await music.play();syncMusicUI()}catch(e){syncMusicUI('SLOWED · TAP TO PLAY')}
  }else{
    musicUserPaused=true;
    music.pause();
    syncMusicUI();
  }
}
function setMusicCollapsed(collapsed,save=true){
  if(!musicPlayer)return;
  musicPlayer.classList.toggle('collapsed',collapsed);
  if(musicCollapse){
    musicCollapse.textContent=collapsed?'↗':'—';
    musicCollapse.setAttribute('aria-label',collapsed?'Развернуть плеер':'Свернуть плеер');
  }
  if(save)musicStorageSet('vo1d_music_collapsed',collapsed);
  requestAnimationFrame(()=>requestAnimationFrame(clampMusicPlayer));
}
function viewportBox(){
  const vv=window.visualViewport;
  return {
    left:vv?.offsetLeft||0,
    top:vv?.offsetTop||0,
    width:vv?.width||innerWidth,
    height:vv?.height||innerHeight
  };
}
function clampMusicPlayer(){
  if(!musicPlayer)return;
  const v=viewportBox(),r=musicPlayer.getBoundingClientRect(),m=8;
  let left=parseFloat(musicPlayer.style.left);
  let top=parseFloat(musicPlayer.style.top);
  if(!Number.isFinite(left)||!Number.isFinite(top))return;
  const minX=v.left+m,minY=v.top+m;
  const maxX=Math.max(minX,v.left+v.width-r.width-m);
  const maxY=Math.max(minY,v.top+v.height-r.height-m);
  left=Math.min(maxX,Math.max(minX,left));
  top=Math.min(maxY,Math.max(minY,top));
  musicPlayer.style.left=left+'px';
  musicPlayer.style.top=top+'px';
  musicPlayer.style.right='auto';
  musicPlayer.style.bottom='auto';
}
function saveMusicPosition(){
  if(!musicPlayer||!musicPlayer.style.top)return;
  musicStorageSet('vo1d_music_position',{
    left:parseFloat(musicPlayer.style.left)||8,
    top:parseFloat(musicPlayer.style.top)||8
  });
}
function restoreMusicPlayer(){
  if(!musicPlayer)return;
  // Каждый новый запуск Mini App начинается с компактного квадрата.
  setMusicCollapsed(true,false);
  const pos=musicStorageGet('vo1d_music_position',null);
  if(pos&&Number.isFinite(pos.left)&&Number.isFinite(pos.top)){
    musicPlayer.style.left=pos.left+'px';
    musicPlayer.style.top=pos.top+'px';
    musicPlayer.style.right='auto';
    musicPlayer.style.bottom='auto';
    requestAnimationFrame(clampMusicPlayer);
  }
}
function beginMusicDrag(e){
  if(!musicPlayer||e.button>0)return;
  const r=musicPlayer.getBoundingClientRect();
  musicDragState={
    id:e.pointerId,
    startX:e.clientX,startY:e.clientY,
    originX:r.left,originY:r.top,
    moved:false
  };
  musicPlayer.style.left=r.left+'px';
  musicPlayer.style.top=r.top+'px';
  musicPlayer.style.right='auto';
  musicPlayer.style.bottom='auto';
  musicPlayer.classList.add('dragging');
  musicDrag.setPointerCapture?.(e.pointerId);
  e.preventDefault();
}
function moveMusicDrag(e){
  const d=musicDragState;
  if(!d||e.pointerId!==d.id||!musicPlayer)return;
  const dx=e.clientX-d.startX,dy=e.clientY-d.startY;
  if(Math.abs(dx)+Math.abs(dy)>5)d.moved=true;
  musicPlayer.style.left=(d.originX+dx)+'px';
  musicPlayer.style.top=(d.originY+dy)+'px';
  clampMusicPlayer();
}
function endMusicDrag(e){
  const d=musicDragState;
  if(!d||e.pointerId!==d.id)return;
  musicPlayer?.classList.remove('dragging');
  try{musicDrag?.releasePointerCapture?.(e.pointerId)}catch(err){}
  if(!d.moved&&musicPlayer?.classList.contains('collapsed'))setMusicCollapsed(false);
  else saveMusicPosition();
  musicDragState=null;
}
function updateMusicProgress(){
  if(!music||!musicProgress)return;
  const pct=Number.isFinite(music.duration)&&music.duration>0?(music.currentTime/music.duration)*100:0;
  musicProgress.style.width=Math.max(0,Math.min(100,pct))+'%';
}

music?.addEventListener('play',()=>syncMusicUI());
music?.addEventListener('pause',()=>syncMusicUI());
music?.addEventListener('canplay',()=>syncMusicUI(music.paused?'SLOWED · READY':'SLOWED · PLAYING'));
music?.addEventListener('error',()=>syncMusicUI('SLOWED · TRACK NEEDED'));
music?.addEventListener('timeupdate',updateMusicProgress);
musicToggle?.addEventListener('click',toggleMusic);
musicCollapse?.addEventListener('click',()=>setMusicCollapsed(!musicPlayer.classList.contains('collapsed')));
musicDrag?.addEventListener('pointerdown',beginMusicDrag);
musicDrag?.addEventListener('pointermove',moveMusicDrag);
musicDrag?.addEventListener('pointerup',endMusicDrag);
musicDrag?.addEventListener('pointercancel',endMusicDrag);
musicDrag?.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&musicPlayer?.classList.contains('collapsed')){e.preventDefault();setMusicCollapsed(false)}});
addEventListener('resize',()=>requestAnimationFrame(clampMusicPlayer),{passive:true});
window.visualViewport?.addEventListener('resize',()=>requestAnimationFrame(clampMusicPlayer),{passive:true});

restoreMusicPlayer();
syncMusicUI('SLOWED · LOADING');
setTimeout(tryStartMusic,520);
document.addEventListener('pointerdown',()=>{
  if(music&&!musicUserPaused&&music.paused&&!music.error)tryStartMusic();
},{once:true,passive:true});

function telegramInit(){
  if(!tg)return;
  try{
    tg.ready();tg.expand();
    tg.setHeaderColor?.('#050505');
    tg.setBackgroundColor?.('#050505');
    tg.setBottomBarColor?.('#050505');
  }catch(e){}
}
telegramInit();

const boot=$('#boot'),bootFill=$('#bootFill'),bootPct=$('#bootPct'),bootText=$('#bootText'),shell=$('#shell'),
      bootPulse=$('#bootPulse'),bootS1=$('#bootS1'),bootS2=$('#bootS2'),bootS3=$('#bootS3');

let bootVisualDone=false,bootDataReady=false,bootFailed=false;
function forceShellReady(){
  boot?.classList.add('hide');
  shell?.classList.add('ready');
  refreshReveal();
}
function maybeFinishBoot(force=false){
  if(!force&&(!bootVisualDone||(!bootDataReady&&!bootFailed)))return;
  if(bootDataReady)updateBoot(100);
  boot?.classList.remove('loading');
  boot?.classList.add(bootDataReady?'complete':'failed');
  setTimeout(forceShellReady,bootDataReady?320:120);
}
setTimeout(()=>{
  if(!bootDataReady){
    bootFailed=true;
    if(bootText)bootText.textContent='CONNECTION TIMEOUT';
    maybeFinishBoot(true);
  }
},9000);
window.addEventListener('error',e=>{
  console.error('VO1D UI error',e.error||e.message);
  bootFailed=true;
  maybeFinishBoot(true);
});
const bootSteps=[
  [0,'INITIALIZING'],
  [15,'VERIFYING TELEGRAM'],
  [34,'OPENING SECURE CHANNEL'],
  [56,'AUTHENTICATING SESSION'],
  [74,'SYNCING ACCESS CORE'],
  [90,'RENDERING PRIVATE INTERFACE'],
  [99,'ACCESS READY']
];
let bp=0,bootStarted=performance.now();
boot?.classList.add('loading');

function updateBoot(value){
  bp=Math.max(0,Math.min(100,value));
  if(bootFill)bootFill.style.width=bp.toFixed(1)+'%';
  if(bootPulse)bootPulse.style.left=`calc(${bp.toFixed(1)}% - 5px)`;
  if(bootPct)bootPct.textContent=String(Math.floor(bp)).padStart(2,'0')+'%';
  const match=[...bootSteps].reverse().find(x=>bp>=x[0]);
  if(match&&bootText)bootText.textContent=match[1];
  bootS1?.classList.toggle('ok',bp>=28);
  bootS2?.classList.toggle('ok',bp>=55);
  bootS3?.classList.toggle('ok',bp>=82);
}
function bootFrame(now){
  const elapsed=now-bootStarted;
  const raw=Math.min(1,elapsed/2050);
  const eased=1-Math.pow(1-raw,3.2);
  // Лёгкие замедления делают загрузку похожей на настоящий системный handshake.
  let target=eased*100;
  if(raw<.42)target=Math.min(target,47);
  if(raw<.70&&target>71)target=71;
  updateBoot(target);
  if(raw<1){
    requestAnimationFrame(bootFrame);
  }else{
    bootVisualDone=true;
    if(bootDataReady){
      updateBoot(100);
      if(bootText)bootText.textContent='ACCESS READY';
    }else{
      updateBoot(94);
      if(bootText)bootText.textContent='SYNCING ACCOUNT';
    }
    maybeFinishBoot();
  }
}
requestAnimationFrame(bootFrame);

function haptic(type='light'){try{tg?.HapticFeedback?.impactOccurred(type)}catch(e){}}
function notify(msg){
  const t=$('#toast');if(!t)return;
  t.textContent=msg;t.classList.add('show');clearTimeout(notify._t);
  notify._t=setTimeout(()=>t.classList.remove('show'),1800);
}
function safeText(v,fallback='—'){return v===null||v===undefined||v===''?fallback:String(v)}
function fmtMoney(cents){return '$'+(Number(cents||0)/100).toFixed(2)}
function formatLocalUnix(ts){
  const n=Number(ts||0);if(!n)return '—';
  try{
    return new Intl.DateTimeFormat('ru-RU',{
      day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'
    }).format(new Date(n*1000));
  }catch(e){return new Date(n*1000).toLocaleString()}
}
async function api(path,opts={}){
  const timeout=Number(opts.timeout||8000);
  const controller=new AbortController();
  const timer=setTimeout(()=>controller.abort(),timeout);
  const {timeout:_ignored,headers:extraHeaders,...rest}=opts;
  const headers={'Content-Type':'application/json','X-Telegram-Init-Data':tg?.initData||'',...(extraHeaders||{})};
  try{
    const res=await fetch(path,{...rest,headers,cache:'no-store',signal:controller.signal});
    let data={};try{data=await res.json()}catch(e){data={ok:false,error:'bad_response'}}
    if(!res.ok||data.ok===false){const err=new Error(data.message||data.error||'request_failed');err.data=data;err.status=res.status;throw err}
    return data;
  }catch(e){
    if(e?.name==='AbortError'){const err=new Error('timeout');err.data={message:'Сервер отвечает слишком долго. Попробуй ещё раз.'};throw err}
    throw e;
  }finally{clearTimeout(timer)}
}

let observer;
function setupReveal(){
  observer?.disconnect?.();
  const reduce=window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches;
  if(reduce||!('IntersectionObserver' in window)){$$('.reveal').forEach(el=>el.classList.add('seen'));return}
  observer=new IntersectionObserver(entries=>{
    entries.forEach((entry,i)=>{
      if(entry.isIntersecting){
        setTimeout(()=>entry.target.classList.add('seen'),Math.min(i*28,110));
        observer.unobserve(entry.target);
      }
    });
  },{threshold:.08,rootMargin:'0px 0px -18px'});
  $$('.tab.active .reveal').forEach(el=>observer.observe(el));
}
function refreshReveal(){
  requestAnimationFrame(()=>{
    $$('.tab.active .reveal').forEach(el=>el.classList.remove('seen'));
    setupReveal();
  });
}

function switchTab(name){
  state.tab=name;
  $$('.tab').forEach(x=>x.classList.toggle('active',x.id==='tab-'+name));
  $$('.nav-item').forEach(x=>x.classList.toggle('active',x.dataset.tab===name));
  window.scrollTo(0,0);
  try{
    if(tg?.BackButton){if(name==='home')tg.BackButton.hide();else tg.BackButton.show()}
    tg?.HapticFeedback?.selectionChanged?.();
  }catch(e){}
  refreshReveal();
  if(name==='admin')loadAdmin();
}
document.addEventListener('click',e=>{
  const btn=e.target.closest?.('[data-tab]');
  if(btn?.dataset?.tab)switchTab(btn.dataset.tab);
});
try{tg?.BackButton?.onClick(()=>switchTab('home'))}catch(e){}

function setLoadingError(message='Не удалось получить данные. Нажми сюда, чтобы повторить.'){
  bootFailed=true;
  maybeFinishBoot(true);
  notify('НЕ УДАЛОСЬ ЗАГРУЗИТЬ ДАННЫЕ');
  const hint=$('#heroHint');
  if(hint){
    hint.textContent=message;
    hint.classList.add('retry-hint');
    hint.onclick=()=>loadMe(true);
  }
  const chip=$('#chipStatus');
  if(chip)chip.textContent='reconnect needed';
}

function renderPlans(plans,infra={}){
  const box=$('#plansList');if(!box)return;
  const regions=Math.max(0,Number(infra?.servers?.total_countries||0));
  const regionLabel=regions?(`${regions} ${regions===1?'REGION':'REGIONS'}`):'VO1D NETWORK';
  box.innerHTML=(plans||[]).map((p,i)=>`
    <article class="plan reveal ${i===1?'popular':''}">
      <div class="plan-top">
        <div class="plan-label"><span>0${i+1} / ACCESS</span><h3>${p.title}</h3></div>
        <div class="plan-price"><b>${p.stars} ⭐</b><small>${p.usd}</small></div>
      </div>
      ${i===1?'<div class="plan-badge">POPULAR</div>':''}
      <div class="plan-meta"><span>${p.days} DAYS</span><span>VLESS + REALITY</span><span>${regionLabel}</span></div>
      <button class="primary-btn buy-stars" data-days="${p.days}">КУПИТЬ ЗА ${p.stars} ⭐</button>
    </article>`).join('');
  $$('.buy-stars').forEach(b=>b.addEventListener('click',()=>buyStars(Number(b.dataset.days),b)));
  if(state.tab==='plans')refreshReveal();
}

function renderServers(network={}){
  const box=$('#serverList'),counter=$('#serverCount');
  if(!box)return;
  const countries=Array.isArray(network.countries)?network.countries:[];
  const totalNodes=Number(network.total_nodes||0);
  if(counter)counter.textContent=countries.length?(`${countries.length} COUNTRIES · ${totalNodes} NODES`):'0 COUNTRIES';
  if(!countries.length){
    box.innerHTML='<div class="server-empty">СЕРВЕРЫ ОБНОВЛЯЮТСЯ…</div>';
    return;
  }
  box.innerHTML=countries.map((s,i)=>{
    const code=String(s.code||'--').replace(/[^A-Z]/g,'').slice(0,3);
    const name=String(s.name||code).replace(/[<>&]/g,'');
    const flag=String(s.flag||'◌').replace(/[<>&]/g,'');
    const where=s.location?(' · '+String(s.location).replace(/[<>&]/g,'')):'';
    const nodes=Math.max(1,Number(s.nodes||1));
    return `<article class="server-row">
      <div class="server-index">${String(i+1).padStart(2,'0')}</div>
      <div class="server-flag">${flag}</div>
      <div class="server-copy"><span>${code}${where}</span><b>${name}</b><small>${nodes} ${nodes===1?'NODE':'NODES'} В ПОДПИСКЕ</small></div>
      <div class="server-state"><i></i>READY</div>
    </article>`;
  }).join('');
}

async function loadServers(){
  try{
    const data=await api('/api/servers',{timeout:6000});
    renderServers(data);
  }catch(e){
    console.warn('server list refresh failed',e);
  }
}

function render(me){
  state.me=me;
  const u=me.user||{},s=me.subscription||{},infra=me.infrastructure||{};
  const initial=(u.first_name||u.username||'V').trim().charAt(0).toUpperCase();
  $('#avatar').textContent=initial;$('#accountAvatar').textContent=initial;
  $('#chipName').textContent=u.first_name||u.username||'VO1D';
  $('#chipStatus').textContent=s.active?'access active':'access offline';
  $('#accountName').textContent=[u.first_name,u.last_name].filter(Boolean).join(' ')||'VO1D user';
  $('#accountUsername').textContent=u.username?'@'+u.username:'username скрыт';
  $('#accountId').textContent=safeText(u.id);
  $('#balance').textContent=fmtMoney(u.balance_cents);
  $('#accountUntil').textContent=s.until?formatLocalUnix(s.until):'—';
  $('#trialState').textContent=s.trial_claimed?'CLAIMED':'AVAILABLE';
  if($('#adminOpen'))$('#adminOpen').hidden=!u.is_admin;

  const nodeKnown=typeof infra.node_online==='boolean';
  const nodeUp=infra.node_online===true;
  $('#nodeStatus').classList.toggle('active',nodeUp);
  const nodeLabel=!infra.node_configured?'NODE NOT CONFIGURED':(nodeKnown?(nodeUp?'NODE ONLINE':'NODE OFFLINE'):'NODE CHECKING');
  const nodeLatency=nodeUp&&Number.isFinite(Number(infra.node_latency_ms))?` · ${infra.node_latency_ms}MS`:'';
  $('#nodeStatus').innerHTML=`<i></i>${nodeLabel}${nodeLatency}`;
  $('#privacyValue').textContent=s.active?'READY':'OFF';
  $('#heroHint').textContent=s.active?'Доступ активен. Подключись через Happ и проверь внешний IP ниже.':'Подписка неактивна. Активируй пробный доступ или выбери тариф.';
  $('#daysLeft').textContent=s.active?(s.remaining_short||'ACTIVE'):'0';
  $('#untilText').textContent=s.active?('до '+formatLocalUnix(s.until)):'нет активного доступа';
  $('#planState').textContent=s.active?'ACTIVE':'OFFLINE';

  $('#accessStatus').textContent=s.active?'ACTIVE':'OFFLINE';
  $('#accessRemaining').textContent=s.active?(s.remaining_long||'активно'):'нужна подписка';
  $('#subUrl').textContent=s.subscription_url||'Активируй подписку, чтобы получить URL';
  $('#copySub').disabled=!s.subscription_url;
  $('#trialCard').classList.toggle('used',!!s.trial_claimed);

  const network=infra.servers||{};
  const countries=Math.max(0,Number(network.total_countries||0));
  $('#networkLocation').textContent=countries>1?`${countries} REGIONS`:(countries===1?'1 REGION':'VO1D CORE');
  $('#networkSecurity').textContent=infra.protocol?.includes('REALITY')?'REALITY':safeText(infra.protocol,'VLESS');
  $('#networkFlow').textContent='VISION';
  $('#networkTransport').textContent=safeText(infra.transport,'TCP / 443');

  renderServers(network);
  renderPlans(me.plans||[],infra);
}

async function loadMe(manual=false){
  if(state.loadingMe)return;
  if(!tg?.initData){setLoadingError('Открой Mini App заново из @VO1D_VPNbot.');return}
  state.loadingMe=true;
  if(manual){
    bootFailed=false;
    notify('ПОВТОРНОЕ ПОДКЛЮЧЕНИЕ…');
  }
  try{
    const me=await api('/api/me',{timeout:8000});
    render(me);
    bootDataReady=true;
    bootFailed=false;
    const hint=$('#heroHint');
    if(hint){hint.classList.remove('retry-hint');hint.onclick=null}
    maybeFinishBoot();
    measurePing();
    setTimeout(()=>runPrivacyTest(false),550);
    setTimeout(loadServers,4200);
  }catch(e){
    console.error(e);setLoadingError(e.data?.message||'Не удалось получить данные. Нажми сюда, чтобы повторить.');
  }finally{
    state.loadingMe=false;
  }
}

async function loadAdmin(){
  if(!state.me?.user?.is_admin)return;
  try{
    const d=await api('/api/admin/overview');
    $('#adminUsers').textContent=safeText(d.users);
    $('#adminActive').textContent=safeText(d.active);
    $('#adminPending').textContent=safeText(d.pending);
    $('#adminBalanceTotal').textContent=fmtMoney(d.balance_total);
    const box=$('#adminPromos');
    if(box)box.innerHTML=(d.promos||[]).map(p=>{
      const reward=p.reward_type==='days'?'+'+p.reward_value+' DAYS':'+'+fmtMoney(p.reward_value);
      const limit=Number(p.max_uses||0)?p.max_uses:'∞';
      return `<div><b>${p.code}</b><small>${reward} · ${p.uses}/${limit} · ${p.active?'ON':'OFF'}</small></div>`;
    }).join('')||'<div><b>NO PROMOS</b><small>—</small></div>';
    refreshReveal();
  }catch(e){notify(e.data?.message||'ADMIN LOAD ERROR')}
}

async function createAdminPromo(){
  const code=$('#promoCodeInput')?.value.trim();
  const reward_type=$('#promoTypeInput')?.value;
  const value=$('#promoValueInput')?.value.trim();
  const max_uses=$('#promoUsesInput')?.value.trim()||'0';
  if(!code||!value){notify('ЗАПОЛНИ CODE И НАГРАДУ');return}
  try{
    const r=await api('/api/admin/promo',{method:'POST',body:JSON.stringify({code,reward_type,value,max_uses})});
    notify('PROMO '+r.code+' SAVED');
    $('#promoCodeInput').value='';$('#promoValueInput').value='';
    await loadAdmin();
  }catch(e){notify(e.data?.message||'PROMO ERROR')}
}

async function adminGrant(){
  const user_id=$('#grantUserInput')?.value.trim();
  const kind=$('#grantTypeInput')?.value;
  const value=$('#grantValueInput')?.value.trim();
  if(!user_id||!value){notify('УКАЖИ ID И ЗНАЧЕНИЕ');return}
  try{
    const r=await api('/api/admin/grant',{method:'POST',body:JSON.stringify({user_id,kind,value})});
    notify('ГОТОВО · '+r.message);
    $('#grantValueInput').value='';
    await loadAdmin();
  }catch(e){notify(e.data?.message||'GRANT ERROR')}
}

async function measurePing(){
  const out=$('#pingValue');if(!out)return;
  out.textContent='…';
  const values=[];
  for(let i=0;i<3;i++){
    const t=performance.now();
    try{await api('/api/ping?x='+Date.now(),{timeout:3500});values.push(performance.now()-t)}catch(e){}
  }
  if(!values.length){out.textContent='OFF';return}
  const ms=Math.round(values.reduce((a,b)=>a+b,0)/values.length);
  out.textContent=ms+' ms';
}

function renderRouteRing(verified){
  const text=$('#privacyScore'),ring=$('#scoreRing');
  if(!text||!ring)return;
  text.textContent=verified?'ON':'OFF';
  ring.style.background=verified
    ?'conic-gradient(#f4f4f0 100%,rgba(255,255,255,.07) 0)'
    :'conic-gradient(#f4f4f0 0%,rgba(255,255,255,.07) 0)';
}

async function runPrivacyTest(manual=true){
  const card=$('#privacyTest'),btn=$('#runPrivacyTest');
  if(!card||state.busy&&manual)return;
  card.classList.add('testing');
  $('#privacyBadge').textContent='SCANNING';
  $('#observedIp').textContent='определяем…';
  $('#routeCheck').textContent='CHECKING';
  if(manual){state.busy=true;haptic('medium');btn.disabled=true}
  try{
    const result=await api('/api/privacy-test');
    state.privacy=result;
    $('#observedIp').textContent=result.ip||'не определён';
    $('#routeCheck').textContent=result.vo1d_route?'CONFIRMED':'NOT DETECTED';
    $('#privacyLevel').textContent=result.level||'CHECKED';
    $('#privacyBadge').textContent=result.vo1d_route?'VO1D ROUTE':'DIRECT ROUTE';
    renderRouteRing(!!result.vo1d_route);
    if(manual){
      try{tg?.HapticFeedback?.notificationOccurred?.(result.vo1d_route?'success':'warning')}catch(e){}
      notify(result.vo1d_route?'VO1D МАРШРУТ ПОДТВЕРЖДЁН':'IP УЗЛА VO1D НЕ ОБНАРУЖЕН');
    }
  }catch(e){
    $('#observedIp').textContent='ошибка проверки';
    $('#routeCheck').textContent='ERROR';
    $('#privacyLevel').textContent='НЕТ ДАННЫХ';
    $('#privacyBadge').textContent='ERROR';
    renderRouteRing(false);
    if(manual)notify('НЕ УДАЛОСЬ ПРОВЕРИТЬ IP');
  }finally{
    setTimeout(()=>card.classList.remove('testing'),260);
    if(manual){state.busy=false;btn.disabled=false}
  }
}

async function activateTrial(){
  const btn=$('#trialBtn');if(state.busy)return;state.busy=true;btn.disabled=true;btn.textContent='АКТИВАЦИЯ…';haptic('medium');
  try{
    await api('/api/trial',{method:'POST',body:'{}'});
    notify('ПРОБНЫЙ ДОСТУП АКТИВИРОВАН');
    try{tg?.HapticFeedback?.notificationOccurred?.('success')}catch(e){}
    await loadMe();switchTab('access');
  }catch(e){
    if(e.data?.code==='channel_required'&&e.data?.channel_url){
      notify('СНАЧАЛА ПОДПИШИСЬ НА КАНАЛ');
      tg?.openTelegramLink?.(e.data.channel_url);
    }else notify(e.data?.message||'НЕ УДАЛОСЬ АКТИВИРОВАТЬ');
  }finally{state.busy=false;btn.disabled=false;btn.textContent='АКТИВИРОВАТЬ'}
}

async function buyStars(days,btn){
  if(state.busy)return;state.busy=true;
  const old=btn.textContent;btn.disabled=true;btn.textContent='СОЗДАЁМ СЧЁТ…';haptic('medium');
  try{
    const r=await api('/api/invoice',{method:'POST',body:JSON.stringify({days})});
    if(tg?.openInvoice){
      tg.openInvoice(r.invoice_url,status=>{
        if(status==='paid'){notify('ОПЛАТА ПОЛУЧЕНА');setTimeout(loadMe,700);try{tg.HapticFeedback?.notificationOccurred?.('success')}catch(e){}}
        else if(status==='cancelled')notify('ОПЛАТА ОТМЕНЕНА');
        else if(status==='failed')notify('ОШИБКА ОПЛАТЫ');
      });
    }else location.href=r.invoice_url;
  }catch(e){notify(e.data?.message||'НЕ УДАЛОСЬ СОЗДАТЬ СЧЁТ')}
  finally{state.busy=false;btn.disabled=false;btn.textContent=old}
}

async function copySubscription(){
  const value=state.me?.subscription?.subscription_url;if(!value)return;
  haptic('light');
  try{
    await navigator.clipboard.writeText(value);notify('ССЫЛКА СКОПИРОВАНА');
  }catch(e){
    const ta=document.createElement('textarea');ta.value=value;document.body.appendChild(ta);ta.select();document.execCommand('copy');ta.remove();notify('ССЫЛКА СКОПИРОВАНА');
  }
}

function openTelegramUrl(url){
  const target=String(url||'').trim();
  if(!target)return;
  if(tg?.openTelegramLink)tg.openTelegramLink(target);else location.href=target;
}

function bindPressEffects(){
  document.addEventListener('pointerdown',e=>{
    const b=e.target.closest('button');if(!b)return;
    b.animate([{transform:'scale(1)'},{transform:'scale(.975)'},{transform:'scale(1)'}],{duration:230,easing:'cubic-bezier(.19,1,.22,1)'});
  },{passive:true});
}

let scrollTick=false;
addEventListener('scroll',()=>{
  if(scrollTick)return;scrollTick=true;
  requestAnimationFrame(()=>{
    scrollTick=false;
    const y=Math.min(scrollY,500);
    const hero=$('.hero-card');
    if(hero&&state.tab==='home'){
      $$('.orbit').forEach((o,i)=>o.style.translate=`0 ${y*(i+1)*.012}px`);
      $('.hero-grid').style.transform=`translateY(${y*.035}px)`;
    }
  });
},{passive:true});

$('#trialBtn')?.addEventListener('click',activateTrial);
$('#copySub')?.addEventListener('click',copySubscription);
$('#runPrivacyTest')?.addEventListener('click',()=>runPrivacyTest(true));
$('#refreshBtn')?.addEventListener('click',async()=>{
  haptic('light');const b=$('#refreshBtn');b.style.transform='rotate(180deg)';
  await loadMe();setTimeout(()=>b.style.transform='',250);notify('ДАННЫЕ ОБНОВЛЕНЫ');
});
$('#pingCard')?.addEventListener('click',()=>{haptic('light');measurePing()});
$('#supportBtn')?.addEventListener('click',()=>openTelegramUrl(state.me?.links?.support||'https://t.me/vo1d_root'));
$('#supportPayBtn')?.addEventListener('click',()=>openTelegramUrl(state.me?.links?.support||'https://t.me/vo1d_root'));
$('#openBotBtn')?.addEventListener('click',()=>openTelegramUrl(state.me?.links?.bot||'https://t.me/VO1D_VPNbot'));
$('#createPromoBtn')?.addEventListener('click',createAdminPromo);
$('#grantBtn')?.addEventListener('click',adminGrant);

document.documentElement.dataset.vo1dJs='ready';
bindPressEffects();
setupReveal();
loadMe();
