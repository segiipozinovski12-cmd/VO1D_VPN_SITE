import os, json, time, html, sqlite3, secrets, threading, urllib.request, urllib.parse, hashlib, hmac, mimetypes, ipaddress, uuid, socket, shutil, glob
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP, ROUND_CEILING
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

TOKEN=os.getenv("BOT_TOKEN","").strip()
ADMIN_ID=int(os.getenv("ADMIN_ID","8632158680"))
ADMIN_USERNAME=os.getenv("ADMIN_USERNAME","vo1d_root").lstrip("@")
CHANNEL_ID=int(os.getenv("CHANNEL_ID","0") or 0)
CHANNEL_USERNAME=os.getenv("CHANNEL_USERNAME","").lstrip("@")
CHANNEL_URL=os.getenv("CHANNEL_URL",("https://t.me/"+CHANNEL_USERNAME) if CHANNEL_USERNAME else "")
SITE_URL=os.getenv("SITE_URL","").rstrip("/")
PUBLIC_URL=os.getenv("PUBLIC_URL","").rstrip("/")
if not PUBLIC_URL and os.getenv("RAILWAY_PUBLIC_DOMAIN"):
    PUBLIC_URL="https://"+os.getenv("RAILWAY_PUBLIC_DOMAIN","").strip()
SUPPORT_URL=os.getenv("SUPPORT_URL",f"https://t.me/{ADMIN_USERNAME}")
MINI_APP_URL=os.getenv("MINI_APP_URL",(PUBLIC_URL+"/app") if PUBLIC_URL else "").rstrip("/")
TRIAL_HOURS=int(os.getenv("TRIAL_HOURS","24"))
PORT=int(os.getenv("PORT","8080"))
VPN_NODES=[x.strip() for x in os.getenv("VPN_NODES","").replace("\\n","\n").splitlines() if x.strip()]
BOT_USERNAME=os.getenv("BOT_USERNAME","VO1D_VPNbot").lstrip("@")
DEVICE_LIMIT=max(1,int(os.getenv("DEVICE_LIMIT","3")))
REFERRAL_REWARD_CENTS=max(0,int(os.getenv("REFERRAL_REWARD_CENTS","100")))
PER_USER_KEYS=os.getenv("PER_USER_KEYS","0").strip().lower() in ("1","true","yes","on")
XRAY_SYNC_SECRET=os.getenv("XRAY_SYNC_SECRET","").strip()

mount=os.getenv("RAILWAY_VOLUME_MOUNT_PATH","").strip()
DB_PATH=os.getenv("DB_PATH",(mount.rstrip("/")+"/vo1d.db") if mount else "vo1d.db")
os.makedirs(os.path.dirname(DB_PATH) or ".",exist_ok=True)
BASE_DIR=os.path.dirname(os.path.abspath(__file__))
WEBAPP_DIR=os.path.join(BASE_DIR,"webapp")
BUNDLED_AUDIO_PATH=os.path.join(WEBAPP_DIR,"audio","leaveamsg-slowed.mp3")
VOLUME_AUDIO_PATH=os.getenv("AUDIO_PATH",(mount.rstrip("/")+"/leaveamsg-slowed.mp3") if mount else "")
BACKUP_DIR=os.getenv("BACKUP_DIR",(mount.rstrip("/")+"/backups") if mount else os.path.join(BASE_DIR,"backups"))

PLANS={
  30: {"title":"1 месяц","usd":399,"stars":250},
  90: {"title":"3 месяца","usd":999,"stars":650},
  180:{"title":"6 месяцев","usd":1699,"stars":1100},
  365:{"title":"12 месяцев","usd":2799,"stars":1800},
}

# Внутренний баланс VO1D. Эти суммы — только быстрые кнопки:
# пользователь также может ввести произвольную сумму вручную.
TOPUP_STARS_PER_USD=Decimal("65")
TOPUP_MIN_CENTS=10
TOPUP_MAX_CENTS=10000
TOPUPS={
  500: {"title":"$5.00","stars":325},
  1000:{"title":"$10.00","stars":650},
  2000:{"title":"$20.00","stars":1300},
  3000:{"title":"$30.00","stars":1950},
  5000:{"title":"$50.00","stars":3250},
}

def now(): return int(time.time())
def dt(ts):
    return datetime.fromtimestamp(ts,timezone.utc).strftime("%d.%m.%Y %H:%M UTC") if ts else "—"
def money(c): return "$"+f"{c/100:.2f}"
def esc(s): return html.escape(str(s or ""))

def valid_topup_cents(cents):
    try:cents=int(cents)
    except:return False
    return TOPUP_MIN_CENTS<=cents<=TOPUP_MAX_CENTS

def topup_stars(cents):
    cents=int(cents)
    return int((Decimal(cents)*TOPUP_STARS_PER_USD/Decimal(100)).quantize(Decimal("1"),rounding=ROUND_CEILING))

def parse_topup_amount(raw):
    s=str(raw or "").strip().replace("$","").replace("USD","").replace("usd","").replace(" ","").replace(",",".")
    try:
        value=Decimal(s)
    except InvalidOperation:
        return None
    if not value.is_finite():return None
    cents=int((value*100).quantize(Decimal("1"),rounding=ROUND_HALF_UP))
    return cents if valid_topup_cents(cents) else None

def set_pending(uid,action,data=""):
    with db() as c:
        c.execute("""INSERT INTO pending_actions(user_id,action,data,created_at) VALUES(?,?,?,?)
          ON CONFLICT(user_id) DO UPDATE SET action=excluded.action,data=excluded.data,created_at=excluded.created_at""",
          (int(uid),str(action),str(data or ""),now()))

def get_pending(uid):
    with db() as c:return c.execute("SELECT * FROM pending_actions WHERE user_id=?",(int(uid),)).fetchone()

def clear_pending(uid):
    with db() as c:c.execute("DELETE FROM pending_actions WHERE user_id=?",(int(uid),))


def configured_node_ips():
    out=[]
    for node in VPN_NODES:
        try:
            host=urllib.parse.urlparse(node).hostname
            if not host: continue
            ipaddress.ip_address(host)
            if host not in out: out.append(host)
        except Exception:
            pass
    return out

VO1D_NODE_IPS=configured_node_ips()
NODE_STATUS={}
NODE_STATUS_LOCK=threading.Lock()


def db():
    c=sqlite3.connect(DB_PATH,timeout=30)
    c.row_factory=sqlite3.Row
    return c

def ensure_column(c,table,column,definition):
    cols={r["name"] for r in c.execute(f"PRAGMA table_info({table})").fetchall()}
    if column not in cols:
        c.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")

def init_db():
    with db() as c:
        c.executescript("""
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS users(
          id INTEGER PRIMARY KEY,
          username TEXT, first_name TEXT,
          joined_at INTEGER NOT NULL, last_seen INTEGER NOT NULL,
          trial_claimed INTEGER NOT NULL DEFAULT 0,
          sub_until INTEGER NOT NULL DEFAULT 0,
          banned INTEGER NOT NULL DEFAULT 0,
          balance_cents INTEGER NOT NULL DEFAULT 0,
          sub_token TEXT NOT NULL UNIQUE
        );
        CREATE TABLE IF NOT EXISTS payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          method TEXT NOT NULL,
          plan_days INTEGER NOT NULL,
          amount_stars INTEGER NOT NULL DEFAULT 0,
          amount_usd_cents INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'pending',
          created_at INTEGER NOT NULL,
          paid_at INTEGER NOT NULL DEFAULT 0,
          charge_id TEXT DEFAULT ''
        );
        CREATE TABLE IF NOT EXISTS balance_transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          kind TEXT NOT NULL,
          amount_cents INTEGER NOT NULL,
          reference TEXT DEFAULT '',
          created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS pending_actions(
          user_id INTEGER PRIMARY KEY,
          action TEXT NOT NULL,
          data TEXT DEFAULT '',
          created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS promo_codes(
          code TEXT PRIMARY KEY,
          reward_type TEXT NOT NULL,
          reward_value INTEGER NOT NULL,
          max_uses INTEGER NOT NULL DEFAULT 0,
          uses INTEGER NOT NULL DEFAULT 0,
          expires_at INTEGER NOT NULL DEFAULT 0,
          active INTEGER NOT NULL DEFAULT 1,
          created_by INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS promo_redemptions(
          code TEXT NOT NULL,
          user_id INTEGER NOT NULL,
          redeemed_at INTEGER NOT NULL,
          PRIMARY KEY(code,user_id)
        );
        CREATE TABLE IF NOT EXISTS referral_rewards(
          invitee_id INTEGER PRIMARY KEY,
          referrer_id INTEGER NOT NULL,
          reward_cents INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS reminders(
          user_id INTEGER NOT NULL,
          event_key TEXT NOT NULL,
          sent_at INTEGER NOT NULL,
          PRIMARY KEY(user_id,event_key)
        );
        CREATE TABLE IF NOT EXISTS devices(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          vpn_uuid TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          UNIQUE(user_id,name)
        );
        CREATE TABLE IF NOT EXISTS gift_codes(
          code TEXT PRIMARY KEY,
          days INTEGER NOT NULL,
          created_by INTEGER NOT NULL,
          redeemed_by INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          redeemed_at INTEGER NOT NULL DEFAULT 0,
          active INTEGER NOT NULL DEFAULT 1
        );
        CREATE TABLE IF NOT EXISTS subscription_events(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          days INTEGER NOT NULL,
          source TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          sub_until INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS trial_claims(
          user_id INTEGER PRIMARY KEY,
          claimed_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS meta(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
        """)
        ensure_column(c,"users","vpn_uuid","TEXT NOT NULL DEFAULT ''")
        ensure_column(c,"users","auto_renew","INTEGER NOT NULL DEFAULT 0")
        ensure_column(c,"users","auto_renew_days","INTEGER NOT NULL DEFAULT 30")
        ensure_column(c,"users","referrer_id","INTEGER NOT NULL DEFAULT 0")
        ensure_column(c,"users","referral_awarded","INTEGER NOT NULL DEFAULT 0")
        ensure_column(c,"users","preferred_node","INTEGER NOT NULL DEFAULT 0")
        ensure_column(c,"users","notifications","INTEGER NOT NULL DEFAULT 1")
        ensure_column(c,"users","welcome_done","INTEGER NOT NULL DEFAULT 0")
        ensure_column(c,"payments","reference","TEXT NOT NULL DEFAULT ''")
        rows=c.execute("SELECT id FROM users WHERE vpn_uuid='' OR vpn_uuid IS NULL").fetchall()
        for r in rows:
            c.execute("UPDATE users SET vpn_uuid=? WHERE id=?",(str(uuid.uuid4()),r["id"]))

        builtins=[
          ("VOID24","days",1,100),
          ("GHOST48","days",2,60),
          ("NIGHT3","days",3,40),
          ("WELCOME50","balance",50,100),
          ("LONDON1","days",1,100),
        ]
        for code,reward_type,reward_value,max_uses in builtins:
            c.execute("""INSERT OR IGNORE INTO promo_codes
              (code,reward_type,reward_value,max_uses,uses,expires_at,active,created_by,created_at)
              VALUES(?,?,?,?,0,0,1,0,?)""",(code,reward_type,reward_value,max_uses,now()))
