#!/usr/bin/env python3
import json, os, re, socket, subprocess, tempfile, time, urllib.parse, urllib.request

SOURCE=os.getenv(
    "RU_E2E_SOURCE",
    "https://raw.githubusercontent.com/kort0881/vpn-vless-configs-russia/main/data/githubmirror/ru-sni-local/vless.txt",
)
XRAY=os.getenv("XRAY_BIN","./xray")
MAX_CANDIDATES=max(4,min(24,int(os.getenv("RU_E2E_MAX","16"))))
RESULT_PATH=os.getenv("RU_E2E_RESULT","/tmp/ru-e2e.json")

def fetch_text(url):
    req=urllib.request.Request(url,headers={"User-Agent":"VO1D-RU-E2E/1.0"})
    with urllib.request.urlopen(req,timeout=20) as r:
        return r.read(4_000_000).decode("utf-8","ignore")

def source_ms(uri):
    try:
        frag=urllib.parse.unquote(uri.split("#",1)[1] if "#" in uri else "")
        m=re.search(r"\|\s*(\d+)ms\s*$",frag,re.I)
        return int(m.group(1)) if m else 999999
    except Exception:
        return 999999

def endpoint_geo(host):
    ips=[]
    try:
        socket.inet_aton(host)
        ips=[host]
    except OSError:
        try:
            ips=list(dict.fromkeys(x[4][0] for x in socket.getaddrinfo(host,None,socket.AF_INET,socket.SOCK_STREAM)))
        except Exception:
            ips=[]
    for ip in ips[:4]:
        try:
            req=urllib.request.Request(
                "https://ipwho.is/"+urllib.parse.quote(ip,safe="")+"?fields=success,country_code,ip",
                headers={"User-Agent":"VO1D-RU-E2E/1.0"},
            )
            with urllib.request.urlopen(req,timeout=7) as r:
                data=json.loads(r.read(4096).decode())
            code=str(data.get("country_code") or "").upper() if data.get("success",True) else ""
            if code:
                return code,ip
        except Exception:
            pass
    return "",""

def parse(uri):
    if not uri.startswith("vless://"):return None
    try:
        p=urllib.parse.urlsplit(uri)
        q=urllib.parse.parse_qs(p.query,keep_blank_values=True)
        host=p.hostname;port=p.port;uuid=urllib.parse.unquote(p.username or "")
        if not host or not port or not uuid:return None
        security=(q.get("security") or ["none"])[0].lower() or "none"
        network=(q.get("type") or ["tcp"])[0].lower() or "tcp"
        if network not in ("tcp","raw","grpc","xhttp","ws"):return None
        if security not in ("reality","tls","none"):return None
        if port not in (80,443,2053,2083,2087,2096,8443):return None
        sni=(q.get("sni") or [""])[0]
        pbk=(q.get("pbk") or [""])[0]
        if security=="reality" and (not sni or not pbk):return None
        return {
            "uri":uri,"host":host,"port":port,"uuid":uuid,
            "flow":(q.get("flow") or [""])[0],
            "network":network,"security":security,
            "sni":sni,"pbk":pbk,
            "sid":(q.get("sid") or [""])[0],
            "fp":(q.get("fp") or ["chrome"])[0] or "chrome",
            "spx":(q.get("spx") or ["/"])[0] or "/",
            "path":(q.get("path") or ["/"])[0] or "/",
            "host_header":(q.get("host") or [""])[0],
            "service_name":(q.get("serviceName") or [""])[0],
            "mode":(q.get("mode") or [""])[0],
            "allow_insecure":str((q.get("allowInsecure") or q.get("insecure") or ["0"])[0]).lower() in ("1","true","yes"),
            "source_ms":source_ms(uri),
        }
    except Exception:
        return None

def tcp_ms(host,port):
    started=time.monotonic()
    try:
        with socket.create_connection((host,port),timeout=2.5):pass
        return int((time.monotonic()-started)*1000)
    except Exception:return None

def xray_config(c,socks_port):
    client={"id":c["uuid"],"encryption":"none"}
    if c["flow"] and c["network"] in ("tcp","raw"):
        client["flow"]=c["flow"]
    stream={"network":c["network"],"security":c["security"]}
    if c["security"]=="reality":
        reality={"serverName":c["sni"],"fingerprint":c["fp"],"publicKey":c["pbk"],"spiderX":c["spx"]}
        if c["sid"]:reality["shortId"]=c["sid"]
        stream["realitySettings"]=reality
    elif c["security"]=="tls":
        tls={"serverName":c["sni"],"fingerprint":c["fp"],"allowInsecure":c["allow_insecure"]}
        stream["tlsSettings"]=tls
    if c["network"]=="grpc":
        stream["grpcSettings"]={"serviceName":c["service_name"],"multiMode":c["mode"]=="multi"}
    elif c["network"]=="ws":
        ws={"path":c["path"]}
        if c["host_header"]:ws["headers"]={"Host":c["host_header"]}
        stream["wsSettings"]=ws
    elif c["network"]=="xhttp":
        xh={"path":c["path"],"mode":c["mode"] or "auto"}
        if c["host_header"]:xh["host"]=c["host_header"]
        stream["xhttpSettings"]=xh
    return {
      "log":{"loglevel":"warning"},
      "inbounds":[{"listen":"127.0.0.1","port":socks_port,"protocol":"socks","settings":{"udp":False}}],
      "outbounds":[{
        "tag":"proxy","protocol":"vless",
        "settings":{"vnext":[{"address":c["host"],"port":c["port"],"users":[client]}]},
        "streamSettings":stream
      }]
    }

