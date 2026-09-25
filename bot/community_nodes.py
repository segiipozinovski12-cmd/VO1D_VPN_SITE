import os, json, time, base64, socket, threading, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor

SOURCE_TEMPLATE=os.getenv(
    "COMMUNITY_SOURCE_TEMPLATE",
    "https://raw.githubusercontent.com/Au1rxx/free-vpn-subscriptions/main/output/by-country/v2ray-base64-{country}.txt"
)
RU_SOURCE_TEMPLATE=os.getenv(
    "COMMUNITY_RU_SOURCE",
    "https://raw.githubusercontent.com/Au1rxx/free-vpn-subscriptions/main/output/country/RU/v2ray-base64-0001.txt"
)
COUNTRY_NAMES={
    "JP":"Japan","US":"United States","NL":"Netherlands","SG":"Singapore",
    "DE":"Germany","GB":"United Kingdom","FR":"France","PL":"Poland",
    "CA":"Canada","HK":"Hong Kong","KR":"Korea","TW":"Taiwan",
    "TR":"Turkey","RO":"Romania","FI":"Finland","RU":"Russia"
}
ALLOWED_SCHEMES={"vless","vmess","trojan","ss","hy2","hysteria2"}
# These RU endpoints were confirmed by the client as unusable/N/A, so never publish them again.
RU_BLOCKED_HOSTS={"91.240.86.70","45.12.75.242","83.222.26.101"}

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
    scheme=uri.split("://",1)[0].lower()
    ep=_endpoint(uri)
    if not ep:return False
    if scheme in ("hy2","hysteria2"):
        # We cannot validate a QUIC/Hysteria2 tunnel with a TCP probe.
        # Do not publish it as "healthy" until we have a protocol-aware end-to-end check.
        return False
    try:
        with socket.create_connection(ep,timeout=timeout):
            return True
    except Exception:
        return False

def _hy2_score(uri):
    try:
        p=urllib.parse.urlsplit(uri)
        q=urllib.parse.parse_qs(p.query)
        sni=(q.get("sni") or [""])[0].strip()
        insecure=(q.get("insecure") or ["0"])[0].strip().lower()
        score=0
        if insecure not in ("1","true","yes"):score+=2
        if sni and not sni.replace(".","").isdigit():score+=3
        return score
    except Exception:
        return 0

def _candidate_score(uri,cc=""):
    try:
        scheme=uri.split("://",1)[0].lower()
        score={"vless":70,"trojan":55,"vmess":45,"ss":35,"hy2":5,"hysteria2":5}.get(scheme,0)
        if scheme=="vless":
            p=urllib.parse.urlsplit(uri)
            q=urllib.parse.parse_qs(p.query)
            security=(q.get("security") or [""])[0].lower()
            transport=(q.get("type") or [""])[0].lower()
            flow=(q.get("flow") or [""])[0].lower()
            if cc=="RU":
                # On the user's network, the previously chosen RU Reality endpoints returned N/A.
                # Prefer ordinary TCP-friendly WS VLESS first, then Shadowsocks.
                if transport=="ws":score+=80
                if security=="reality":score-=45
            else:
                if security=="reality":score+=35
                if transport in ("tcp",""):score+=15
                if "vision" in flow:score+=10
        if cc=="RU" and scheme=="ss":
            score+=90
        if cc=="RU" and scheme in ("hy2","hysteria2"):
            score-=1000
        return score
    except Exception:
        return 0

def _dedupe_endpoints(items,cc=""):
    best={}
    passthrough=[]
    for uri in items:
        ep=_endpoint(uri)
        if not ep:
            passthrough.append(uri);continue
        old=best.get(ep)
        if old is None or _candidate_score(uri,cc)>_candidate_score(old,cc):
            best[ep]=uri
    return passthrough+list(best.values())

def _prefer_same_endpoint(items):
    out=[]; hy2={}
    for uri in items:
        scheme=uri.split("://",1)[0].lower()
        if scheme not in ("hy2","hysteria2"):
            out.append(uri);continue
        ep=_endpoint(uri)
        if not ep:
            out.append(uri);continue
        previous=hy2.get(ep)
        if previous is None or _hy2_score(uri)>_hy2_score(previous):
            hy2[ep]=uri
    out.extend(hy2.values())
    return out

def _normalize_uri(uri):
    try:
        scheme=uri.split("://",1)[0].lower()
        if scheme!="vless":
            return uri
        p=urllib.parse.urlsplit(uri)
        q=urllib.parse.parse_qsl(p.query,keep_blank_values=True)
        keys={k.lower() for k,_ in q}
        if "encryption" not in keys:
            q.append(("encryption","none"))
        qd={k.lower():v for k,v in q}
        if qd.get("type","").lower() in ("","tcp") and "headertype" not in keys:
            q.append(("headerType","none"))
        query=urllib.parse.urlencode(q,doseq=True,safe="-._~")
        return urllib.parse.urlunsplit((p.scheme,p.netloc,p.path,query,p.fragment))
    except Exception:
        return uri

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
        raw=os.getenv("COMMUNITY_COUNTRIES","JP,US,NL,SG,DE,GB,FR,PL,CA,RU")
        requested=[x.strip().upper() for x in raw.split(",") if x.strip().upper() in COUNTRY_NAMES]
        forced=os.getenv("COMMUNITY_FORCE_COUNTRIES","RU")
        for cc in [x.strip().upper() for x in forced.split(",") if x.strip().upper() in COUNTRY_NAMES]:
            if cc not in requested:
                requested.append(cc)
        self.countries=requested
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
        url=RU_SOURCE_TEMPLATE if cc=="RU" else SOURCE_TEMPLATE.format(country=cc)
        req=urllib.request.Request(url,headers={"User-Agent":"VO1D-Community-Pool/1.0"})
        with urllib.request.urlopen(req,timeout=20) as r:
            raw=r.read(2_500_000)
        decoded=_b64decode_text(raw.decode())
        unique=[]
        seen=set()
        limit=max(self.candidate_limit,60) if cc=="RU" else self.candidate_limit
        for line in decoded.splitlines():
            uri=_normalize_uri(line.strip())
            if "://" not in uri:continue
            scheme=uri.split("://",1)[0].lower()
            if scheme not in ALLOWED_SCHEMES:continue
            if cc=="RU":
                if scheme in ("hy2","hysteria2"):
                    continue
                ep=_endpoint(uri)
                if ep and ep[0] in RU_BLOCKED_HOSTS:
                    continue
            key=uri.split("#",1)[0]
            if key in seen:continue
            seen.add(key);unique.append(uri)
            if len(unique)>=limit:break
        if not unique:return []
        unique=_dedupe_endpoints(unique,cc)
        if cc=="RU":
            unique.sort(key=lambda u:_candidate_score(u,cc),reverse=True)
        else:
            unique=_prefer_same_endpoint(unique)
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