init_db()

def api(method, payload=None, timeout=70):
    if not TOKEN: raise RuntimeError("BOT_TOKEN is not set")
    data=json.dumps(payload or {}).encode()
    req=urllib.request.Request(
        f"https://api.telegram.org/bot{TOKEN}/{method}",
        data=data, headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=timeout) as r:
        out=json.loads(r.read().decode())
    if not out.get("ok"): raise RuntimeError(out)
    return out.get("result")

def validate_webapp_init_data(init_data,max_age=86400):
    if not init_data:
        raise ValueError("Telegram initData is missing")
    pairs=urllib.parse.parse_qsl(init_data,keep_blank_values=True)
    params=dict(pairs)
    received_hash=params.pop("hash",None)
    if not received_hash:
        raise ValueError("Telegram hash is missing")
    check="\n".join(f"{k}={v}" for k,v in sorted(params.items()))
    secret=hmac.new(b"WebAppData",TOKEN.encode(),hashlib.sha256).digest()
    calculated=hmac.new(secret,check.encode(),hashlib.sha256).hexdigest()
    if not hmac.compare_digest(calculated,received_hash):
        raise ValueError("Telegram signature is invalid")
    auth_date=int(params.get("auth_date","0") or 0)
    if not auth_date or abs(now()-auth_date)>max_age:
        raise ValueError("Telegram session is expired")
    try:
        user=json.loads(params.get("user","{}"))
    except Exception:
        user={}
    if not user.get("id"):
        raise ValueError("Telegram user is missing")
    return user

def webapp_user_payload(tg_user,row):
    is_active=active(row)
    seconds=max(0,int(row["sub_until"])-now()) if row else 0
    days=seconds//86400
    hours=(seconds%86400)//3600
    remaining_short=(f"{days}d" if days else f"{hours}h") if seconds else "0"
    sub_url=(f"{PUBLIC_URL}/sub/{row['sub_token']}" if is_active and PUBLIC_URL else "")
    return {
      "ok":True,
      "user":{
        "id":int(row["id"]),
        "username":tg_user.get("username") or row["username"] or "",
        "first_name":tg_user.get("first_name") or row["first_name"] or "",
        "last_name":tg_user.get("last_name") or "",
        "photo_url":tg_user.get("photo_url") or "",
        "balance_cents":int(row["balance_cents"]),
      },
      "subscription":{
        "active":is_active,
        "banned":bool(row["banned"]),
        "trial_claimed":bool(row["trial_claimed"]),
        "until":int(row["sub_until"]),
        "until_text":dt(row["sub_until"]),
        "remaining_short":remaining_short,
        "remaining_long":remaining(row["sub_until"]),
        "subscription_url":sub_url,
      },
      "infrastructure":{
        "node_configured":bool(VPN_NODES),
        "nodes":len(VPN_NODES),
        "location":"London",
        "protocol":"VLESS + REALITY",
        "transport":"TCP / 443",
      },
      "plans":[
        {"days":days,"title":p["title"],"stars":p["stars"],"usd":money(p["usd"])}
        for days,p in PLANS.items()
      ],
      "links":{
        "support":SUPPORT_URL,
        "bot":"https://t.me/VO1D_VPNbot",
        "channel":CHANNEL_URL,
        "site":SITE_URL,
      }
    }

def create_star_invoice_link(uid,days):
    p=PLANS[days]
    payload=f"sub:{uid}:{days}:{secrets.token_hex(6)}"
    return api("createInvoiceLink",{
      "title":f"VO1D_VPN — {p['title']}",
      "description":f"Доступ VO1D_VPN на {days} дней",
      "payload":payload,
      "provider_token":"",
      "currency":"XTR",
      "prices":[{"label":p["title"],"amount":p["stars"]}],
    },30)

def send(chat_id,text,kb=None,disable_preview=True):
    p={"chat_id":chat_id,"text":text,"parse_mode":"HTML",
       "disable_web_page_preview":disable_preview}
    if kb: p["reply_markup"]={"inline_keyboard":kb}
    return api("sendMessage",p)

def answer_cb(cid,text="",alert=False):
    try: api("answerCallbackQuery",{"callback_query_id":cid,"text":text,"show_alert":alert},20)
    except Exception: pass

def button(text,cb=None,url=None,web_app=None):
    b={"text":text}
    if cb: b["callback_data"]=cb
    if url: b["url"]=url
    if web_app: b["web_app"]={"url":web_app}
    return b

def upsert_user(u):
    uid=int(u["id"]); username=u.get("username",""); first=u.get("first_name","")
    with db() as c:
        row=c.execute("SELECT id FROM users WHERE id=?",(uid,)).fetchone()
        if row:
            c.execute("UPDATE users SET username=?,first_name=?,last_seen=? WHERE id=?",
                      (username,first,now(),uid))
        else:
            c.execute("INSERT INTO users(id,username,first_name,joined_at,last_seen,sub_token,vpn_uuid) VALUES(?,?,?,?,?,?,?)",
                      (uid,username,first,now(),now(),secrets.token_urlsafe(24),str(uuid.uuid4())))
    return get_user(uid)

def get_user(uid):
    with db() as c: return c.execute("SELECT * FROM users WHERE id=?",(int(uid),)).fetchone()

def active(row):
    return bool(row and not row["banned"] and row["sub_until"]>now())

def remaining(ts):
    s=max(0,int(ts)-now())
    if not s:return "0 минут"
    d,s=divmod(s,86400); h,s=divmod(s,3600); m=s//60
    return (f"{d} дн. {h} ч." if d else f"{h} ч. {m} мин.")

def add_days(uid,days,source="grant"):
    uid=int(uid); days=int(days)
    with db() as c:
        c.execute("BEGIN IMMEDIATE")
        r=c.execute("SELECT sub_until FROM users WHERE id=?",(uid,)).fetchone()
        if not r:return 0
        base=max(now(),int(r["sub_until"]))
        end=base+days*86400
        c.execute("UPDATE users SET sub_until=? WHERE id=?",(end,uid))
        c.execute("INSERT INTO subscription_events(user_id,days,source,created_at,sub_until) VALUES(?,?,?,?,?)",
                  (uid,days,str(source),now(),end))
        return end

def change_balance(uid,delta_cents,kind="adjustment",reference=""):
    uid=int(uid); delta_cents=int(delta_cents)
    with db() as c:
        c.execute("BEGIN IMMEDIATE")
        r=c.execute("SELECT balance_cents FROM users WHERE id=?",(uid,)).fetchone()
        if not r:return None
        new_balance=int(r["balance_cents"])+delta_cents
        if new_balance<0:return None
        c.execute("UPDATE users SET balance_cents=? WHERE id=?",(new_balance,uid))
        c.execute("INSERT INTO balance_transactions(user_id,kind,amount_cents,reference,created_at) VALUES(?,?,?,?,?)",
                  (uid,kind,delta_cents,str(reference or ""),now()))
        return new_balance

def buy_with_balance(uid,days):
    uid=int(uid); days=int(days)
    p=PLANS.get(days)
    if not p:return None,"bad_plan"
    with db() as c:
        c.execute("BEGIN IMMEDIATE")
        r=c.execute("SELECT balance_cents,sub_until,banned FROM users WHERE id=?",(uid,)).fetchone()
        if not r:return None,"user_not_found"
        if r["banned"]:return None,"banned"
        price=int(p["usd"])
        balance=int(r["balance_cents"])
        if balance<price:return balance,"insufficient"
        end=max(now(),int(r["sub_until"]))+days*86400
        new_balance=balance-price
        cur=c.execute("""INSERT INTO payments(user_id,method,plan_days,amount_stars,amount_usd_cents,status,created_at,paid_at,charge_id)
          VALUES(?,?,?,?,?,?,?,?,?)""",(uid,"balance",days,0,price,"paid",now(),now(),""))
        pid=cur.lastrowid
        c.execute("UPDATE users SET balance_cents=?,sub_until=? WHERE id=?",(new_balance,end,uid))
        c.execute("INSERT INTO balance_transactions(user_id,kind,amount_cents,reference,created_at) VALUES(?,?,?,?,?)",
                  (uid,"subscription",-price,f"payment:{pid}",now()))
        c.execute("INSERT INTO subscription_events(user_id,days,source,created_at,sub_until) VALUES(?,?,?,?,?)",
                  (uid,days,"balance",now(),end))
        return {"end":end,"balance":new_balance,"payment_id":pid},"ok"

def normalize_code(value):
    return "".join(ch for ch in str(value or "").upper().strip() if ch.isalnum() or ch in "-_")[:40]

def assign_referrer(uid,referrer_id):
    uid=int(uid); referrer_id=int(referrer_id)
    if uid==referrer_id:return False
    with db() as c:
        ref=c.execute("SELECT id FROM users WHERE id=?",(referrer_id,)).fetchone()
        row=c.execute("SELECT referrer_id FROM users WHERE id=?",(uid,)).fetchone()
        if not ref or not row or int(row["referrer_id"] or 0):return False
        c.execute("UPDATE users SET referrer_id=? WHERE id=?",(referrer_id,uid))
        return True

def award_referral_if_needed(invitee_id):
    invitee_id=int(invitee_id)
    with db() as c:
        c.execute("BEGIN IMMEDIATE")
        u=c.execute("SELECT referrer_id,referral_awarded FROM users WHERE id=?",(invitee_id,)).fetchone()
        if not u or int(u["referral_awarded"] or 0):return None
        referrer=int(u["referrer_id"] or 0)
        if not referrer or referrer==invitee_id:return None
        if c.execute("SELECT invitee_id FROM referral_rewards WHERE invitee_id=?",(invitee_id,)).fetchone():
            c.execute("UPDATE users SET referral_awarded=1 WHERE id=?",(invitee_id,))
            return None
        rr=c.execute("SELECT balance_cents FROM users WHERE id=?",(referrer,)).fetchone()
        if not rr:return None
        reward=REFERRAL_REWARD_CENTS
        new_balance=int(rr["balance_cents"])+reward
        c.execute("UPDATE users SET balance_cents=? WHERE id=?",(new_balance,referrer))
        c.execute("UPDATE users SET referral_awarded=1 WHERE id=?",(invitee_id,))
        c.execute("INSERT INTO referral_rewards(invitee_id,referrer_id,reward_cents,created_at) VALUES(?,?,?,?)",
                  (invitee_id,referrer,reward,now()))
        c.execute("INSERT INTO balance_transactions(user_id,kind,amount_cents,reference,created_at) VALUES(?,?,?,?,?)",
                  (referrer,"referral",reward,f"invitee:{invitee_id}",now()))
        return referrer,reward,new_balance

def notify_referral_reward(invitee_id):
    result=award_referral_if_needed(invitee_id)
    if not result:return
    referrer,reward,new_balance=result
    try:
        send(referrer,
          f"🎉 <b>Реферальный бонус</b>\n\nДруг впервые оплатил подписку. "
          f"На баланс начислено <b>{money(reward)}</b>.\nБаланс: <b>{money(new_balance)}</b>.")
    except Exception:pass

