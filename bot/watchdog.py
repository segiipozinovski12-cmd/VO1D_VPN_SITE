#!/usr/bin/env python3
import os, json, time, socket, tempfile, urllib.request, urllib.parse, html

BOT_TOKEN=os.getenv("ALERT_BOT_TOKEN",os.getenv("BOT_TOKEN","")).strip()
CHAT_ID=os.getenv("ALERT_CHAT_ID",os.getenv("ADMIN_ID","")).strip()
INTERVAL=max(15,int(os.getenv("WATCH_INTERVAL","60")))
FAILURE_THRESHOLD=max(1,int(os.getenv("WATCH_FAILURE_THRESHOLD","3")))
RECOVERY_THRESHOLD=max(1,int(os.getenv("WATCH_RECOVERY_THRESHOLD","1")))
TIMEOUT=max(2,float(os.getenv("WATCH_TIMEOUT","8")))
STARTUP_ALERT=os.getenv("WATCH_STARTUP_ALERT","1").strip().lower() in ("1","true","yes","on")
PROJECT_URL=os.getenv("WATCH_PROJECT_URL",os.getenv("PUBLIC_URL","")).strip().rstrip("/")
RAW_TARGETS=os.getenv("WATCH_TARGETS","").replace("\\n","\n")
VPN_NODES=[x.strip() for x in os.getenv("VPN_NODES","").replace("\\n","\n").splitlines() if x.strip()]
mount=os.getenv("RAILWAY_VOLUME_MOUNT_PATH","").strip()
STATE_PATH=os.getenv("WATCH_STATE_PATH",(mount.rstrip("/")+"/vo1d-watchdog.json") if mount else "vo1d-watchdog.json")

def esc(value):
    return html.escape(str(value or ""))

def node_label(uri,index):
    try:
        p=urllib.parse.urlsplit(uri)
        if p.fragment:return urllib.parse.unquote(p.fragment)[:80]
        return p.hostname or f"VPN-{index+1}"
    except Exception:
        return f"VPN-{index+1}"

def parse_targets():
    targets=[]
    if PROJECT_URL:
        url=PROJECT_URL if PROJECT_URL.endswith("/health") else PROJECT_URL+"/health"
        targets.append({"kind":"health","name":"VO1D PROJECT","url":url})
    for raw in RAW_TARGETS.splitlines():
        line=raw.strip()
        if not line or line.startswith("#"):continue
        parts=[x.strip() for x in line.split("|")]
        kind=parts[0].lower() if parts else ""
        if kind in ("health","http") and len(parts)>=3 and parts[1] and parts[2]:
            targets.append({"kind":kind,"name":parts[1][:80],"url":parts[2]})
        elif kind=="tcp" and len(parts)>=4 and parts[1] and parts[2]:
            try:port=int(parts[3])
            except Exception:continue
            if 1<=port<=65535:
                targets.append({"kind":"tcp","name":parts[1][:80],"host":parts[2],"port":port})
    for i,uri in enumerate(VPN_NODES):
        try:
            p=urllib.parse.urlsplit(uri)
            host=p.hostname
            port=int(p.port or 443)
            if host:
                targets.append({"kind":"tcp","name":"VPN · "+node_label(uri,i),"host":host,"port":port})
        except Exception:
            continue
    seen=set();out=[]
    for target in targets:
        key=target_key(target)
        if key in seen:continue
        seen.add(key);out.append(target)
    return out

def target_key(target):
    if target["kind"]=="tcp":
        return f"tcp:{target['host']}:{target['port']}"
    return f"{target['kind']}:{target['url']}"

def load_state():
    try:
        with open(STATE_PATH,"r",encoding="utf-8") as f:
            data=json.load(f)
        return data if isinstance(data,dict) else {}
    except Exception:
        return {}

def save_state(state):
    directory=os.path.dirname(STATE_PATH) or "."
    os.makedirs(directory,exist_ok=True)
    fd,tmp=tempfile.mkstemp(prefix=".vo1d-watch-",suffix=".json",dir=directory)
    try:
        with os.fdopen(fd,"w",encoding="utf-8") as f:
            json.dump(state,f,ensure_ascii=False,separators=(",",":"))
        os.replace(tmp,STATE_PATH)
    finally:
        if os.path.exists(tmp):
            try:os.remove(tmp)
            except OSError:pass

def telegram_alert(text):
    if not BOT_TOKEN or not CHAT_ID:
        print("watchdog alert skipped: ALERT_BOT_TOKEN/BOT_TOKEN or ALERT_CHAT_ID/ADMIN_ID missing",flush=True)
        return False
    payload=urllib.parse.urlencode({
        "chat_id":CHAT_ID,
        "text":text,
        "parse_mode":"HTML",
        "disable_web_page_preview":"true",
    }).encode()
    req=urllib.request.Request(
        f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
        data=payload,
        headers={"Content-Type":"application/x-www-form-urlencoded","User-Agent":"VO1D-Watchdog/1.0"},
    )
    try:
        with urllib.request.urlopen(req,timeout=12) as r:
            return 200<=getattr(r,"status",200)<300
    except Exception as e:
        print("watchdog telegram error:",repr(e),flush=True)
        return False

