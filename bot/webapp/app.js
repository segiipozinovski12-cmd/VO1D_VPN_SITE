const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const tg=window.Telegram?.WebApp;
const state={me:null,tab:'home',busy:false,privacy:null};


const music=$('#bgMusic'),musicToggle=$('#musicToggle'),musicState=$('#musicState'),musicIcon=$('#musicIcon');
let musicUserPaused=false;
function syncMusicUI(){
  if(!music||!musicToggle)return;
  const playing=!music.paused&&!music.ended;
  musicToggle.classList.toggle('paused',!playing);
  musicIcon.textContent=playing?'Ⅱ':'▶';
  if(music.error){
    musicState.textContent='SLOWED · FILE NEEDED';
    musicToggle.classList.add('unavailable');
  }else{
    musicToggle.classList.remove('unavailable');
    musicState.textContent=playing?'SLOWED · PLAYING':'SLOWED · PAUSED';
  }
}
async function tryStartMusic(){
  if(!music||musicUserPaused||music.error)return;
  music.volume=.42;
  try{await music.play();syncMusicUI()}catch(e){
    musicState.textContent='SLOWED · TAP TO PLAY';
    syncMusicUI();
  }
}
function toggleMusic(){
  if(!music)return;
  haptic('light');
  if(music.paused){
    musicUserPaused=false;
    music.play().then(syncMusicUI).catch(()=>{musicState.textContent='SLOWED · TAP TO PLAY';syncMusicUI()});
  }else{
    musicUserPaused=true;
    music.pause();
    syncMusicUI();
  }
}
music?.addEventListener('play',syncMusicUI);
music?.addEventListener('pause',syncMusicUI);
music?.addEventListener('error',syncMusicUI);
musicToggle?.addEventListener('click',toggleMusic);
document.addEventListener('pointerdown',()=>{
  if(music&&!musicUserPaused&&music.paused&&!music.error)tryStartMusic();
},{once:true,passive:true});
setTimeout(tryStartMusic,450);

function telegramInit(){
  if(!tg)return;
  try{
    tg.ready();tg.expand();
    tg.setHeaderColor?.('#050505');
    tg.setBackgroundColor?.('#050505');
    tg.setBottomBarColor?.('#050505');
    tg.disableVerticalSwipes?.();
  }catch(e){}
}
telegramInit();

const boot=$('#boot'),bootFill=$('#bootFill'),bootPct=$('#bootPct'),bootText=$('#bootText'),shell=$('#shell');
let bp=0;
const bootSteps=[[8,'VERIFYING TELEGRAM'],[29,'AUTHENTICATING'],[52,'LOADING ACCOUNT'],[73,'SYNCING ACCESS'],[91,'BUILDING SECURE UI'],[99,'READY']];
const bootTimer=setInterval(()=>{
  bp=Math.min(100,bp+Math.floor(Math.random()*7)+3);
  bootFill.style.width=bp+'%';
  bootPct.textContent=String(bp).padStart(2,'0')+'%';
  const match=[...bootSteps].reverse().find(x=>bp>=x[0]);
  if(match)bootText.textContent=match[1];
  if(bp>=100){
    clearInterval(bootTimer);
    setTimeout(()=>{boot.classList.add('hide');shell.classList.add('ready');refreshReveal()},250);
  }
},82);

function haptic(type='light'){try{tg?.HapticFeedback?.impactOccurred(type)}catch(e){}}
function notify(msg){
  const t=$('#toast');if(!t)return;
  t.textContent=msg;t.classList.add('show');clearTimeout(notify._t);
  notify._t=setTimeout(()=>t.classList.remove('show'),1800);
}
function safeText(v,fallback='—'){return v===null||v===undefined||v===''?fallback:String(v)}
function fmtMoney(cents){return '$'+(Number(cents||0)/100).toFixed(2)}
async function api(path,opts={}){
  const headers={'Content-Type':'application/json','X-Telegram-Init-Data':tg?.initData||'',...(opts.headers||{})};
  const res=await fetch(path,{...opts,headers,cache:'no-store'});
  let data={};try{data=await res.json()}catch(e){data={ok:false,error:'bad_response'}}
  if(!res.ok||data.ok===false){const err=new Error(data.message||data.error||'request_failed');err.data=data;err.status=res.status;throw err}
  return data;
}

let observer;
function setupReveal(){
  observer?.disconnect();
  const reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
  if(reduce){$$('.reveal').forEach(el=>el.classList.add('seen'));return}
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
  window.scrollTo({top:0,behavior:'smooth'});
  try{
    if(tg?.BackButton){if(name==='home')tg.BackButton.hide();else tg.BackButton.show()}
    tg?.HapticFeedback?.selectionChanged?.();
  }catch(e){}
  refreshReveal();
}
$$('[data-tab]').forEach(btn=>btn.addEventListener('click',()=>switchTab(btn.dataset.tab)));
try{tg?.BackButton?.onClick(()=>switchTab('home'))}catch(e){}

