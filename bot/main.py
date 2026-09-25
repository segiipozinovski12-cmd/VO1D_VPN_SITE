import os, json, time, html, sqlite3, secrets, threading, urllib.request, urllib.parse, hashlib, hmac, mimetypes
from datetime import datetime, timezone
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

mount=os.getenv("RAILWAY_VOLUME_MOUNT_PATH","").strip()
DB_PATH=os.getenv("DB_PATH",(mount.rstrip("/")+"/vo1d.db") if mount else "vo1d.db")
os.makedirs(os.path.dirname(DB_PATH) or ".",exist_ok=True)
BASE_DIR=os.path.dirname(os.path.abspath(__file__))
WEBAPP_DIR=os.path.join(BASE_DIR,"webapp")

PLANS={
  30: {"title":"1 месяц","usd":399,"stars":250},
  90: {"title":"3 месяца","usd":999,"stars":650},
  180:{"title":"6 месяцев","usd":1699,"stars":1100},
  365:{"title":"12 месяцев","usd":2799,"stars":1800},
}

def now(): return int(time.time())
def dt(ts):
    return datetime.fromtimestamp(ts,timezone.utc).strftime("%d.%m.%Y %H:%M UTC") if ts else "—"
def money(c): return "$"+f"{c/100:.2f}"
def esc(s): return html.escape(str(s or ""))

