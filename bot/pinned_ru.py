import json, urllib.parse

def _first(seq, default=None):
    return seq[0] if isinstance(seq,list) and seq else default

def build_pinned_ru_uri(raw_json,label="VO1D · RU · 01"):
    if isinstance(raw_json,(bytes,bytearray)):
        raw_json=raw_json.decode("utf-8","ignore")
    data=json.loads(str(raw_json))
    outbounds=data.get("outbounds") or []
    outbound=None
    for item in outbounds:
        if item.get("tag")=="proxy" and item.get("protocol")=="vless":
            outbound=item
            break
    if outbound is None:
        for item in outbounds:
            if item.get("protocol")=="vless":
                outbound=item
                break
    if outbound is None:
        raise ValueError("VLESS proxy outbound not found")

    vnext=_first((outbound.get("settings") or {}).get("vnext") or [])
    if not isinstance(vnext,dict):
        raise ValueError("VLESS vnext is missing")
    user=_first(vnext.get("users") or [])
    if not isinstance(user,dict):
        raise ValueError("VLESS user is missing")

    address=str(vnext.get("address") or "").strip()
    port=int(vnext.get("port") or 0)
    user_id=str(user.get("id") or "").strip()
    if not address or not port or not user_id:
        raise ValueError("VLESS address/port/id is incomplete")

    stream=outbound.get("streamSettings") or {}
    network=str(stream.get("network") or "tcp").strip().lower()
    security=str(stream.get("security") or "none").strip().lower()
    reality=stream.get("realitySettings") or {}
    xhttp=stream.get("xhttpSettings") or {}

    if network!="xhttp":
        raise ValueError("Pinned RU profile must use XHTTP")
    if security!="reality":
        raise ValueError("Pinned RU profile must use Reality")

    sni=str(reality.get("serverName") or "").strip()
    pbk=str(reality.get("publicKey") or "").strip()
    sid=str(reality.get("shortId") or "").strip()
    fp=str(reality.get("fingerprint") or "chrome").strip() or "chrome"
    if not sni or not pbk:
        raise ValueError("Reality serverName/publicKey is missing")

    params=[
        ("encryption",str(user.get("encryption") or "none")),
        ("security","reality"),
        ("sni",sni),
        ("fp",fp),
        ("pbk",pbk),
    ]
    if sid:
        params.append(("sid",sid))
    flow=str(user.get("flow") or "").strip()
    if flow:
        params.append(("flow",flow))

    params.append(("type","xhttp"))
    path=str(xhttp.get("path") or "/").strip() or "/"
    mode=str(xhttp.get("mode") or "auto").strip() or "auto"
    host=str(xhttp.get("host") or "").strip()
    params.extend([("path",path),("mode",mode)])
    if host:
        params.append(("host",host))
    extra=xhttp.get("extra")
    if isinstance(extra,dict) and extra:
        params.append(("extra",json.dumps(extra,ensure_ascii=False,separators=(",",":"))))

    query=urllib.parse.urlencode(params,doseq=True,quote_via=urllib.parse.quote,safe="-._~")
    authority=f"{urllib.parse.quote(user_id,safe='-._~')}@{address}:{port}"
    fragment=urllib.parse.quote(label,safe="")
    uri=f"vless://{authority}?{query}#{fragment}"
    meta={
        "address":address,
        "port":port,
        "network":network,
        "security":security,
        "sni":sni,
        "label":label,
        "has_extra":bool(isinstance(extra,dict) and extra),
    }
    return uri,meta
