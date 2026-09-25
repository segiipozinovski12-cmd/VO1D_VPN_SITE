const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const tg=window.Telegram?.WebApp;
const state={me:null,tab:'home',busy:false};

function telegramInit(){
  if(!tg)return;
  try{
    tg.ready(); tg.expand();
    tg.setHeaderColor?.('#050505');
    tg.setBackgroundColor?.('#050505');
    tg.setBottomBarColor?.('#050505');
    tg.disableVerticalSwipes?.();
  }catch(e){}
}
telegramInit();

const boot=$('#boot'),bootFill=$('#bootFill'),bootPct=$('#bootPct'),bootText=$('#bootText'),shell=$('#shell');
let bp=0;const bootSteps=[[10,'VERIFYING TELEGRAM'],[32,'AUTHENTICATING'],[58,'LOADING ACCOUNT'],[79,'SYNCING ACCESS'],[94,'READY']];
const bootTimer=setInterval(()=>{
  bp=Math.min(100,bp+Math.floor(Math.random()*8)+4);
  bootFill.style.width=bp+'%';bootPct.textContent=String(bp).padStart(2,'0')+'%';
  const match=[...bootSteps].reverse().find(x=>bp>=x[0]);if(match)bootText.textContent=match[1];
  if(bp>=100){clearInterval(bootTimer);setTimeout(()=>{boot.classList.add('hide');shell.classList.add('ready')},260)}
},90);

function haptic(type='light'){
  try{tg?.HapticFeedback?.impactOccurred(type)}catch(e){}
}
function notify(msg){
  const t=$('#toast');t.textContent=msg;t.classList.add('show');clearTimeout(notify._t);notify._t=setTimeout(()=>t.classList.remove('show'),1800);
}
function safeText(v,fallback='—'){return v===null||v===undefined||v===''?fallback:String(v)}
function fmtMoney(cents){return '$'+(Number(cents||0)/100).toFixed(2)}
async function api(path,opts={}){
  const headers={'Content-Type':'application/json','X-Telegram-Init-Data':tg?.initData||'',...(opts.headers||{})};
  const res=await fetch(path,{...opts,headers});
  let data={};try{data=await res.json()}catch(e){data={ok:false,error:'bad_response'}}
  if(!res.ok||data.ok===false){const err=new Error(data.message||data.error||'request_failed');err.data=data;err.status=res.status;throw err}
  return data;
}

function switchTab(name){
  state.tab=name;
  $$('.tab').forEach(x=>x.classList.toggle('active',x.id==='tab-'+name));
  $$('.nav-item').forEach(x=>x.classList.toggle('active',x.dataset.tab===name));
  window.scrollTo({top:0,behavior:'smooth'});
  try{
    if(tg?.BackButton){
      if(name==='home')tg.BackButton.hide();else tg.BackButton.show();
    }
    tg?.HapticFeedback?.selectionChanged?.();
  }catch(e){}
}
$$('[data-tab]').forEach(btn=>btn.addEventListener('click',()=>switchTab(btn.dataset.tab)));
try{tg?.BackButton?.onClick(()=>switchTab('home'))}catch(e){}

function setLoadingError(){
  $('.main').innerHTML=`<div class="error-screen"><span class="eyebrow">// AUTH ERROR</span><h1>ОТКРОЙ<br>В TELEGRAM</h1><p>Mini App получает безопасные данные пользователя только при запуске из @VO1D_VPNbot.</p><button class="primary-btn" id="retryApp">ПОВТОРИТЬ</button></div>`;
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
      <div class="plan-meta"><span>${p.days} DAYS</span><span>VLESS + REALITY</span><span>LONDON</span></div>
      ${i===1?'<div class="plan-badge">POPULAR</div>':''}
      <button class="primary-btn buy-stars" data-days="${p.days}">КУПИТЬ ЗА ${p.stars} ⭐</button>
    </article>`).join('');
  $$('.buy-stars').forEach(b=>b.addEventListener('click',()=>buyStars(Number(b.dataset.days),b)));
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
  $('#heroHint').textContent=s.active?'Твоя подписка активна. Персональный доступ готов к импорту в Happ.':'Подписка неактивна. Активируй пробный доступ или выбери тариф.';
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

async function activateTrial(){
  const btn=$('#trialBtn');if(state.busy)return;state.busy=true;btn.disabled=true;btn.textContent='АКТИВАЦИЯ…';haptic('medium');
  try{
    const r=await api('/api/trial',{method:'POST',body:'{}'});
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
  if(state.busy)return;state.busy=true;const old=btn.textContent;btn.disabled=true;btn.textContent='СОЗДАЁМ СЧЁТ…';haptic('medium');
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

$('#trialBtn')?.addEventListener('click',activateTrial);
$('#copySub')?.addEventListener('click',copySubscription);
$('#refreshBtn')?.addEventListener('click',async()=>{haptic('light');$('#refreshBtn').style.transform='rotate(180deg)';await loadMe();setTimeout(()=>$('#refreshBtn').style.transform='',250);notify('ДАННЫЕ ОБНОВЛЕНЫ')});
$('#pingCard')?.addEventListener('click',()=>{haptic('light');measurePing()});
$('#supportBtn')?.addEventListener('click',()=>openTelegramUser('vo1d_root'));
$('#supportPayBtn')?.addEventListener('click',()=>openTelegramUser('vo1d_root'));
$('#openBotBtn')?.addEventListener('click',()=>openTelegramUser('VO1D_VPNbot'));

loadMe();