function setLoadingError(){
  $('.main').innerHTML=`<div class="error-screen"><span class="eyebrow">// AUTH ERROR</span><h1>ОТКРОЙ<br>В TELEGRAM</h1><p>Приложение получает подтверждённые данные пользователя только при запуске из @VO1D_VPNbot.</p><button class="primary-btn" id="retryApp">ПОВТОРИТЬ</button></div>`;
  $('#retryApp')?.addEventListener('click',()=>location.reload());
}

function renderPlans(plans){
  const box=$('#plansList');if(!box)return;
  box.innerHTML=(plans||[]).map((p,i)=>`
    <article class="plan reveal ${i===1?'popular':''}">
      <div class="plan-top">
        <div class="plan-label"><span>0${i+1} / ACCESS</span><h3>${p.title}</h3></div>
        <div class="plan-price"><b>${p.stars} ⭐</b><small>${p.usd}</small></div>
      </div>
      ${i===1?'<div class="plan-badge">POPULAR</div>':''}
      <div class="plan-meta"><span>${p.days} DAYS</span><span>VLESS + REALITY</span><span>LONDON</span></div>
      <button class="primary-btn buy-stars" data-days="${p.days}">КУПИТЬ ЗА ${p.stars} ⭐</button>
    </article>`).join('');
  $$('.buy-stars').forEach(b=>b.addEventListener('click',()=>buyStars(Number(b.dataset.days),b)));
  if(state.tab==='plans')refreshReveal();
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
  $('#accountUntil').textContent=s.until_text||'—';
  $('#trialState').textContent=s.trial_claimed?'USED':'AVAILABLE';

  $('#nodeStatus').classList.toggle('active',!!infra.node_configured);
  $('#nodeStatus').innerHTML=`<i></i>${infra.node_configured?'NODE READY':'NODE OFFLINE'}`;
  $('#privacyValue').textContent=s.active?'READY':'OFF';
  $('#heroHint').textContent=s.active?'Доступ активен. Подключись через Happ и проверь внешний IP ниже.':'Подписка неактивна. Активируй пробный доступ или выбери тариф.';
  $('#daysLeft').textContent=s.active?(s.remaining_short||'ACTIVE'):'0';
  $('#untilText').textContent=s.active?('до '+s.until_text):'нет активного доступа';
  $('#planState').textContent=s.active?'ACTIVE':'OFFLINE';

  $('#accessStatus').textContent=s.active?'ACTIVE':'OFFLINE';
  $('#accessRemaining').textContent=s.active?(s.remaining_long||'активно'):'нужна подписка';
  $('#subUrl').textContent=s.subscription_url||'Активируй подписку, чтобы получить URL';
  $('#copySub').disabled=!s.subscription_url;
  $('#trialCard').classList.toggle('used',!!s.trial_claimed);

  renderPlans(me.plans||[]);
}

async function loadMe(){
  if(!tg?.initData){setLoadingError();return}
  try{
    const me=await api('/api/me');
    render(me);
    measurePing();
    setTimeout(()=>runPrivacyTest(false),550);
  }catch(e){
    console.error(e);setLoadingError();
  }
}

async function measurePing(){
  const out=$('#pingValue');if(!out)return;
  out.textContent='…';
  const values=[];
  for(let i=0;i<3;i++){
    const t=performance.now();
    try{await fetch('/api/ping?x='+Date.now(),{cache:'no-store'});values.push(performance.now()-t)}catch(e){}
  }
  if(!values.length){out.textContent='OFF';return}
  const ms=Math.round(values.reduce((a,b)=>a+b,0)/values.length);
  out.textContent=ms+' ms';
}

function animateScore(target){
  const text=$('#privacyScore'),ring=$('#scoreRing');
  if(!text||!ring)return;
  const start=performance.now(),duration=950;
  const from=Number((text.textContent||'0').replace(',','.'))||0;
  function frame(now){
    const p=Math.min(1,(now-start)/duration);
    const e=1-Math.pow(1-p,4);
    const value=from+(target-from)*e;
    text.textContent=value.toFixed(2).replace('.',',');
    ring.style.background=`conic-gradient(#f4f4f0 ${value}%,rgba(255,255,255,.07) 0)`;
    if(p<1)requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
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
    animateScore(Number(result.score||0));
    if(manual){
      try{tg?.HapticFeedback?.notificationOccurred?.(result.vo1d_route?'success':'warning')}catch(e){}
      notify(result.vo1d_route?'VO1D МАРШРУТ ПОДТВЕРЖДЁН':'IP УЗЛА VO1D НЕ ОБНАРУЖЕН');
    }
  }catch(e){
    $('#observedIp').textContent='ошибка проверки';
    $('#routeCheck').textContent='ERROR';
    $('#privacyLevel').textContent='НЕТ ДАННЫХ';
    $('#privacyBadge').textContent='ERROR';
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

function openTelegramUser(username){
  const url='https://t.me/'+username.replace('@','');
  if(tg?.openTelegramLink)tg.openTelegramLink(url);else location.href=url;
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
$('#supportBtn')?.addEventListener('click',()=>openTelegramUser('vo1d_root'));
$('#supportPayBtn')?.addEventListener('click',()=>openTelegramUser('vo1d_root'));
$('#openBotBtn')?.addEventListener('click',()=>openTelegramUser('VO1D_VPNbot'));

bindPressEffects();
setupReveal();
loadMe();
