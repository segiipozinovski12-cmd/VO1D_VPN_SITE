import os, json, time, base64, socket, threading, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor

SOURCE_TEMPLATE=os.getenv(
    "COMMUNITY_SOURCE_TEMPLATE",
    "https://raw.githubusercontent.com/Au1rxx/free-vpn-subscriptions/main/output/by-country/v2ray-base64-{country}.txt"
)
COUNTRY_NAMES={
    "JP":"Japan","US":"United States","NL":"Netherlands","SG":"Singapore",
    "DE":"Germany","GB":"United Kingdom","FR":"France","PL":"Poland",
    "CA":"Canada","HK":"Hong Kong","KR":"Korea","TW":"Taiwan",
    "TR":"Turkey","RO":"Romania","FI":"Finland"
}
ALLOWED_SCHEMES={"vless","vmess","trojan","ss"}

def _b64decode_text(value):
    raw="".join(str(value or "").split())
    raw += "="*((4-len(raw)%4)%4)
    return base64.b64decode(raw.encode(),validate=False).decode("utf-8","ignore")

def _vmess_json(uri):
    try:
        payload=uri.split("://",1)[1]
        return json.loads(_b64decode_text(payload))
    except Exception:
        return None

def _endpoint(uri):
    try:
        scheme=uri.split("://",1)[0].lower()
        if scheme=="vmess":
            obj=_vmess_json(uri)
            if not obj:return None
            host=str(obj.get("add","")).strip()
            port=int(obj.get("port",0) or 0)
            return (host,port) if host and port else None
        parsed=urllib.parse.urlsplit(uri)
        if parsed.hostname and parsed.port:
            return parsed.hostname,int(parsed.port)
    except Exception:
        return None
    return None

def _tcp_alive(uri,timeout=1.4):
    ep=_endpoint(uri)
    if not ep:return False
    try:
        with socket.create_connection(ep,timeout=timeout):
            return True
    except Exception:
        return False

def _rename(uri,label):
    scheme=uri.split("://",1)[0].lower()
    if scheme=="vmess":
        obj=_vmess_json(uri)
        if not obj:return uri
        obj["ps"]=label
        payload=base64.b64encode(
            json.dumps(obj,ensure_ascii=False,separators=(",",":")).encode()
        ).decode()
        return "vmess://"+payload
    base=uri.split("#",1)[0]
    return base+"#"+urllib.parse.quote(label,safe="")

class CommunityPool:
    def __init__(self):
        self.enabled=os.getenv("COMMUNITY_ENABLED","0").strip().lower() in ("1","true","yes","on")
        raw=os.getenv("COMMUNITY_COUNTRIES","JP,US,NL,SG,DE,GB,FR,PL,CA")
        self.countries=[x.strip().upper() for x in raw.split(",") if x.strip().upper() in COUNTRY_NAMES]
        self.per_country=max(1,min(5,int(os.getenv("COMMUNITY_PER_COUNTRY","2"))))
        self.candidate_limit=max(self.per_country,min(40,int(os.getenv("COMMUNITY_CANDIDATE_LIMIT","18"))))
        self.refresh_seconds=max(300,int(os.getenv("COMMUNITY_REFRESH_SECONDS","900")))
        raw_excluded=os.getenv(
            "COMMUNITY_EXCLUDE",
            "PL:01,PL:02,FR:01,US:01,JP:01,JP:02,DE:01,DE:02"
        )
        self.excluded={
            x.strip().upper().replace("-",":")
            for x in raw_excluded.split(",") if x.strip()
        }
        self._lock=threading.Lock()
        self._nodes={}
        self._updated_at=0
        self._errors={}

    def snapshot(self):
        with self._lock:
            return {
                "enabled":self.enabled,
                "updated_at":self._updated_at,
                "countries":{k:list(v) for k,v in self._nodes.items()},
                "errors":dict(self._errors),
            }

    def flattened(self):
        snap=self.snapshot()
        out=[]
        for cc in self.countries:
            out.extend(snap["countries"].get(cc,[]))
        return out

    def _fetch_country(self,cc):
        url=SOURCE_TEMPLATE.format(country=cc)
        req=urllib.request.Request(url,headers={"User-Agent":"VO1D-Community-Pool/1.0"})
        with urllib.request.urlopen(req,timeout=20) as r:
            raw=r.read(2_500_000)
        decoded=_b64decode_text(raw.decode())
        unique=[]
        seen=set()
        for line in decoded.splitlines():
            uri=line.strip()
            if "://" not in uri:continue
            scheme=uri.split("://",1)[0].lower()
            if scheme not in ALLOWED_SCHEMES:continue
            key=uri.split("#",1)[0]
            if key in seen:continue
            seen.add(key);unique.append(uri)
            if len(unique)>=self.candidate_limit:break
        if not unique:return []
        workers=min(12,len(unique))
        with ThreadPoolExecutor(max_workers=workers) as ex:
            alive=list(ex.map(_tcp_alive,unique))
        selected=[u for u,ok in zip(unique,alive) if ok][:self.per_country]
        out=[]
        for idx,uri in enumerate(selected,1):
            slot=f"{cc}:{idx:02d}"
            if slot in self.excluded:
                continue
            out.append(_rename(uri,f"VO1D · {cc} · {idx:02d}"))
        return out

    def refresh(self):
        if not self.enabled:return self.snapshot()
        nodes={};errors={}
        for cc in self.countries:
            try:
                result=self._fetch_country(cc)
                if result:nodes[cc]=result
                else:errors[cc]="no_live_nodes"
            except Exception as e:
                errors[cc]=type(e).__name__
        with self._lock:
            if nodes:self._nodes=nodes
            self._errors=errors
            self._updated_at=int(time.time())
        return self.snapshot()

COMMUNITY_POOL=CommunityPool()

def community_worker():
    if not COMMUNITY_POOL.enabled:return
    time.sleep(3)
    while True:
        try:
            snap=COMMUNITY_POOL.refresh()
            total=sum(len(v) for v in snap["countries"].values())
            print(f"community refresh: nodes={total} countries={len(snap['countries'])} errors={len(snap['errors'])}",flush=True)
        except Exception as e:
            print("community refresh error",repr(e),flush=True)
        time.sleep(COMMUNITY_POOL.refresh_seconds)