def redeem_code(uid,raw_code):
    code=normalize_code(raw_code)
    if not code:return False,"Пустой код."
    with db() as c:
        c.execute("BEGIN IMMEDIATE")
        gift=c.execute("SELECT * FROM gift_codes WHERE code=?",(code,)).fetchone()
        if gift:
            if not gift["active"] or int(gift["redeemed_by"] or 0):
                return False,"Этот подарочный код уже использован."
            days=int(gift["days"])
            row=c.execute("SELECT sub_until FROM users WHERE id=?",(uid,)).fetchone()
            if not row:return False,"Пользователь не найден."
            end=max(now(),int(row["sub_until"]))+days*86400
            c.execute("UPDATE users SET sub_until=? WHERE id=?",(end,uid))
            c.execute("UPDATE gift_codes SET redeemed_by=?,redeemed_at=?,active=0 WHERE code=?",(uid,now(),code))
            c.execute("INSERT INTO subscription_events(user_id,days,source,created_at,sub_until) VALUES(?,?,?,?,?)",
                      (uid,days,f"gift:{code}",now(),end))
            return True,f"🎁 Подарок активирован: <b>+{days} дней</b>.\nПодписка до {dt(end)}."

        p=c.execute("SELECT * FROM promo_codes WHERE code=?",(code,)).fetchone()
        if not p:return False,"Промокод не найден."
        if not p["active"]:return False,"Промокод отключён."
        if int(p["expires_at"] or 0)>0 and int(p["expires_at"])<now():return False,"Срок промокода истёк."
        if int(p["max_uses"] or 0)>0 and int(p["uses"])>=int(p["max_uses"]):return False,"Лимит активаций промокода исчерпан."
        if c.execute("SELECT 1 FROM promo_redemptions WHERE code=? AND user_id=?",(code,uid)).fetchone():
            return False,"Ты уже активировал этот промокод."
        reward_type=p["reward_type"]; value=int(p["reward_value"])
        if reward_type=="days":
            row=c.execute("SELECT sub_until FROM users WHERE id=?",(uid,)).fetchone()
            end=max(now(),int(row["sub_until"]))+value*86400
            c.execute("UPDATE users SET sub_until=? WHERE id=?",(end,uid))
            c.execute("INSERT INTO subscription_events(user_id,days,source,created_at,sub_until) VALUES(?,?,?,?,?)",
                      (uid,value,f"promo:{code}",now(),end))
            message=f"✅ Промокод активирован: <b>+{value} дней</b>.\nПодписка до {dt(end)}."
        elif reward_type=="balance":
            row=c.execute("SELECT balance_cents FROM users WHERE id=?",(uid,)).fetchone()
            new_balance=int(row["balance_cents"])+value
            c.execute("UPDATE users SET balance_cents=? WHERE id=?",(new_balance,uid))
            c.execute("INSERT INTO balance_transactions(user_id,kind,amount_cents,reference,created_at) VALUES(?,?,?,?,?)",
                      (uid,"promo",value,f"promo:{code}",now()))
            message=f"✅ Промокод активирован: <b>+{money(value)}</b> на баланс.\nБаланс: <b>{money(new_balance)}</b>."
        else:
            return False,"Неизвестный тип награды."
        c.execute("INSERT INTO promo_redemptions(code,user_id,redeemed_at) VALUES(?,?,?)",(code,uid,now()))
        c.execute("UPDATE promo_codes SET uses=uses+1 WHERE code=?",(code,))
        return True,message

def balance_history(uid):
    with db() as c:rows=c.execute("SELECT * FROM balance_transactions WHERE user_id=? ORDER BY id DESC LIMIT 15",(uid,)).fetchall()
    text="<b>🧾 История баланса</b>\n\n"
    if not rows:text+="Пока операций нет."
    labels={"stars_topup":"Stars","manual_topup":"Пополнение","subscription":"Подписка","promo":"Промокод","referral":"Реферал","admin":"Админ"}
    for r in rows:
        amount=int(r["amount_cents"]); sign="+" if amount>=0 else "−"
        text+=f"{sign}<b>{money(abs(amount))}</b> · {esc(labels.get(r['kind'],r['kind']))}\n"
    send(uid,text,[[button("◀️ Баланс","balance")]])

def subscription_history(uid):
    with db() as c:rows=c.execute("SELECT * FROM subscription_events WHERE user_id=? ORDER BY id DESC LIMIT 15",(uid,)).fetchall()
    text="<b>🕘 История подписки</b>\n\n"
    if not rows:text+="Пока продлений нет."
    for r in rows:
        text+=f"+<b>{r['days']} дн.</b> · {esc(r['source'])} · до {dt(r['sub_until'])}\n"
    send(uid,text,[[button("◀️ Ещё","more")]])

def promo_prompt(uid):
    set_pending(uid,"redeem_code")
    send(uid,
      "<b>🎟 Промокод / подарок</b>\n\nОтправь код одним сообщением.",
      [[button("❌ Отмена","more")]])

def referral_screen(uid):
    with db() as c:
        invited=c.execute("SELECT COUNT(*) n FROM users WHERE referrer_id=?",(uid,)).fetchone()["n"]
        paid=c.execute("SELECT COUNT(*) n FROM referral_rewards WHERE referrer_id=?",(uid,)).fetchone()["n"]
    link=f"https://t.me/{BOT_USERNAME}?start=ref_{uid}"
    send(uid,
      f"<b>👥 Пригласить друга</b>\n\n"
      f"За первую оплаченную подписку приглашённого ты получишь <b>{money(REFERRAL_REWARD_CENTS)}</b> на баланс.\n\n"
      f"Приглашено: <b>{invited}</b>\nС бонусом: <b>{paid}</b>\n\n"
      f"Твоя ссылка:\n<code>{esc(link)}</code>",
      [[button("◀️ Ещё","more")]])

def auto_renew_screen(uid):
    r=get_user(uid)
    state="ВКЛЮЧЕНО" if r["auto_renew"] else "ВЫКЛЮЧЕНО"
    days=int(r["auto_renew_days"] or 30)
    kb=[[button("✅ Выключить" if r["auto_renew"] else "⚡ Включить", "autorenew:toggle")]]
    kb += [[button(("✓ " if days==d else "")+PLANS[d]["title"],f"autorenew:{d}")] for d in PLANS]
    kb.append([button("◀️ Ещё","more")])
    send(uid,
      f"<b>♻️ Автопродление</b>\n\nСтатус: <b>{state}</b>\nТариф: <b>{PLANS.get(days,PLANS[30])['title']}</b>\n"
      "Оплата идёт только с внутреннего баланса примерно за 24 часа до окончания подписки.",kb)

def node_name(index,node=None):
    try:
        node=node or VPN_NODES[index]
        p=urllib.parse.urlsplit(node)
        if p.fragment:return urllib.parse.unquote(p.fragment)
        return p.hostname or f"NODE-{index+1}"
    except Exception:return f"NODE-{index+1}"

def node_target(node):
    try:
        p=urllib.parse.urlsplit(node)
        return p.hostname,int(p.port or 443)
    except Exception:return None,None

def probe_node(index,timeout=2.5):
    if index<0 or index>=len(VPN_NODES):return False,None
    host,port=node_target(VPN_NODES[index])
    if not host:return False,None
    started=time.monotonic()
    try:
        with socket.create_connection((host,port),timeout=timeout):pass
        return True,int((time.monotonic()-started)*1000)
    except Exception:return False,None

def servers_screen(uid):
    r=get_user(uid); preferred=int(r["preferred_node"] or 0)
    kb=[]
    for i,node in enumerate(VPN_NODES):
        with NODE_STATUS_LOCK: st=NODE_STATUS.get(i,{})
        online=st.get("online")
        icon="🟢" if online is True else ("🔴" if online is False else "⚪")
        chosen="✓ " if i==preferred else ""
        kb.append([button(f"{chosen}{icon} {node_name(i,node)}",f"server:{i}")])
    kb.append([button("◀️ Ещё","more")])
    send(uid,
      "<b>🌐 Серверы VO1D</b>\n\nВыбранный сервер ставится первым в подписке Happ. "
      "Статус проверяется реальным TCP-соединением.",kb)

def diagnostics(uid):
    r=get_user(uid); idx=int(r["preferred_node"] or 0)
    online,lat=probe_node(idx)
    checks=[
      ("Подписка","OK" if active(r) else "OFF"),
      ("Subscription URL","OK" if PUBLIC_URL else "ERROR"),
      (node_name(idx),"ONLINE" if online else "OFFLINE"),
      ("Конфигурация","READY" if VPN_NODES else "EMPTY"),
    ]
    ok=sum(v in ("OK","ONLINE","READY") for _,v in checks)
    text=f"<b>🧪 Диагностика VO1D</b>\n\nРезультат: <b>{ok}/{len(checks)}</b>\n\n"
    for k,v in checks:text+=f"{'✅' if v in ('OK','ONLINE','READY') else '❌'} {esc(k)}: <b>{v}</b>\n"
    if lat is not None:text+=f"\nОтклик TCP узла: <b>{lat} ms</b>\n"
    kb=[]
    if MINI_APP_URL:kb.append([button("🔎 Проверить внешний IP",web_app=MINI_APP_URL)])
    kb.append([button("◀️ Ещё","more")])
    send(uid,text,kb)

def devices_screen(uid):
    with db() as c:rows=c.execute("SELECT * FROM devices WHERE user_id=? ORDER BY id",(uid,)).fetchall()
    kb=[]
    for r in rows:kb.append([button(f"📱 {r['name']} · удалить",f"device_del:{r['id']}")])
    if len(rows)<DEVICE_LIMIT:kb.append([button("➕ Добавить устройство","device_add")])
    kb.append([button("◀️ Ещё","more")])
    text=f"<b>📱 Мои устройства</b>\n\nДобавлено: <b>{len(rows)}/{DEVICE_LIMIT}</b>."
    if not PER_USER_KEYS:text+="\n\nСейчас список используется для управления аккаунтом; жёсткое отключение отдельных устройств включится после синхронизации персональных ключей с Xray."
    send(uid,text,kb)

def add_device(uid,name):
    name=" ".join(str(name or "").strip().split())[:32]
    if len(name)<2:return False,"Название слишком короткое."
    with db() as c:
        count=c.execute("SELECT COUNT(*) n FROM devices WHERE user_id=?",(uid,)).fetchone()["n"]
        if count>=DEVICE_LIMIT:return False,f"Лимит устройств: {DEVICE_LIMIT}."
        try:
            c.execute("INSERT INTO devices(user_id,name,vpn_uuid,created_at) VALUES(?,?,?,?)",
                      (uid,name,str(uuid.uuid4()),now()))
        except sqlite3.IntegrityError:return False,"Устройство с таким названием уже есть."
    return True,"Устройство добавлено."

def reset_access(uid):
    token=secrets.token_urlsafe(24); new_uuid=str(uuid.uuid4())
    with db() as c:c.execute("UPDATE users SET sub_token=?,vpn_uuid=? WHERE id=?",(token,new_uuid,uid))
    if PER_USER_KEYS:
        return "✅ Ссылка и персональный VPN-ключ заменены. После синхронизации Xray старый ключ перестанет работать."
    return "✅ Персональная subscription-ссылка заменена. Старый импортированный VPN-конфиг пока не отключается сервером — для этого нужен режим персональных Xray-ключей."