def db():
    c=sqlite3.connect(DB_PATH,timeout=30)
    c.row_factory=sqlite3.Row
    return c

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
        """)
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
            c.execute("INSERT INTO users(id,username,first_name,joined_at,last_seen,sub_token) VALUES(?,?,?,?,?,?)",
                      (uid,username,first,now(),now(),secrets.token_urlsafe(24)))
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

def add_days(uid,days):
    with db() as c:
        r=c.execute("SELECT sub_until FROM users WHERE id=?",(uid,)).fetchone()
        if not r:return 0
        base=max(now(),int(r["sub_until"]))
        end=base+int(days)*86400
        c.execute("UPDATE users SET sub_until=? WHERE id=?",(end,uid))
        return end

def main_kb(uid):
    rows=[]
    if MINI_APP_URL:
        rows.append([button("⚫ Открыть VO1D Mini App",web_app=MINI_APP_URL)])
    rows += [
      [button("👤 Профиль","profile"),button("💎 Подписка","plans")],
      [button("⚡ Подключить","connect"),button("💰 Купить время","plans")],
      [button("📖 Инструкция","guide"),button("🛟 Поддержка",url=SUPPORT_URL)],
    ]
    if uid==ADMIN_ID: rows.append([button("🛠 Админ-панель","admin")])
    return rows

def start_screen(uid,first=""):
    if CHANNEL_ID:
        rows=[]
        if CHANNEL_URL: rows.append([button("📢 Подписаться на канал",url=CHANNEL_URL)])
        rows.append([button("✅ Я подписался","check_sub")])
        text=(f"<b>VO1D_VPN</b>\n\nДобро пожаловать, {esc(first)}.\n"
              "Чтобы получить доступ к сервису и бонусной пробной подписке, подпишись на канал.")
        send(uid,text,rows)
    else:
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
      [[button("⚡ Подключить","connect")],[button("💎 Продлить","plans")],[button("◀️ Меню","menu")]])

def plans(uid):
    kb=[]
    for days,p in PLANS.items():
        kb.append([button(f"{p['title']} · {money(p['usd'])} · {p['stars']} ⭐",f"plan:{days}")])
    kb.append([button("◀️ Меню","menu")])
    send(uid,"<b>💎 Подписка VO1D_VPN</b>\n\nВыбери срок. После этого выберешь способ оплаты.",kb)

def payment_methods(uid,days):
    p=PLANS.get(days)
    if not p:return
    send(uid,
      f"<b>{p['title']}</b>\nЦена: <b>{money(p['usd'])}</b> или <b>{p['stars']} ⭐</b>\n\n"
      "Выбери способ оплаты:",
      [[button("⭐ Telegram Stars",f"pay:{days}:stars")],
       [button("₿ Криптовалюта",f"pay:{days}:crypto"),button("💳 Банковская карта",f"pay:{days}:card")],
       [button("◀️ Назад","plans")]])

def make_payment(uid,method,days,status="pending",charge=""):
    p=PLANS[days]
    with db() as c:
        cur=c.execute("""INSERT INTO payments(user_id,method,plan_days,amount_stars,amount_usd_cents,status,created_at,paid_at,charge_id)
          VALUES(?,?,?,?,?,?,?,?,?)""",(uid,method,days,p["stars"] if method=="stars" else 0,p["usd"],status,now(),now() if status=="paid" else 0,charge))
        return cur.lastrowid

def star_invoice(uid,days):
    p=PLANS[days]
    payload=f"sub:{uid}:{days}:{secrets.token_hex(6)}"
    api("sendInvoice",{
      "chat_id":uid,"title":f"VO1D_VPN — {p['title']}",
      "description":f"Доступ VO1D_VPN на {days} дней",
      "payload":payload,"currency":"XTR",
      "prices":[{"label":p["title"],"amount":p["stars"]}]
    },30)

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
        stars=c.execute("SELECT COALESCE(SUM(amount_stars),0) n FROM payments WHERE status='paid' AND method='stars'").fetchone()["n"]
        usd=c.execute("SELECT COALESCE(SUM(amount_usd_cents),0) n FROM payments WHERE status='paid' AND method!='stars'").fetchone()["n"]
    send(ADMIN_ID,
      f"<b>🛠 VO1D Admin</b>\n\n"
      f"Пользователей: <b>{users}</b>\nАктивных: <b>{act}</b>\nБанов: <b>{bans}</b>\n"
      f"Ожидают оплаты: <b>{pend}</b>\nДоход Stars: <b>{stars} ⭐</b>\n"
      f"Подтверждённый manual: <b>{money(usd)}</b>",
      [[button("👥 Последние пользователи","admin_users")],[button("💳 Заявки","admin_payments")],[button("◀️ Меню","menu")]])

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

def handle_command(uid,text):
    parts=text.strip().split(maxsplit=2); cmd=parts[0].split("@")[0].lower()
    if cmd=="/start":
        r=get_user(uid)
        if r and r["banned"]: return send(uid,"⛔ Доступ к VO1D_VPN заблокирован.",[[button("🛟 Поддержка",url=SUPPORT_URL)]])
        return start_screen(uid,r["first_name"] if r else "")
    if cmd=="/admin" and uid==ADMIN_ID:return admin_panel()
    if cmd=="/stats" and uid==ADMIN_ID:return admin_panel()
    if cmd=="/users" and uid==ADMIN_ID:return admin_users()
    if cmd=="/payments" and uid==ADMIN_ID:return admin_payments()
    if uid!=ADMIN_ID:return
    try:
        if cmd=="/grant":
            _,target,days=text.split(maxsplit=2); end=add_days(int(target),int(days))
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
            with db() as c:c.execute("UPDATE users SET balance_cents=balance_cents+? WHERE id=?",(cents,int(target)))
            send(uid,f"✅ Баланс <code>{target}</code> изменён на {money(cents)}.")
        elif cmd=="/paid":
            pid=int(parts[1])
            with db() as c:
                p=c.execute("SELECT * FROM payments WHERE id=?",(pid,)).fetchone()
                if not p:return send(uid,"Заявка не найдена.")
                if p["status"]=="paid":return send(uid,"Эта заявка уже подтверждена.")
                c.execute("UPDATE payments SET status='paid',paid_at=? WHERE id=?",(now(),pid))
            end=add_days(p["user_id"],p["plan_days"])
            send(uid,f"✅ Заявка #{pid} подтверждена. Доступ до {dt(end)}.")
            send(p["user_id"],f"✅ <b>Оплата подтверждена.</b>\nНачислено {p['plan_days']} дней.\nАктивно до {dt(end)}.",main_kb(p["user_id"]))
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
    if data=="menu":return send(uid,"<b>VO1D_VPN</b>\nВыбери действие:",main_kb(uid))
    if data=="check_sub":
        if not is_member(uid):
            kb=[]
            if CHANNEL_URL:kb.append([button("📢 Подписаться",url=CHANNEL_URL)])
            kb.append([button("🔄 Проверить","check_sub")])
            return send(uid,"Подписка пока не обнаружена. Подпишись на канал и нажми проверку ещё раз.",kb)
        if not r["trial_claimed"]:
            return send(uid,"✅ Подписка подтверждена.\n\nТебе доступна пробная подписка на <b>24 часа</b>.",
              [[button("🎁 Активировать 1 день","activate_trial")]])
        return send(uid,"✅ Подписка подтверждена.",main_kb(uid))
    if data=="activate_trial":
        with db() as c:
            rr=c.execute("SELECT trial_claimed FROM users WHERE id=?",(uid,)).fetchone()
            if rr["trial_claimed"]:return send(uid,"Пробный период уже был активирован.",main_kb(uid))
            end=max(now(),get_user(uid)["sub_until"])+TRIAL_HOURS*3600
            c.execute("UPDATE users SET trial_claimed=1,sub_until=? WHERE id=?",(end,uid))
        return send(uid,f"🎉 <b>Пробная подписка активирована.</b>\nДоступ до {dt(end)}.",main_kb(uid))
    if data=="profile":return profile(uid)
    if data=="plans":return plans(uid)
    if data=="connect":return connect(uid)
    if data=="guide":return guide(uid)
    if data=="admin" and uid==ADMIN_ID:return admin_panel()
    if data=="admin_users" and uid==ADMIN_ID:return admin_users()
    if data=="admin_payments" and uid==ADMIN_ID:return admin_payments()
    if data.startswith("plan:"):
        try:return payment_methods(uid,int(data.split(":")[1]))
        except:return
    if data.startswith("pay:"):
        try:
            _,d,method=data.split(":"); days=int(d)
            if days not in PLANS:return
            if method=="stars":return star_invoice(uid,days)
            if method in ("crypto","card"):return manual_payment(uid,days,method)
        except Exception as e:return send(uid,f"Ошибка оплаты: <code>{esc(e)}</code>")

def successful_payment(msg):
    sp=msg.get("successful_payment")
    if not sp:return
    uid=int(msg["from"]["id"]); payload=sp.get("invoice_payload","")
    try:
        kind,puid,pdays,_=payload.split(":",3)
        if kind!="sub" or int(puid)!=uid:return
        days=int(pdays)
        if days not in PLANS:return
    except:return
    charge=sp.get("telegram_payment_charge_id","")
    with db() as c:
        dup=c.execute("SELECT id FROM payments WHERE charge_id=?",(charge,)).fetchone()
    if dup:return
    make_payment(uid,"stars",days,"paid",charge)
    end=add_days(uid,days)
    send(uid,f"✅ <b>Оплата Stars получена.</b>\nНачислено {days} дней.\nПодписка до {dt(end)}.",main_kb(uid))
    send(ADMIN_ID,f"⭐ Stars payment\nUser: <code>{uid}</code>\n{days} дней · {PLANS[days]['stars']} ⭐\nCharge: <code>{esc(charge)}</code>")

def handle_update(u):
    if "pre_checkout_query" in u:
        q=u["pre_checkout_query"]
        try: api("answerPreCheckoutQuery",{"pre_checkout_query_id":q["id"],"ok":True},15)
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

    def serve_app_asset(self,path):
        mapping={
          "/app":"index.html",
          "/app/":"index.html",
          "/app/index.html":"index.html",
          "/app/style.css":"style.css",
          "/app/app.js":"app.js",
        }
        name=mapping.get(path)
        if not name:return False
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