def check_http(target):
    started=time.monotonic()
    req=urllib.request.Request(target["url"],headers={"User-Agent":"VO1D-Watchdog/1.0","Cache-Control":"no-cache"})
    try:
        with urllib.request.urlopen(req,timeout=TIMEOUT) as r:
            status=int(getattr(r,"status",200))
            body=r.read(65536)
        ms=int((time.monotonic()-started)*1000)
        if not 200<=status<300:
            return False,f"HTTP {status}",ms
        if target["kind"]=="health":
            try:data=json.loads(body.decode("utf-8","replace"))
            except Exception:return False,"invalid health JSON",ms
            if not data.get("ok"):
                comps=data.get("components") or {}
                bad=", ".join(f"{k}={v}" for k,v in comps.items() if v!="ok")
                return False,(bad or "health ok=false")[:300],ms
        return True,f"HTTP {status}",ms
    except Exception as e:
        return False,str(e)[:300],None

def check_tcp(target):
    started=time.monotonic()
    try:
        with socket.create_connection((target["host"],int(target["port"])),timeout=TIMEOUT):
            pass
        return True,"TCP connected",int((time.monotonic()-started)*1000)
    except Exception as e:
        return False,str(e)[:300],None

def check_target(target):
    if target["kind"]=="tcp":return check_tcp(target)
    return check_http(target)

def transition(entry,ok):
    entry=dict(entry or {})
    state=entry.get("state","unknown")
    failures=int(entry.get("failures",0) or 0)
    recoveries=int(entry.get("recoveries",0) or 0)
    event=None
    if ok:
        failures=0;recoveries+=1
        if state=="down" and recoveries>=RECOVERY_THRESHOLD:
            state="up";event="recovered"
        elif state=="unknown" and recoveries>=RECOVERY_THRESHOLD:
            state="up"
    else:
        recoveries=0;failures+=1
        if state!="down" and failures>=FAILURE_THRESHOLD:
            state="down";event="down"
    entry.update({"state":state,"failures":failures,"recoveries":recoveries})
    return entry,event

def format_alert(target,event,detail,latency):
    name=esc(target["name"])
    latency_text=f"\nLatency: <b>{latency} ms</b>" if latency is not None else ""
    if target["kind"]=="tcp":
        endpoint=f"{esc(target['host'])}:{int(target['port'])}"
    else:
        endpoint=esc(target["url"])
    if event=="down":
        return (
            f"🚨 <b>VO1D ALERT · DOWN</b>\n"
            f"<b>{name}</b>\n"
            f"<code>{endpoint}</code>\n"
            f"Причина: <code>{esc(detail)}</code>{latency_text}"
        )
    return (
        f"✅ <b>VO1D RECOVERED</b>\n"
        f"<b>{name}</b> снова отвечает.\n"
        f"<code>{endpoint}</code>{latency_text}"
    )

def run_once(targets,state,send_alert=telegram_alert):
    changed=False
    for target in targets:
        key=target_key(target)
        ok,detail,latency=check_target(target)
        entry=state.get(key,{})
        entry,event=transition(entry,ok)
        entry.update({
            "name":target["name"],
            "kind":target["kind"],
            "last_check":int(time.time()),
            "last_ok":bool(ok),
            "detail":str(detail)[:300],
            "latency_ms":latency,
        })
        state[key]=entry;changed=True
        label="UP" if ok else "FAIL"
        print(f"{label} {target['name']} {detail} {latency if latency is not None else '-'}ms",flush=True)
        if event:
            send_alert(format_alert(target,event,detail,latency))
    return changed

def main():
    targets=parse_targets()
    if not targets:
        raise SystemExit("No watchdog targets. Set WATCH_PROJECT_URL/PUBLIC_URL, VPN_NODES, or WATCH_TARGETS.")
    print(f"VO1D watchdog started: targets={len(targets)} interval={INTERVAL}s failures={FAILURE_THRESHOLD}",flush=True)
    if STARTUP_ALERT:
        telegram_alert(f"🛡 <b>VO1D WATCHDOG ONLINE</b>\nМониторинг запущен. Целей: <b>{len(targets)}</b>.")
    state=load_state()
    while True:
        try:
            if run_once(targets,state):save_state(state)
        except Exception as e:
            print("watchdog loop error:",repr(e),flush=True)
        time.sleep(INTERVAL)

if __name__=="__main__":
    main()