def claim_trial(uid):
    uid=int(uid)
    with db() as c:
        c.execute("BEGIN IMMEDIATE")
        r=c.execute("SELECT trial_claimed,sub_until,banned FROM users WHERE id=?",(uid,)).fetchone()
        if not r:return None,"missing"
        if r["banned"]:return None,"banned"
        if r["trial_claimed"] or c.execute("SELECT 1 FROM trial_claims WHERE user_id=?",(uid,)).fetchone():
            return int(r["sub_until"]),"used"
        end=max(now(),int(r["sub_until"]))+TRIAL_HOURS*3600
        c.execute("UPDATE users SET trial_claimed=1,sub_until=? WHERE id=?",(end,uid))
        c.execute("INSERT INTO trial_claims(user_id,claimed_at) VALUES(?,?)",(uid,now()))
        c.execute("INSERT INTO subscription_events(user_id,days,source,created_at,sub_until) VALUES(?,?,?,?,?)",
                  (uid,max(1,TRIAL_HOURS//24),"trial",now(),end))
        return end,"ok"

def more_menu(uid):
    r=get_user(uid)
    send(uid,
      "<b>⚙️ VO1D Control</b>\nВыбери раздел:",
      [[button("♻️ Автопродление","autorenew"),button("🌐 Серверы","servers")],
       [button("🧪 Диагностика","diagnostics"),button("📱 Устройства","devices")],
       [button("🎟 Промокод","promo"),button("👥 Рефералы","referral")],
       [button("🎁 Подарки","gifts"),button("🕘 История подписки","sub_history")],
       [button("🔔 Уведомления: "+("ON" if r["notifications"] else "OFF"),"notifications")],
       [button("🔐 Сбросить доступ","reset_access")],
       [button("◀️ Меню","menu")]])

def gift_code_value():
    alphabet="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return "VOID-"+"".join(secrets.choice(alphabet) for _ in range(4))+"-"+"".join(secrets.choice(alphabet) for _ in range(4))

def create_gift_code(uid,days):
    while True:
        code=gift_code_value()
        with db() as c:
            try:
                c.execute("INSERT INTO gift_codes(code,days,created_by,created_at) VALUES(?,?,?,?)",(code,days,uid,now()))
                return code
            except sqlite3.IntegrityError:pass

def gifts_screen(uid):
    send(uid,
      "<b>🎁 Подарки VO1D</b>\n\nМожно подарить подписку человеку по Telegram ID или купить код, который он активирует сам.",
      [[button("👤 Подарить пользователю","gift_direct")],
       [button("🎫 Купить подарочный код","gift_code")],
       [button("🎟 Активировать код","promo")],
       [button("◀️ Ещё","more")]])

def gift_plan_menu(uid,mode):
    kb=[[button(p["title"],f"{mode}:{days}")] for days,p in PLANS.items()]
    kb.append([button("◀️ Подарки","gifts")])
    title="кому подарить" if mode=="giftplan" else "для подарочного кода"
    send(uid,f"<b>🎁 Выбери срок {title}</b>",kb)

def direct_gift_recipient_prompt(uid,days):
    set_pending(uid,"gift_recipient",json.dumps({"days":int(days)}))
    send(uid,
      f"<b>Подарок · {PLANS[days]['title']}</b>\n\nОтправь Telegram ID получателя. "
      "Получатель должен хотя бы один раз запустить @"+BOT_USERNAME+".",
      [[button("❌ Отмена","gifts")]])

def direct_gift_payment(uid,target,days):
    if not get_user(target):return send(uid,"Получатель ещё не запускал бота.",[[button("◀️ Подарки","gifts")]])
    p=PLANS[days]
    send(uid,
      f"<b>🎁 Подарок</b>\n\nПолучатель: <code>{target}</code>\nСрок: <b>{p['title']}</b>\nЦена: <b>{money(p['usd'])}</b>",
      [[button(f"💰 С баланса · {money(p['usd'])}",f"giftpay:{target}:{days}:balance")],
       [button(f"⭐ Telegram Stars · {p['stars']} ⭐",f"giftpay:{target}:{days}:stars")],
       [button("◀️ Подарки","gifts")]])

def gift_code_payment(uid,days):
    p=PLANS[days]
    send(uid,
      f"<b>🎫 Подарочный код · {p['title']}</b>\n\nПосле оплаты получишь одноразовый код.",
      [[button(f"💰 С баланса · {money(p['usd'])}",f"gcodepay:{days}:balance")],
       [button(f"⭐ Telegram Stars · {p['stars']} ⭐",f"gcodepay:{days}:stars")],
       [button("◀️ Подарки","gifts")]])

def welcome_screen(uid,step=1):
    if step==1:
        return send(uid,
          "<b>VO1D_VPN // WELCOME</b>\n\nVO1D выдаёт персональную subscription-ссылку для Happ и управляет сроком доступа из Telegram.",
          [[button("ДАЛЬШЕ →","welcome:2")]])
    if step==2:
        return send(uid,
          "<b>02 // БЫСТРЫЙ СТАРТ</b>\n\nАктивируй пробный доступ, добавь ссылку в Happ и затем проверь внешний IP в Mini App.",
          [[button("ДАЛЬШЕ →","welcome:3")]])
    with db() as c:c.execute("UPDATE users SET welcome_done=1 WHERE id=?",(uid,))
    send(uid,
      "<b>03 // ГОТОВО</b>\n\nБаланс, серверы, подарки, промокоды и диагностика находятся в разделе «Ещё».",
      [[button("🎁 Пробный доступ","activate_trial")],[button("⚫ Открыть VO1D",web_app=MINI_APP_URL)] if MINI_APP_URL else [button("⚙️ Открыть меню","menu")],
       [button("⚙️ Меню","menu")]])

def main_kb(uid):
    rows=[]
    if MINI_APP_URL:
        rows.append([button("⚫ Открыть VO1D Mini App",web_app=MINI_APP_URL)])
    rows += [
      [button("👤 Профиль","profile"),button("💳 Баланс","balance")],
      [button("💎 Подписка","plans"),button("⚡ Подключить","connect")],
      [button("⚙️ Ещё","more"),button("📖 Инструкция","guide")],
      [button("🛟 Поддержка",url=SUPPORT_URL)],
    ]
    if uid==ADMIN_ID: rows.append([button("🛠 Админ-панель","admin")])
    return rows

def start_screen(uid,first=""):
    r=get_user(uid)
    if CHANNEL_ID and not is_member(uid):
        rows=[]
        if CHANNEL_URL: rows.append([button("📢 Подписаться на канал",url=CHANNEL_URL)])
        rows.append([button("✅ Я подписался","check_sub")])
        text=(f"<b>VO1D_VPN</b>\n\nДобро пожаловать, {esc(first)}.\n"
              "Чтобы получить доступ к сервису и бонусной пробной подписке, подпишись на канал.")
        return send(uid,text,rows)
    if r and not r["welcome_done"]:
        return welcome_screen(uid,1)
    send(uid,"<b>VO1D_VPN</b>\n\nСистема готова. Управление доступом — прямо здесь.",main_kb(uid))

def is_member(uid):
    if not CHANNEL_ID:return True
    try:
        r=api("getChatMember",{"chat_id":CHANNEL_ID,"user_id":uid},25)
        return r.get("status") in ("creator","administrator","member") or bool(r.get("is_member"))
    except Exception:
        return False

def profile(uid):
    r=get_user(uid)
    status="🔴 заблокирован" if r["banned"] else ("🟢 активна" if active(r) else "⚪ неактивна")
    uname="@"+r["username"] if r["username"] else "—"
    send(uid,
      f"<b>👤 Профиль VO1D</b>\n\n"
      f"ID: <code>{uid}</code>\nUsername: {esc(uname)}\n"
      f"Статус: {status}\n"
      f"До: <b>{dt(r['sub_until'])}</b>\n"
      f"Осталось: <b>{remaining(r['sub_until'])}</b>\n"
      f"Баланс: <b>{money(r['balance_cents'])}</b>",
      [[button("💳 Пополнить баланс","topup")],[button("💎 Купить подписку","plans")],[button("⚡ Подключить","connect")],[button("◀️ Меню","menu")]])

def balance_screen(uid):
    clear_pending(uid)
    r=get_user(uid)
    if not r:return
    send(uid,
      f"<b>💳 Баланс VO1D</b>\n\n"
      f"Доступно: <b>{money(r['balance_cents'])}</b>\n\n"
      "Баланс можно пополнять и использовать для покупки любой подписки VO1D. "
      "Внутренний баланс не выводится обратно в деньги.",
      [[button("➕ Пополнить баланс","topup")],
       [button("🧾 История операций","balance_history")],
       [button("💎 Купить подписку","plans")],
       [button("◀️ Меню","menu")]])

def topup_menu(uid):
    r=get_user(uid)
    set_pending(uid,"topup_amount")
    kb=[]
    row=[]
    for cents,p in TOPUPS.items():
        row.append(button(f"+{p['title']}",f"topup:{cents}"))
        if len(row)==2:
            kb.append(row);row=[]
    if row:kb.append(row)
    kb.append([button("❌ Отмена","balance")])
    send(uid,
      f"<b>➕ Пополнение баланса</b>\n\n"
      f"Сейчас: <b>{money(r['balance_cents'])}</b>\n\n"
      f"Отправь <b>любую сумму одним сообщением</b>, например:\n"
      f"<code>7.50</code> или <code>12</code>\n\n"
      f"Допустимый диапазон: <b>{money(TOPUP_MIN_CENTS)}–{money(TOPUP_MAX_CENTS)}</b>.\n"
      "Либо используй быструю кнопку:",kb)

def topup_methods(uid,cents):
    cents=int(cents)
    if not valid_topup_cents(cents):
        return send(uid,"Некорректная сумма пополнения.",[[button("↩️ Ввести другую сумму","topup")]])
    stars=topup_stars(cents)
    clear_pending(uid)
    send(uid,
      f"<b>Пополнение баланса</b>\n\n"
      f"На баланс: <b>{money(cents)}</b>\n"
      f"Итог через Telegram Stars: <b>{stars} ⭐</b>\n"
      f"Карта / криптовалюта: <b>{money(cents)}</b>\n\n"
      "Выбери способ оплаты:",
      [[button(f"⭐ Оплатить {stars} Stars",f"topup_pay:{cents}:stars")],
       [button("₿ Криптовалюта",f"topup_pay:{cents}:crypto"),button("💳 Карта",f"topup_pay:{cents}:card")],
       [button("✍️ Другая сумма","topup")],
       [button("◀️ Баланс","balance")]])

def plans(uid):
    kb=[]
    for days,p in PLANS.items():
        kb.append([button(f"{p['title']} · {money(p['usd'])} · {p['stars']} ⭐",f"plan:{days}")])
    kb.append([button("◀️ Меню","menu")])
    r=get_user(uid)
    send(uid,
      f"<b>💎 Подписка VO1D_VPN</b>\n\n"
      f"Баланс: <b>{money(r['balance_cents'])}</b>\n"
      "Выбери срок. На следующем шаге можно оплатить с баланса или другим способом.",kb)

def payment_methods(uid,days):
    p=PLANS.get(days)
    if not p:return
    send(uid,
      f"<b>{p['title']}</b>\nЦена: <b>{money(p['usd'])}</b> или <b>{p['stars']} ⭐</b>\n\n"
      f"Баланс: <b>{money(get_user(uid)['balance_cents'])}</b>\n\n"
      "Выбери способ оплаты:",
      [[button(f"💰 С баланса · {money(p['usd'])}",f"pay:{days}:balance")],
       [button("⭐ Telegram Stars",f"pay:{days}:stars")],
       [button("₿ Криптовалюта",f"pay:{days}:crypto"),button("💳 Банковская карта",f"pay:{days}:card")],
       [button("◀️ Назад","plans")]])

def record_payment(uid,method,days=0,amount_stars=0,amount_cents=0,status="pending",charge="",reference=""):
    with db() as c:
        cur=c.execute("""INSERT INTO payments(user_id,method,plan_days,amount_stars,amount_usd_cents,status,created_at,paid_at,charge_id,reference)
          VALUES(?,?,?,?,?,?,?,?,?,?)""",(uid,method,int(days),int(amount_stars),int(amount_cents),status,now(),now() if status=="paid" else 0,charge,str(reference or "")))
        return cur.lastrowid

def make_payment(uid,method,days,status="pending",charge="",reference=""):
    p=PLANS[days]
    return record_payment(uid,method,days,p["stars"] if method=="stars" else 0,p["usd"],status,charge,reference)

def star_invoice(uid,days):
    p=PLANS[days]
    payload=f"sub:{uid}:{days}:{secrets.token_hex(6)}"
    api("sendInvoice",{
      "chat_id":uid,"title":f"VO1D_VPN — {p['title']}",
      "description":f"Доступ VO1D_VPN на {days} дней",
      "payload":payload,"currency":"XTR",
      "prices":[{"label":p["title"],"amount":p["stars"]}]
    },30)

def gift_star_invoice(uid,target,days):
    p=PLANS[days]
    payload=f"gift:{uid}:{int(target)}:{days}:{secrets.token_hex(5)}"
    api("sendInvoice",{
      "chat_id":uid,
      "title":f"Подарок VO1D — {p['title']}",
      "description":f"Подписка VO1D_VPN для Telegram ID {int(target)}",
      "payload":payload,"currency":"XTR",
      "prices":[{"label":p["title"],"amount":p["stars"]}]
    },30)

def giftcode_star_invoice(uid,days):
    p=PLANS[days]
    payload=f"gcode:{uid}:{days}:{secrets.token_hex(5)}"
    api("sendInvoice",{
      "chat_id":uid,
      "title":f"Подарочный код VO1D — {p['title']}",
      "description":"После оплаты бот выдаст одноразовый подарочный код.",
      "payload":payload,"currency":"XTR",
      "prices":[{"label":p["title"],"amount":p["stars"]}]
    },30)

def gift_with_balance(uid,target,days):
    uid=int(uid);target=int(target);days=int(days);p=PLANS[days]
    with db() as c:
        c.execute("BEGIN IMMEDIATE")
        buyer=c.execute("SELECT balance_cents FROM users WHERE id=?",(uid,)).fetchone()
        recipient=c.execute("SELECT sub_until,banned FROM users WHERE id=?",(target,)).fetchone()
        if not buyer:return None,"buyer_missing"
        if not recipient:return None,"recipient_missing"
        if recipient["banned"]:return None,"recipient_blocked"
        price=int(p["usd"]); bal=int(buyer["balance_cents"])
        if bal<price:return bal,"insufficient"
        end=max(now(),int(recipient["sub_until"]))+days*86400
        new_balance=bal-price
        cur=c.execute("""INSERT INTO payments(user_id,method,plan_days,amount_stars,amount_usd_cents,status,created_at,paid_at,charge_id,reference)
          VALUES(?,?,?,?,?,?,?,?,?,?)""",(uid,"gift_balance",days,0,price,"paid",now(),now(),"",f"target:{target}"))
        pid=cur.lastrowid
        c.execute("UPDATE users SET balance_cents=? WHERE id=?",(new_balance,uid))
        c.execute("UPDATE users SET sub_until=? WHERE id=?",(end,target))
        c.execute("INSERT INTO balance_transactions(user_id,kind,amount_cents,reference,created_at) VALUES(?,?,?,?,?)",
                  (uid,"gift",-price,f"payment:{pid}",now()))
        c.execute("INSERT INTO subscription_events(user_id,days,source,created_at,sub_until) VALUES(?,?,?,?,?)",
                  (target,days,f"gift_from:{uid}",now(),end))
        return {"balance":new_balance,"end":end},"ok"

def giftcode_with_balance(uid,days):
    uid=int(uid);days=int(days);p=PLANS[days]
    with db() as c:
        c.execute("BEGIN IMMEDIATE")
        buyer=c.execute("SELECT balance_cents FROM users WHERE id=?",(uid,)).fetchone()
        if not buyer:return None,"missing"
        price=int(p["usd"]);bal=int(buyer["balance_cents"])
        if bal<price:return bal,"insufficient"
        new_balance=bal-price
        c.execute("UPDATE users SET balance_cents=? WHERE id=?",(new_balance,uid))
        cur=c.execute("""INSERT INTO payments(user_id,method,plan_days,amount_stars,amount_usd_cents,status,created_at,paid_at,charge_id,reference)
          VALUES(?,?,?,?,?,?,?,?,?,?)""",(uid,"giftcode_balance",days,0,price,"paid",now(),now(),"","giftcode"))
        pid=cur.lastrowid
        c.execute("INSERT INTO balance_transactions(user_id,kind,amount_cents,reference,created_at) VALUES(?,?,?,?,?)",
                  (uid,"gift",-price,f"payment:{pid}",now()))
    code=create_gift_code(uid,days)
    return {"balance":new_balance,"code":code},"ok"

def topup_star_invoice(uid,cents):
    cents=int(cents)
    if not valid_topup_cents(cents):return
    stars=topup_stars(cents)
    payload=f"bal:{uid}:{cents}:{stars}:{secrets.token_hex(6)}"
    api("sendInvoice",{
      "chat_id":uid,
      "title":f"VO1D Balance +{money(cents)}",
      "description":"Пополнение внутреннего баланса VO1D для покупки подписок.",
      "payload":payload,
      "currency":"XTR",
      "prices":[{"label":f"Баланс +{money(cents)}","amount":stars}]
    },30)

def manual_topup(uid,cents,method):
    cents=int(cents)
    if not valid_topup_cents(cents):return
    method_name="topup_crypto" if method=="crypto" else "topup_card"
    pid=record_payment(uid,method_name,0,0,cents,"pending","")
    label="криптовалютой" if method=="crypto" else "банковской картой"
    draft=f"VO1D_VPN | Пополнение #{pid}\nХочу пополнить баланс на {money(cents)} {label}.\nTelegram ID: {uid}"
    url=f"https://t.me/{ADMIN_USERNAME}?text="+urllib.parse.quote(draft)
    send(uid,
      f"<b>Пополнение #{pid}</b>\n\n"
      f"Сумма: <b>{money(cents)}</b>\nСпособ: {label}\n\n"
      "После подтверждения администратора сумма появится на балансе.",
      [[button("💬 Открыть @"+ADMIN_USERNAME,url=url)],[button("◀️ Баланс","balance")]])
    send(ADMIN_ID,
      f"<b>💳 Пополнение баланса #{pid}</b>\nUser: <code>{uid}</code>\n"
      f"Сумма: <b>{money(cents)}</b>\nМетод: {label}\n"
      f"Подтвердить: <code>/paid {pid}</code>")

def manual_payment(uid,days,method):
    pid=make_payment(uid,method,days)
    p=PLANS[days]
    label="криптовалютой" if method=="crypto" else "банковской картой"
    draft=f"VO1D_VPN | Заявка #{pid}\nХочу купить {p['title']} ({days} дней) {label}.\nTelegram ID: {uid}\nЦена: {money(p['usd'])}"
    url=f"https://t.me/{ADMIN_USERNAME}?text="+urllib.parse.quote(draft)
    send(uid,
      f"<b>Заявка #{pid} создана</b>\n\n"
      f"Тариф: {p['title']}\nЦена: {money(p['usd'])}\nСпособ: {label}\n\n"
      "Нажми кнопку ниже — сообщение администратору уже подготовлено.",
      [[button("💬 Открыть @"+ADMIN_USERNAME,url=url)],[button("◀️ Меню","menu")]])
    send(ADMIN_ID,
      f"<b>💳 Новая заявка #{pid}</b>\nUser: <code>{uid}</code>\n"
      f"Тариф: {p['title']}\nМетод: {label}\nЦена: {money(p['usd'])}\n"
      f"Подтвердить: <code>/paid {pid}</code>")

def connect(uid):
    r=get_user(uid)
    if r["banned"]:
        return send(uid,"⛔ <b>Доступ заблокирован.</b>\nОбратись в поддержку.",[[button("🛟 Поддержка",url=SUPPORT_URL)]])
    if not active(r):
        return send(uid,"Подписка сейчас не активна.",[[button("💎 Купить подписку","plans")],[button("◀️ Меню","menu")]])
    if not PUBLIC_URL:
        return send(uid,"Подписка активна, но публичный URL бота ещё не указан в Railway Variables: <code>PUBLIC_URL</code>.")
    sub=f"{PUBLIC_URL}/sub/{r['sub_token']}"
    send(uid,
      f"<b>⚡ Подключение VO1D_VPN</b>\n\n"
      f"Твоя персональная ссылка для Happ:\n<code>{esc(sub)}</code>\n\n"
      "Не передавай её другим: ссылка привязана к твоей подписке.",
      [[button("📖 Как добавить в Happ","guide")],[button("◀️ Меню","menu")]])

def guide(uid):
    send(uid,
      "<b>📖 Подключение через Happ</b>\n\n"
      "1. Установи Happ из официального магазина своей платформы.\n"
      "2. В боте нажми <b>⚡ Подключить</b>.\n"
      "3. Скопируй персональную subscription URL.\n"
      "4. В Happ нажми <b>+</b> → добавление подписки.\n"
      "5. Вставь URL и обнови список серверов.\n"
      "6. Выбери доступный узел и подключись.\n\n"
      "Если ссылка не выдаётся — проверь срок подписки.",
      [[button("⚡ Получить ссылку","connect")],[button("◀️ Меню","menu")]])

def admin_panel():
    with db() as c:
        users=c.execute("SELECT COUNT(*) n FROM users").fetchone()["n"]
        act=c.execute("SELECT COUNT(*) n FROM users WHERE sub_until>? AND banned=0",(now(),)).fetchone()["n"]
        bans=c.execute("SELECT COUNT(*) n FROM users WHERE banned=1").fetchone()["n"]
        pend=c.execute("SELECT COUNT(*) n FROM payments WHERE status='pending'").fetchone()["n"]
        stars=c.execute("SELECT COALESCE(SUM(amount_stars),0) n FROM payments WHERE status='paid' AND method IN ('stars','stars_topup')").fetchone()["n"]
        usd=c.execute("SELECT COALESCE(SUM(amount_usd_cents),0) n FROM payments WHERE status='paid' AND method IN ('crypto','card','topup_crypto','topup_card')").fetchone()["n"]
    send(ADMIN_ID,
      f"<b>🛠 VO1D Admin</b>\n\n"
      f"Пользователей: <b>{users}</b>\nАктивных: <b>{act}</b>\nБанов: <b>{bans}</b>\n"
      f"Ожидают оплаты: <b>{pend}</b>\nДоход Stars: <b>{stars} ⭐</b>\n"
      f"Подтверждённый manual: <b>{money(usd)}</b>",
      [[button("👥 Последние пользователи","admin_users")],[button("💳 Заявки","admin_payments")],
       [button("🎟 Промокоды","admin_promos")],[button("◀️ Меню","menu")]])

def admin_users():
    with db() as c: rows=c.execute("SELECT * FROM users ORDER BY joined_at DESC LIMIT 15").fetchall()
    text="<b>👥 Последние пользователи</b>\n\n"
    for r in rows:
        text+=f"<code>{r['id']}</code> @{esc(r['username'] or '—')} | {'ACTIVE' if active(r) else 'OFF'}{' | BAN' if r['banned'] else ''}\n"
    text+="\n<code>/grant ID DAYS</code> · <code>/ban ID</code> · <code>/unban ID</code>"
    send(ADMIN_ID,text)

def admin_payments():
    with db() as c: rows=c.execute("SELECT * FROM payments ORDER BY id DESC LIMIT 15").fetchall()
    text="<b>💳 Последние оплаты</b>\n\n"
    for r in rows:
        text+=f"#{r['id']} · <code>{r['user_id']}</code> · {r['method']} · {r['plan_days']}d · {r['status']}\n"
    text+="\nПодтвердить manual: <code>/paid PAYMENT_ID</code>"
    send(ADMIN_ID,text)

def admin_promos():
    with db() as c:
        rows=c.execute("SELECT * FROM promo_codes ORDER BY created_at DESC LIMIT 30").fetchall()
    text="<b>🎟 Промокоды VO1D</b>\n\n"
    for r in rows:
        reward=(f"+{r['reward_value']} дн." if r["reward_type"]=="days" else f"+{money(r['reward_value'])}")
        limit="∞" if not r["max_uses"] else str(r["max_uses"])
        text+=f"<code>{esc(r['code'])}</code> · {reward} · {r['uses']}/{limit} · {'ON' if r['active'] else 'OFF'}\n"
    text+=("\nСоздать:\n<code>/promo CODE days 7 100</code>\n"
           "<code>/promo CODE balance 5.00 50</code>\n"
           "Последнее число — максимум активаций, 0 = без лимита.\n"
           "Удалить: <code>/delpromo CODE</code>")
    send(ADMIN_ID,text,[[button("◀️ Админ","admin")]])

def handle_command(uid,text):
    parts=text.strip().split(maxsplit=2); cmd=parts[0].split("@")[0].lower()
    if cmd=="/start":
        all_parts=text.strip().split(maxsplit=1)
        if len(all_parts)>1 and all_parts[1].startswith("ref_"):
            try:assign_referrer(uid,int(all_parts[1][4:]))
            except Exception:pass
        r=get_user(uid)
        if r and r["banned"]: return send(uid,"⛔ Доступ к VO1D_VPN заблокирован.",[[button("🛟 Поддержка",url=SUPPORT_URL)]])
        return start_screen(uid,r["first_name"] if r else "")
    if cmd=="/admin" and uid==ADMIN_ID:return admin_panel()
    if cmd=="/stats" and uid==ADMIN_ID:return admin_panel()
    if cmd=="/users" and uid==ADMIN_ID:return admin_users()
    if cmd=="/payments" and uid==ADMIN_ID:return admin_payments()
    if cmd=="/promos" and uid==ADMIN_ID:return admin_promos()
    if uid!=ADMIN_ID:return
    try:
        if cmd=="/promo":
            a=text.strip().split()
            if len(a)<4:return send(uid,"Формат: <code>/promo CODE days 7 100</code> или <code>/promo CODE balance 5.00 50</code>")
            code=normalize_code(a[1]); reward_type=a[2].lower()
            max_uses=int(a[4]) if len(a)>4 else 0
            if reward_type=="days":
                value=int(a[3])
                if value<1 or value>3650:raise ValueError("days out of range")
            elif reward_type=="balance":
                value=parse_topup_amount(a[3])
                if value is None:raise ValueError("bad balance reward")
            else:return send(uid,"Награда должна быть <code>days</code> или <code>balance</code>.")
            with db() as cc:
                cc.execute("""INSERT INTO promo_codes(code,reward_type,reward_value,max_uses,uses,expires_at,active,created_by,created_at)
                  VALUES(?,?,?,?,0,0,1,?,?)
                  ON CONFLICT(code) DO UPDATE SET reward_type=excluded.reward_type,reward_value=excluded.reward_value,
                  max_uses=excluded.max_uses,active=1,created_by=excluded.created_by""",
                  (code,reward_type,value,max_uses,uid,now()))
            return send(uid,f"✅ Промокод <code>{code}</code> сохранён.",[[button("🎟 Список промокодов","admin_promos")]])
        if cmd=="/delpromo":
            code=normalize_code(text.strip().split(maxsplit=1)[1])
            with db() as cc:cc.execute("UPDATE promo_codes SET active=0 WHERE code=?",(code,))
            return send(uid,f"✅ Промокод <code>{code}</code> выключен.")
        if cmd=="/grant":
            _,target,days=text.split(maxsplit=2); end=add_days(int(target),int(days),"admin")
            send(uid,f"✅ <code>{target}</code>: +{days} дней, до {dt(end)}")
            send(int(target),f"✅ Администратор начислил <b>{days} дней</b>.\nПодписка активна до {dt(end)}.",main_kb(int(target)))
        elif cmd=="/ban":
            target=int(parts[1])
            with db() as c:c.execute("UPDATE users SET banned=1 WHERE id=?",(target,))
            send(uid,f"⛔ <code>{target}</code> заблокирован.")
        elif cmd=="/unban":
            target=int(parts[1])
            with db() as c:c.execute("UPDATE users SET banned=0 WHERE id=?",(target,))
            send(uid,f"✅ <code>{target}</code> разблокирован.")
        elif cmd=="/balance":
            _,target,amount=text.split(maxsplit=2); cents=round(float(amount)*100)
            new_balance=change_balance(int(target),cents,"admin",f"admin:{uid}")
            if new_balance is None:return send(uid,"Не удалось изменить баланс.")
            send(uid,f"✅ Баланс <code>{target}</code> изменён на {money(cents)}. Теперь: <b>{money(new_balance)}</b>.")
        elif cmd=="/paid":
            pid=int(parts[1])
            with db() as c:
                p=c.execute("SELECT * FROM payments WHERE id=?",(pid,)).fetchone()
                if not p:return send(uid,"Заявка не найдена.")
                if p["status"]=="paid":return send(uid,"Эта заявка уже подтверждена.")
                c.execute("UPDATE payments SET status='paid',paid_at=? WHERE id=?",(now(),pid))
            if int(p["plan_days"])>0:
                end=add_days(p["user_id"],p["plan_days"],f"manual:{p['method']}")
                notify_referral_reward(p["user_id"])
                send(uid,f"✅ Заявка #{pid} подтверждена. Доступ до {dt(end)}.")
                send(p["user_id"],f"✅ <b>Оплата подтверждена.</b>\nНачислено {p['plan_days']} дней.\nАктивно до {dt(end)}.",main_kb(p["user_id"]))
            else:
                new_balance=change_balance(p["user_id"],p["amount_usd_cents"],"manual_topup",f"payment:{pid}")
                send(uid,f"✅ Пополнение #{pid} подтверждено. Баланс пользователя: <b>{money(new_balance)}</b>.")
                send(p["user_id"],f"✅ <b>Баланс пополнен на {money(p['amount_usd_cents'])}.</b>\nТеперь на балансе: <b>{money(new_balance)}</b>.",main_kb(p["user_id"]))
        elif cmd=="/broadcast":
            msg=text.split(maxsplit=1)[1]
            with db() as c: ids=[r["id"] for r in c.execute("SELECT id FROM users WHERE banned=0").fetchall()]
            ok=0
            for x in ids:
                try: send(x,f"<b>VO1D_VPN</b>\n\n{esc(msg)}"); ok+=1; time.sleep(.04)
                except Exception: pass
            send(uid,f"✅ Отправлено: {ok}/{len(ids)}")
    except Exception as e:
        send(uid,f"Ошибка команды: <code>{esc(e)}</code>")

def handle_callback(q):
    uid=int(q["from"]["id"]); data=q.get("data",""); answer_cb(q["id"])
    r=get_user(uid)
    if not r:return
    if r["banned"] and uid!=ADMIN_ID:return send(uid,"⛔ Доступ заблокирован.")
    if not (data=="topup" or data.startswith("topup:") or data.startswith("topup_pay:")):
        clear_pending(uid)
    if data=="menu":return send(uid,"<b>VO1D_VPN</b>\nВыбери действие:",main_kb(uid))
    if data=="more":return more_menu(uid)
    if data=="balance_history":return balance_history(uid)
    if data=="sub_history":return subscription_history(uid)
    if data=="promo":return promo_prompt(uid)
    if data=="referral":return referral_screen(uid)
    if data=="autorenew":return auto_renew_screen(uid)
    if data=="servers":return servers_screen(uid)
    if data=="diagnostics":return diagnostics(uid)
    if data=="devices":return devices_screen(uid)
    if data=="gifts":return gifts_screen(uid)
    if data=="gift_direct":return gift_plan_menu(uid,"giftplan")
    if data=="gift_code":return gift_plan_menu(uid,"gcodeplan")
    if data=="device_add":
        set_pending(uid,"device_add")
        return send(uid,f"<b>📱 Новое устройство</b>\n\nОтправь название, например <code>iPhone</code> или <code>PC</code>.\nЛимит: {DEVICE_LIMIT}.",[[button("❌ Отмена","devices")]])
    if data.startswith("device_del:"):
        try:
            did=int(data.split(":")[1])
            with db() as cc:cc.execute("DELETE FROM devices WHERE id=? AND user_id=?",(did,uid))
            return devices_screen(uid)
        except:return
    if data=="notifications":
        with db() as cc:cc.execute("UPDATE users SET notifications=CASE notifications WHEN 1 THEN 0 ELSE 1 END WHERE id=?",(uid,))
        return more_menu(uid)
    if data=="reset_access":
        return send(uid,"<b>🔐 Сбросить доступ?</b>\n\nБудет создана новая subscription-ссылка и новый персональный ключ.",[[button("✅ Да, сбросить","reset_access_confirm")],[button("❌ Отмена","more")]])
    if data=="reset_access_confirm":
        return send(uid,reset_access(uid),[[button("⚡ Получить новую ссылку","connect")],[button("◀️ Ещё","more")]])
    if data.startswith("welcome:"):
        try:return welcome_screen(uid,int(data.split(":")[1]))
        except:return
    if data.startswith("autorenew:"):
        val=data.split(":",1)[1]
        if val=="toggle":
            with db() as cc:cc.execute("UPDATE users SET auto_renew=CASE auto_renew WHEN 1 THEN 0 ELSE 1 END WHERE id=?",(uid,))
        else:
            try:
                days=int(val)
                if days in PLANS:
                    with db() as cc:cc.execute("UPDATE users SET auto_renew_days=? WHERE id=?",(days,uid))
            except:pass
        return auto_renew_screen(uid)
    if data.startswith("server:"):
        try:
            idx=int(data.split(":")[1])
            if 0<=idx<len(VPN_NODES):
                with db() as cc:cc.execute("UPDATE users SET preferred_node=? WHERE id=?",(idx,uid))
            return servers_screen(uid)
        except:return
    if data.startswith("giftplan:"):
        try:
            days=int(data.split(":")[1])
            if days in PLANS:return direct_gift_recipient_prompt(uid,days)
        except:return
    if data.startswith("gcodeplan:"):
        try:
            days=int(data.split(":")[1])
            if days in PLANS:return gift_code_payment(uid,days)
        except:return
    if data.startswith("giftpay:"):
        try:
            _,target_s,days_s,method=data.split(":")
            target=int(target_s);days=int(days_s)
            if days not in PLANS:return
            if method=="balance":
                result,status=gift_with_balance(uid,target,days)
                if status=="insufficient":
                    return send(uid,f"Недостаточно средств. Баланс: <b>{money(int(result or 0))}</b>.",[[button("➕ Пополнить","topup")],[button("◀️ Подарки","gifts")]])
                if status!="ok":return send(uid,"Не удалось оформить подарок.")
                try:send(target,f"🎁 <b>Тебе подарили {days} дней VO1D_VPN.</b>\nДоступ до {dt(result['end'])}.",main_kb(target))
                except Exception:pass
                return send(uid,f"✅ Подарок отправлен. Остаток: <b>{money(result['balance'])}</b>.",[[button("◀️ Подарки","gifts")]])
            if method=="stars":return gift_star_invoice(uid,target,days)
        except Exception as e:return send(uid,f"Ошибка подарка: <code>{esc(e)}</code>")
    if data.startswith("gcodepay:"):
        try:
            _,days_s,method=data.split(":");days=int(days_s)
            if days not in PLANS:return
            if method=="balance":
                result,status=giftcode_with_balance(uid,days)
                if status=="insufficient":return send(uid,f"Недостаточно средств. Баланс: <b>{money(int(result or 0))}</b>.",[[button("➕ Пополнить","topup")]])
                if status!="ok":return send(uid,"Не удалось создать подарочный код.")
                return send(uid,f"🎫 <b>Подарочный код готов</b>\n\n<code>{result['code']}</code>\nСрок: <b>{days} дней</b>\nОдноразовый.",[[button("◀️ Подарки","gifts")]])
            if method=="stars":return giftcode_star_invoice(uid,days)
        except Exception as e:return send(uid,f"Ошибка подарочного кода: <code>{esc(e)}</code>")
    if data=="admin_promos" and uid==ADMIN_ID:return admin_promos()
    if data=="check_sub":
        if not is_member(uid):
            kb=[]
            if CHANNEL_URL:kb.append([button("📢 Подписаться",url=CHANNEL_URL)])
            kb.append([button("🔄 Проверить","check_sub")])
            return send(uid,"Подписка пока не обнаружена. Подпишись на канал и нажми проверку ещё раз.",kb)
        r=get_user(uid)
        if r and not r["welcome_done"]:return welcome_screen(uid,1)
        if not r["trial_claimed"]:
            return send(uid,"✅ Подписка подтверждена.\n\nТебе доступна пробная подписка на <b>24 часа</b>.",
              [[button("🎁 Активировать 1 день","activate_trial")]])
        return send(uid,"✅ Подписка подтверждена.",main_kb(uid))
    if data=="activate_trial":
        if CHANNEL_ID and not is_member(uid):return send(uid,"Сначала подпишись на канал.",[[button("📢 Канал",url=CHANNEL_URL)]])
        end,status=claim_trial(uid)
        if status=="used":return send(uid,"Пробный период уже был активирован.",main_kb(uid))
        if status!="ok":return send(uid,"Не удалось активировать пробный период.")
        return send(uid,f"🎉 <b>Пробная подписка активирована.</b>\nДоступ до {dt(end)}.",main_kb(uid))
    if data=="profile":return profile(uid)
    if data=="balance":return balance_screen(uid)
    if data=="topup":return topup_menu(uid)
    if data=="plans":return plans(uid)
    if data=="connect":return connect(uid)
    if data=="guide":return guide(uid)
    if data=="admin" and uid==ADMIN_ID:return admin_panel()
    if data=="admin_users" and uid==ADMIN_ID:return admin_users()
    if data=="admin_payments" and uid==ADMIN_ID:return admin_payments()
    if data.startswith("topup:"):
        try:
            cents=int(data.split(":")[1])
            if valid_topup_cents(cents):return topup_methods(uid,cents)
        except:return
    if data.startswith("topup_pay:"):
        try:
            _,amount,method=data.split(":"); cents=int(amount)
            if not valid_topup_cents(cents):return
            if method=="stars":return topup_star_invoice(uid,cents)
            if method in ("crypto","card"):return manual_topup(uid,cents,method)
        except Exception as e:return send(uid,f"Ошибка пополнения: <code>{esc(e)}</code>")
    if data.startswith("plan:"):
        try:return payment_methods(uid,int(data.split(":")[1]))
        except:return
    if data.startswith("pay:"):
        try:
            _,d,method=data.split(":"); days=int(d)
            if days not in PLANS:return
            if method=="balance":
                result,status=buy_with_balance(uid,days)
                if status=="insufficient":
                    price=PLANS[days]["usd"]
                    missing=max(0,price-int(result or 0))
                    return send(uid,
                      f"Недостаточно средств.\n\nБаланс: <b>{money(int(result or 0))}</b>\n"
                      f"Цена: <b>{money(price)}</b>\nНе хватает: <b>{money(missing)}</b>",
                      [[button("➕ Пополнить баланс","topup")],[button("◀️ Тарифы","plans")]])
                if status!="ok":return send(uid,"Не удалось оплатить с баланса.")
                notify_referral_reward(uid)
                return send(uid,
                  f"✅ <b>Подписка оплачена с баланса.</b>\n\n"
                  f"Списано: <b>{money(PLANS[days]['usd'])}</b>\n"
                  f"Остаток: <b>{money(result['balance'])}</b>\n"
                  f"Доступ до: <b>{dt(result['end'])}</b>",
                  main_kb(uid))
            if method=="stars":return star_invoice(uid,days)
            if method in ("crypto","card"):return manual_payment(uid,days,method)
        except Exception as e:return send(uid,f"Ошибка оплаты: <code>{esc(e)}</code>")

def successful_payment(msg):
    sp=msg.get("successful_payment")
    if not sp:return
    uid=int(msg["from"]["id"]); payload=sp.get("invoice_payload","")
    charge=sp.get("telegram_payment_charge_id","")
    with db() as c:
        dup=c.execute("SELECT id FROM payments WHERE charge_id=?",(charge,)).fetchone()
    if dup:return
    try:
        parts=payload.split(":")
        kind=parts[0]
        puid=int(parts[1])
        if puid!=uid:return

        if kind=="sub":
            days=int(parts[2])
            if days not in PLANS:return
            expected=PLANS[days]["stars"]
            if int(sp.get("total_amount",0))!=expected:return
            make_payment(uid,"stars",days,"paid",charge)
            end=add_days(uid,days,"stars")
            notify_referral_reward(uid)
            send(uid,f"✅ <b>Оплата Stars получена.</b>\nНачислено {days} дней.\nПодписка до {dt(end)}.",main_kb(uid))
            send(ADMIN_ID,f"⭐ Stars payment\nUser: <code>{uid}</code>\n{days} дней · {expected} ⭐\nCharge: <code>{esc(charge)}</code>")
            return

        if kind=="bal":
            cents=int(parts[2]); expected_stars=int(parts[3])
            if not valid_topup_cents(cents) or topup_stars(cents)!=expected_stars:return
            if int(sp.get("total_amount",0))!=expected_stars:return
            pid=record_payment(uid,"stars_topup",0,expected_stars,cents,"paid",charge)
            new_balance=change_balance(uid,cents,"stars_topup",f"payment:{pid}")
            send(uid,
              f"✅ <b>Баланс пополнен на {money(cents)}.</b>\n"
              f"Теперь на балансе: <b>{money(new_balance)}</b>.",
              main_kb(uid))
            send(ADMIN_ID,
              f"⭐ Balance top-up\nUser: <code>{uid}</code>\n"
              f"+{money(cents)} · {expected_stars} ⭐\nCharge: <code>{esc(charge)}</code>")
            return

        if kind=="gift":
            target=int(parts[2]); days=int(parts[3])
            if days not in PLANS or not get_user(target):return
            expected=PLANS[days]["stars"]
            if int(sp.get("total_amount",0))!=expected:return
            record_payment(uid,"gift_stars",days,expected,PLANS[days]["usd"],"paid",charge,f"target:{target}")
            end=add_days(target,days,f"gift_stars:{uid}")
            send(uid,f"✅ <b>Подарок отправлен.</b>\nПолучатель: <code>{target}</code>\nСрок: {days} дней.",main_kb(uid))
            try:send(target,f"🎁 <b>Тебе подарили {days} дней VO1D_VPN.</b>\nДоступ до {dt(end)}.",main_kb(target))
            except Exception:pass
            send(ADMIN_ID,f"⭐ Gift payment\nFrom: <code>{uid}</code>\nTo: <code>{target}</code>\n{days} дней · {expected} ⭐")
            return

        if kind=="gcode":
            days=int(parts[2])
            if days not in PLANS:return
            expected=PLANS[days]["stars"]
            if int(sp.get("total_amount",0))!=expected:return
            record_payment(uid,"giftcode_stars",days,expected,PLANS[days]["usd"],"paid",charge,"giftcode")
            code=create_gift_code(uid,days)
            send(uid,f"🎫 <b>Подарочный код готов</b>\n\n<code>{code}</code>\nСрок: <b>{days} дней</b>\nОдноразовый.",[[button("◀️ Подарки","gifts")]])
            return
    except Exception as e:
        print("successful payment parse error",repr(e),flush=True)

def handle_update(u):
    if "pre_checkout_query" in u:
        q=u["pre_checkout_query"]
        ok=False; err="Платёж не прошёл проверку. Открой счёт заново."
        try:
            payload=q.get("invoice_payload","")
            parts=payload.split(":")
            uid=int(q["from"]["id"])
            if q.get("currency")=="XTR" and len(parts)>=4 and int(parts[1])==uid:
                if parts[0]=="sub":
                    days=int(parts[2])
                    ok=days in PLANS and int(q.get("total_amount",0))==PLANS[days]["stars"]
                elif parts[0]=="bal" and len(parts)>=5:
                    cents=int(parts[2]); stars=int(parts[3])
                    ok=valid_topup_cents(cents) and topup_stars(cents)==stars and int(q.get("total_amount",0))==stars
                elif parts[0]=="gift" and len(parts)>=5:
                    target=int(parts[2]); days=int(parts[3])
                    ok=days in PLANS and bool(get_user(target)) and int(q.get("total_amount",0))==PLANS[days]["stars"]
                elif parts[0]=="gcode" and len(parts)>=4:
                    days=int(parts[2])
                    ok=days in PLANS and int(q.get("total_amount",0))==PLANS[days]["stars"]
            api("answerPreCheckoutQuery",{"pre_checkout_query_id":q["id"],"ok":bool(ok),**({} if ok else {"error_message":err})},15)
        except Exception:
            try: api("answerPreCheckoutQuery",{"pre_checkout_query_id":q["id"],"ok":False,"error_message":err},15)
            except Exception: pass
        return
    msg=u.get("message")
    if msg:
        usr=msg.get("from")
        if not usr:return
        row=upsert_user(usr); uid=int(usr["id"])
        if msg.get("successful_payment"):return successful_payment(msg)
        text=msg.get("text","")
        if text.startswith("/"):return handle_command(uid,text)
        if row["banned"]:return
        pending=get_pending(uid)
        if pending and pending["action"]=="topup_amount":
            cents=parse_topup_amount(text)
            if cents is None:
                return send(uid,
                  f"Не понял сумму. Отправь число от <b>{money(TOPUP_MIN_CENTS)}</b> до <b>{money(TOPUP_MAX_CENTS)}</b>.\n"
                  "Например: <code>7.50</code>",
                  [[button("❌ Отмена","balance")]])
            return topup_methods(uid,cents)
        if pending and pending["action"]=="redeem_code":
            ok,msg=redeem_code(uid,text)
            clear_pending(uid)
            return send(uid,msg,[[button("◀️ Ещё","more")]])
        if pending and pending["action"]=="device_add":
            ok,msg=add_device(uid,text)
            clear_pending(uid)
            send(uid,("✅ " if ok else "⚠️ ")+msg)
            return devices_screen(uid)
        if pending and pending["action"]=="gift_recipient":
            try:
                data=json.loads(pending["data"] or "{}");days=int(data["days"]);target=int(str(text).strip())
            except Exception:
                return send(uid,"Отправь числовой Telegram ID получателя.",[[button("❌ Отмена","gifts")]])
            clear_pending(uid)
            return direct_gift_payment(uid,target,days)
        return send(uid,"<b>VO1D_VPN</b>\nИспользуй меню ниже.",main_kb(uid))
    q=u.get("callback_query")
    if q:
        upsert_user(q["from"]); return handle_callback(q)

class Web(BaseHTTPRequestHandler):
    def log_message(self,*args): pass

    def common_headers(self,cache="no-store"):
        self.send_header("Cache-Control",cache)
        self.send_header("X-Content-Type-Options","nosniff")
        self.send_header("Referrer-Policy","no-referrer")
        self.send_header("X-Frame-Options","SAMEORIGIN")

    def reply_bytes(self,code,data,ctype="application/octet-stream",cache="no-store",extra=None):
        self.send_response(code)
        self.send_header("Content-Type",ctype)
        self.send_header("Content-Length",str(len(data)))
        self.common_headers(cache)
        if extra:
            for k,v in extra.items(): self.send_header(k,v)
        self.end_headers()
        self.wfile.write(data)

    def reply(self,code,body,ctype="text/plain; charset=utf-8",extra=None):
        self.reply_bytes(code,body.encode(),ctype,"no-store",extra)

    def reply_json(self,code,obj):
        self.reply(code,json.dumps(obj,ensure_ascii=False,separators=(",",":")),"application/json; charset=utf-8")

    def read_json(self):
        try:
            size=min(int(self.headers.get("Content-Length","0") or 0),65536)
            raw=self.rfile.read(size) if size else b"{}"
            return json.loads(raw.decode() or "{}")
        except Exception:
            return {}

    def auth_user(self):
        try:
            tg_user=validate_webapp_init_data(self.headers.get("X-Telegram-Init-Data",""))
            row=upsert_user(tg_user)
            return tg_user,row
        except Exception as e:
            self.reply_json(401,{"ok":False,"error":"telegram_auth_failed","message":"Открой Mini App заново из Telegram."})
            return None

    def request_ip(self):
        candidates=[]
        for key in ("CF-Connecting-IP","X-Real-IP","X-Forwarded-For"):
            raw=self.headers.get(key,"")
            if raw:
                candidates.extend(x.strip() for x in raw.split(",") if x.strip())
        if self.client_address and self.client_address[0]:
            candidates.append(self.client_address[0])
        valid=[]
        for value in candidates:
            candidate=value.strip().strip("[]")
            if candidate.count(":")==1 and "." in candidate:
                host,port=candidate.rsplit(":",1)
                if port.isdigit(): candidate=host
            try:
                ip=ipaddress.ip_address(candidate)
                text=str(ip)
                valid.append(text)
                if ip.is_global:
                    return text
            except Exception:
                continue
        return valid[0] if valid else ""


    def serve_app_asset(self,path):
        mapping={
          "/app":"index.html",
          "/app/":"index.html",
          "/app/index.html":"index.html",
          "/app/style.css":"style.css",
          "/app/app.js":"app.js",
          "/app/audio/leaveamsg-slowed.mp3":"audio/leaveamsg-slowed.mp3",
        }
        name=mapping.get(path)
        if not name:return False
        if name=="audio/leaveamsg-slowed.mp3":
            if os.path.isfile(BUNDLED_AUDIO_PATH):
                full=BUNDLED_AUDIO_PATH
            elif VOLUME_AUDIO_PATH and os.path.isfile(VOLUME_AUDIO_PATH):
                full=VOLUME_AUDIO_PATH
            else:
                full=BUNDLED_AUDIO_PATH
        else:
            full=os.path.join(WEBAPP_DIR,name)
        try:
            with open(full,"rb") as f:data=f.read()
            ctype=mimetypes.guess_type(full)[0] or "application/octet-stream"
            if ctype.startswith("text/") or ctype in ("application/javascript","application/json"):
                ctype+="; charset=utf-8"
            cache="no-cache" if name=="index.html" else "public, max-age=300"
            self.reply_bytes(200,data,ctype,cache)
        except FileNotFoundError:
            self.reply(404,"Mini App asset not found")
        return True

    def do_GET(self):
        parsed=urllib.parse.urlparse(self.path)
        path=parsed.path

        if path=="/health":
            return self.reply_json(200,{"ok":True,"service":"VO1D_VPNbot","mini_app":bool(MINI_APP_URL),"db":DB_PATH})

        if path=="/api/ping":
            return self.reply_json(200,{"ok":True,"time":now(),"service":"VO1D_VPN"})

        if path=="/api/me":
            auth=self.auth_user()
            if not auth:return
            tg_user,row=auth
            return self.reply_json(200,webapp_user_payload(tg_user,row))

        if path=="/api/privacy-test":
            auth=self.auth_user()
            if not auth:return
            tg_user,row=auth
            observed=self.request_ip()
            route_match=bool(observed and observed in VO1D_NODE_IPS)
            if route_match:
                score=98.70
                level="VO1D PROTECTED"
            elif observed:
                score=41.80
                level="ROUTE NOT VERIFIED"
            else:
                score=0.0
                level="IP UNAVAILABLE"
            return self.reply_json(200,{
              "ok":True,
              "ip":observed,
              "vo1d_route":route_match,
              "score":score,
              "level":level,
              "measurement":"route_indicator",
              "note":"Score confirms whether this request is seen from a configured VO1D node; it is not a complete anonymity audit."
            })

        if self.serve_app_asset(path):
            return

        if path.startswith("/sub/"):
            token=urllib.parse.unquote(path[5:])
            with db() as c:r=c.execute("SELECT * FROM users WHERE sub_token=?",(token,)).fetchone()
            if not r:return self.reply(404,"subscription not found")
            if r["banned"]:return self.reply(403,"subscription blocked")
            if r["sub_until"]<=now():return self.reply(403,"subscription expired")
            if not VPN_NODES:return self.reply(503,"VPN_NODES is not configured")
            body=[]
            if SITE_URL:body.append("#profile-web-page-url: "+SITE_URL)
            body.append("#announce: VO1D_VPN active until "+dt(r["sub_until"]))
            body.extend(VPN_NODES)
            return self.reply(200,"\n".join(body)+"\n","text/plain; charset=utf-8",
              {"Content-Disposition":'inline; filename="vo1d-sub.txt"'})

        return self.reply(200,"VO1D_VPNbot is online\n")

    def do_POST(self):
        parsed=urllib.parse.urlparse(self.path)
        path=parsed.path

        if path not in ("/api/trial","/api/invoice"):
            return self.reply_json(404,{"ok":False,"error":"not_found"})

        auth=self.auth_user()
        if not auth:return
        tg_user,row=auth
        uid=int(row["id"])

        if row["banned"]:
            return self.reply_json(403,{"ok":False,"error":"blocked","message":"Доступ заблокирован. Обратись в поддержку."})

        if path=="/api/trial":
            if CHANNEL_ID and not is_member(uid):
                return self.reply_json(403,{
                  "ok":False,"code":"channel_required",
                  "message":"Сначала подпишись на канал.",
                  "channel_url":CHANNEL_URL,
                })
            with db() as c:
                rr=c.execute("SELECT trial_claimed,sub_until FROM users WHERE id=?",(uid,)).fetchone()
                if not rr:
                    return self.reply_json(404,{"ok":False,"error":"user_not_found"})
                if rr["trial_claimed"]:
                    return self.reply_json(409,{"ok":False,"error":"trial_used","message":"Пробный период уже использован."})
                end=max(now(),int(rr["sub_until"]))+TRIAL_HOURS*3600
                c.execute("UPDATE users SET trial_claimed=1,sub_until=? WHERE id=?",(end,uid))
            return self.reply_json(200,webapp_user_payload(tg_user,get_user(uid)))

        if path=="/api/invoice":
            body=self.read_json()
            try: days=int(body.get("days",0))
            except Exception: days=0
            if days not in PLANS:
                return self.reply_json(400,{"ok":False,"error":"bad_plan","message":"Тариф не найден."})
            try:
                invoice_url=create_star_invoice_link(uid,days)
                return self.reply_json(200,{"ok":True,"invoice_url":invoice_url})
            except Exception as e:
                print("invoice link error",repr(e),flush=True)
                return self.reply_json(502,{"ok":False,"error":"invoice_failed","message":"Не удалось создать счёт Telegram Stars."})

def web_thread():
    ThreadingHTTPServer(("0.0.0.0",PORT),Web).serve_forever()

def run():
    if not TOKEN: raise SystemExit("Set BOT_TOKEN in Railway Variables")
    threading.Thread(target=web_thread,daemon=True).start()
    if MINI_APP_URL:
        try:
            api("setChatMenuButton",{
              "menu_button":{
                "type":"web_app",
                "text":"Открыть VO1D",
                "web_app":{"url":MINI_APP_URL}
              }
            },20)
            print("VO1D Mini App menu:",MINI_APP_URL,flush=True)
        except Exception as e:
            print("mini app menu error",repr(e),flush=True)
    print("VO1D_VPNbot started; db:",DB_PATH,"web port:",PORT,flush=True)
    offset=0
    while True:
        try:
            updates=api("getUpdates",{"offset":offset,"timeout":50,"allowed_updates":["message","callback_query","pre_checkout_query"]},65)
            for u in updates:
                offset=max(offset,int(u["update_id"])+1)
                try:handle_update(u)
                except Exception as e:print("update error",repr(e),flush=True)
        except Exception as e:
            print("poll error",repr(e),flush=True);time.sleep(3)

if __name__=="__main__":run()
