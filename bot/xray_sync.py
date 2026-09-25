#!/usr/bin/env python3
import os, json, time, shutil, tempfile, subprocess, urllib.request

API_URL=os.getenv("VO1D_API_URL","").rstrip("/")
SYNC_SECRET=os.getenv("XRAY_SYNC_SECRET","")
CONFIG_PATH=os.getenv("XRAY_CONFIG_PATH","/usr/local/etc/xray/config.json")
XRAY_BIN=os.getenv("XRAY_BIN","/usr/local/bin/xray")
INBOUND_TAG=os.getenv("XRAY_INBOUND_TAG","")
FLOW=os.getenv("XRAY_FLOW","xtls-rprx-vision")
INTERVAL=max(15,int(os.getenv("XRAY_SYNC_INTERVAL","60")))

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
    cur_key=[(x.get("id"),x.get("email"),x.get("flow")) for x in current]
    new_key=[(x.get("id"),x.get("email"),x.get("flow")) for x in wanted]
    if cur_key==new_key:return False

    backup=CONFIG_PATH+".vo1d-backup"
    shutil.copy2(CONFIG_PATH,backup)
    settings["clients"]=wanted
    directory=os.path.dirname(CONFIG_PATH) or "."
    fd,tmp=tempfile.mkstemp(prefix=".vo1d-xray-",suffix=".json",dir=directory)
    try:
        with os.fdopen(fd,"w",encoding="utf-8") as f:
            json.dump(config,f,ensure_ascii=False,indent=2)
            f.write("\n")
        os.replace(tmp,CONFIG_PATH)
        try:
            test_config()
        except Exception:
            shutil.copy2(backup,CONFIG_PATH)
            raise
        subprocess.run(["systemctl","restart","xray"],check=True,timeout=25)
        return True
    finally:
        if os.path.exists(tmp):
            try:os.remove(tmp)
            except OSError:pass

def main():
    print("VO1D Xray sync started",flush=True)
    while True:
        try:
            rows=fetch_clients()
            changed=apply_clients(rows)
            print(f"clients={len(rows)} changed={changed}",flush=True)
        except Exception as e:
            print("sync error:",repr(e),flush=True)
        time.sleep(INTERVAL)

if __name__=="__main__":
    main()