def curl_via(port,url,timeout=12):
    p=subprocess.run([
        "curl","-sS","--socks5-hostname",f"127.0.0.1:{port}",
        "--connect-timeout","5","--max-time",str(timeout),"-L",url
    ],capture_output=True,text=True)
    return p.returncode,p.stdout,p.stderr

def test(c,index):
    port=19080+index
    with tempfile.NamedTemporaryFile("w",suffix=".json",delete=False) as f:
        json.dump(xray_config(c,port),f)
        cfg=f.name
    proc=None
    try:
        check=subprocess.run([XRAY,"run","-test","-config",cfg],capture_output=True,text=True,timeout=10)
        if check.returncode!=0:
            return {"ok":False,"reason":"config","stderr":(check.stderr or check.stdout)[-500:]}
        proc=subprocess.Popen([XRAY,"run","-config",cfg],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
        time.sleep(1.0)
        if proc.poll() is not None:
            err=(proc.stderr.read() if proc.stderr else "")[-700:]
            return {"ok":False,"reason":"xray_start","stderr":err}
        code,out,err=curl_via(port,"https://ipwho.is/?fields=success,country_code,ip",10)
        if code!=0:
            return {"ok":False,"reason":"proxy_http","stderr":err[-500:]}
        try:geo=json.loads(out)
        except Exception:return {"ok":False,"reason":"geo_json","sample":out[:300]}
        exit_country=str(geo.get("country_code") or "").upper()
        exit_ip=str(geo.get("ip") or "")
        if exit_country!="RU":
            return {"ok":False,"reason":"wrong_exit","exit_country":exit_country,"exit_ip":exit_ip}
        code,_,err=curl_via(port,"https://ya.ru/",12)
        if code!=0:
            return {"ok":False,"reason":"ru_site","exit_ip":exit_ip,"stderr":err[-500:]}
        return {"ok":True,"exit_country":"RU","exit_ip":exit_ip}
    except Exception as e:
        return {"ok":False,"reason":"exception","error":repr(e)}
    finally:
        if proc is not None:
            proc.terminate()
            try:proc.wait(timeout=2)
            except Exception:proc.kill()
        try:os.unlink(cfg)
        except OSError:pass

def main():
    lines=[x.strip() for x in fetch_text(SOURCE).splitlines() if x.strip()]
    candidates=[]
    seen=set()
    for line in lines:
        c=parse(line)
        if not c:continue
        if c["host"] in seen:continue
        country,endpoint_ip=endpoint_geo(c["host"])
        if country!="RU":continue
        t=tcp_ms(c["host"],c["port"])
        if t is None:continue
        c["endpoint_ip"]=endpoint_ip
        c["tcp_ms"]=t
        seen.add(c["host"]);candidates.append(c)
    candidates.sort(key=lambda x:(x["source_ms"],x["tcp_ms"]))
    candidates=candidates[:MAX_CANDIDATES]
    print("RU E2E candidates:",[(x["host"],x.get("endpoint_ip"),x["port"],x["network"],x["security"],x["source_ms"],x["tcp_ms"]) for x in candidates],flush=True)
    results=[]
    for i,c in enumerate(candidates):
        result=test(c,i)
        row={"host":c["host"],"endpoint_ip":c.get("endpoint_ip"),"port":c["port"],"network":c["network"],"security":c["security"],"source_ms":c["source_ms"],"tcp_ms":c["tcp_ms"],**result}
        results.append(row)
        print("RU E2E result:",json.dumps(row,ensure_ascii=False),flush=True)
    winners=[(c,r) for c,r in zip(candidates,results) if r.get("ok")]
    payload={
      "ok":bool(winners),
      "checked":len(results),
      "winners":[
        {"uri":c["uri"],"host":c["host"],"port":c["port"],"source_ms":c["source_ms"],
         "tcp_ms":c["tcp_ms"],"exit_ip":r.get("exit_ip")}
        for c,r in winners[:4]
      ],
      "results":results,
    }
    with open(RESULT_PATH,"w",encoding="utf-8") as f:json.dump(payload,f,ensure_ascii=False,indent=2)
    print("RU E2E winners:",[(x[0]["host"],x[1].get("exit_ip")) for x in winners[:4]],flush=True)
    return 0 if winners else 2

if __name__=="__main__":
    raise SystemExit(main())
