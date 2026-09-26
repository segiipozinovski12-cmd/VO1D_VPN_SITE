#!/usr/bin/env python3
import os, json, time, shutil, tempfile, subprocess, urllib.request, urllib.parse, html

API_URL=os.getenv("VO1D_API_URL","").rstrip("/")
SYNC_SECRET=os.getenv("XRAY_SYNC_SECRET","")
CONFIG_PATH=os.getenv("XRAY_CONFIG_PATH","/usr/local/etc/xray/config.json")
XRAY_BIN=os.getenv("XRAY_BIN","/usr/local/bin/xray")
INBOUND_TAG=os.getenv("XRAY_INBOUND_TAG","")
FLOW=os.getenv("XRAY_FLOW","xtls-rprx-vision")
INTERVAL=max(15,int(os.getenv("XRAY_SYNC_INTERVAL","60")))
PRESERVE_UNMANAGED=os.getenv("XRAY_PRESERVE_UNMANAGED","1").strip().lower() in ("1","true","yes","on")
ALERT_BOT_TOKEN=os.getenv("ALERT_BOT_TOKEN",os.getenv("BOT_TOKEN","")).strip()
ALERT_CHAT_ID=os.getenv("ALERT_CHAT_ID",os.getenv("ADMIN_ID","")).strip()
ALERT_AFTER=max(1,int(os.getenv("XRAY_ALERT_AFTER","2")))

def telegram_alert(text):
    if not ALERT_BOT_TOKEN or not ALERT_CHAT_ID:return False
    data=urllib.parse.urlencode({
        "chat_id":ALERT_CHAT_ID,
        "text":text,
        "parse_mode":"HTML",
        "disable_web_page_preview":"true",
    }).encode()
    req=urllib.request.Request(
        f"https://api.telegram.org/bot{ALERT_BOT_TOKEN}/sendMessage",
        data=data,
        headers={"Content-Type":"application/x-www-form-urlencoded","User-Agent":"VO1D-Xray-Sync/1.1"},
    )
    try:
        with urllib.request.urlopen(req,timeout=12) as r:
            return 200<=getattr(r,"status",200)<300
    except Exception as e:
        print("alert error:",repr(e),flush=True)
        return False

def fetch_clients():
    if not API_URL or not SYNC_SECRET:
        raise RuntimeError("Set VO1D_API_URL and XRAY_SYNC_SECRET")
    req=urllib.request.Request(
        API_URL+"/internal/xray/clients",
        headers={"X-VO1D-Sync-Token":SYNC_SECRET,"User-Agent":"VO1D-Xray-Sync/1.0"}
    )
    with urllib.request.urlopen(req,timeout=15) as r:
        data=json.loads(r.read().decode())
    if not data.get("ok"):raise RuntimeError("Bad sync response")
    return data.get("clients",[])

def find_inbound(config):
    inbounds=config.get("inbounds") or []
    if INBOUND_TAG:
        for inbound in inbounds:
            if inbound.get("tag")==INBOUND_TAG and inbound.get("protocol")=="vless":
                return inbound
        raise RuntimeError("Configured VLESS inbound tag not found")
    for inbound in inbounds:
        if inbound.get("protocol")=="vless":
            return inbound
    raise RuntimeError("No VLESS inbound found")

def desired_clients(rows):
    out=[]
    for row in rows:
        cid=str(row.get("id","")).strip()
        if not cid:continue
        client={"id":cid,"email":str(row.get("email",""))}
        if FLOW:client["flow"]=FLOW
        out.append(client)
    return out

def test_config():
    p=subprocess.run([XRAY_BIN,"run","-test","-config",CONFIG_PATH],
                     capture_output=True,text=True,timeout=20)
    if p.returncode!=0:
        raise RuntimeError((p.stderr or p.stdout or "xray config test failed")[-2000:])

def apply_clients(rows):
    with open(CONFIG_PATH,"r",encoding="utf-8") as f:
        config=json.load(f)
    inbound=find_inbound(config)
    settings=inbound.setdefault("settings",{})
    wanted=desired_clients(rows)
    current=settings.get("clients") or []
    unmanaged=[]
    if PRESERVE_UNMANAGED:
        unmanaged=[
            dict(x) for x in current
            if not str(x.get("email","")).startswith("vo1d_")
        ]
    merged=unmanaged+wanted
    cur_key=[(x.get("id"),x.get("email"),x.get("flow")) for x in current]
    new_key=[(x.get("id"),x.get("email"),x.get("flow")) for x in merged]
    if cur_key==new_key:return False

    backup=CONFIG_PATH+".vo1d-backup"
    shutil.copy2(CONFIG_PATH,backup)
    settings["clients"]=merged
    directory=os.path.dirname(CONFIG_PATH) or "."
    fd,tmp=tempfile.mkstemp(prefix=".vo1d-xray-",suffix=".json",dir=directory)
    try:
        with os.fdopen(fd,"w",encoding="utf-8") as f:
            json.dump(config,f,ensure_ascii=False,indent=2)
            f.write("\n")
        os.replace(tmp,CONFIG_PATH)
        try:
            test_config()
            subprocess.run(["systemctl","restart","xray"],check=True,timeout=25)
        except Exception:
            shutil.copy2(backup,CONFIG_PATH)
            try:
                test_config()
                subprocess.run(["systemctl","restart","xray"],check=True,timeout=25)
            except Exception as rollback_error:
                raise RuntimeError(f"Xray update failed and rollback restart also failed: {rollback_error}")
            raise
        return True
    finally:
        if os.path.exists(tmp):
            try:os.remove(tmp)
            except OSError:pass

def main():
    print("VO1D Xray sync started",flush=True)
    failures=0
    alerted=False
    while True:
        try:
            rows=fetch_clients()
            changed=apply_clients(rows)
            print(f"clients={len(rows)} changed={changed}",flush=True)
            if alerted:
                telegram_alert("✅ <b>VO1D XRAY SYNC RECOVERED</b>\nСинхронизация клиентов снова работает.")
            failures=0
            alerted=False
        except Exception as e:
            failures+=1
            print("sync error:",repr(e),flush=True)
            if failures>=ALERT_AFTER and not alerted:
                telegram_alert(
                    "🚨 <b>VO1D XRAY SYNC DOWN</b>\n"
                    f"Ошибок подряд: <b>{failures}</b>\n"
                    f"<code>{html.escape(str(e)[:900])}</code>"
                )
                alerted=True
        time.sleep(INTERVAL)

if __name__=="__main__":
    main()
