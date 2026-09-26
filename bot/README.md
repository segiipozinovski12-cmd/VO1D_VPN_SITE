# VO1D_VPN Telegram Bot

Deploy this folder as a second Railway service.

## Railway
1. New Service -> GitHub Repo -> this repository.
2. Set Root Directory to /bot.
3. Add Variables:
   BOT_TOKEN=rotated Telegram bot token
   ADMIN_ID=8632158680
   ADMIN_USERNAME=vo1d_root
   CHANNEL_ID=-100xxxxxxxxxx
   CHANNEL_USERNAME=your_channel
   CHANNEL_URL=https://t.me/your_channel
   SITE_URL=https://your-site.up.railway.app
   PUBLIC_URL=https://your-bot-service.up.railway.app
   SUPPORT_URL=https://t.me/vo1d_root
   TRIAL_HOURS=168
   DB_PATH=/data/vo1d.db
   VPN_NODES=<one permitted VPN config URI per line>

4. Add a Railway Volume mounted at /data so users/subscriptions survive redeploys.
5. Generate a public domain for this bot service, then put that full HTTPS URL into PUBLIC_URL.

## VPN_NODES
Use only nodes you own or are authorized to distribute. Put one Happ-compatible config URI per line, e.g.:
vless://...
trojan://...
ss://...
socks://...

## Admin
/stats
/users
/payments
/grant USER_ID DAYS
/ban USER_ID
/unban USER_ID
/paid PAYMENT_ID
/balance USER_ID AMOUNT
/broadcast TEXT


## Additional country nodes

Additional VO1D country nodes can be appended to the same Happ subscription as the London node.

Variables:
- COMMUNITY_ENABLED=1
- COMMUNITY_COUNTRIES=JP,US,NL,SG,DE,GB,FR,PL,CA,RU
- COMMUNITY_PER_COUNTRY=2
- COMMUNITY_REFRESH_SECONDS=900
- COMMUNITY_EXCLUDE=PL:01,PL:02,FR:01,US:01,JP:01,JP:02,DE:01,DE:02
- COMMUNITY_FORCE_COUNTRIES=RU

The main /sub/<token> feed always places configured VPN_NODES first, then the surviving country nodes. Node labels are rewritten as `VO1D · CC · NN`.


## Payment behavior

- Telegram Stars are available automatically.
- Card and crypto currently create a manual payment request for the administrator.
- Auto-renewal uses the user's internal VO1D balance and runs when less than 24 hours remain.
- Card/crypto can later be replaced by provider webhooks without changing the subscription database model.



## Admin outage alerts

VO1D has two alert layers:

1. The bot itself sends the admin alerts when a configured VPN node changes state, a maintenance subsystem fails, Xray sync fails, or the service starts again.
2. `watchdog.py` is an independent monitor for outages where the main bot cannot alert because it is already down.

Run the watchdog as a **separate service/process** from the main bot. For stronger protection, host it on a different machine/provider from the service it monitors.

Example environment:

```
BOT_TOKEN=<same Telegram bot token, or a dedicated alert bot token>
ADMIN_ID=<your Telegram ID>
WATCH_PROJECT_URL=https://your-vo1d-bot.example
WATCH_INTERVAL=60
WATCH_FAILURE_THRESHOLD=3
WATCH_RECOVERY_THRESHOLD=1
WATCH_STATE_PATH=/data/vo1d-watchdog.json
```

If `VPN_NODES` is also present, the watchdog automatically monitors each configured VPN endpoint by TCP.

Extra VPS or service checks can be added with `WATCH_TARGETS`, one target per line:

```
tcp|RU-01|203.0.113.10|443
tcp|RU-01-SSH|203.0.113.10|22
health|VO1D PANEL|https://panel.example.com/health
http|PUBLIC STATUS|https://status.example.com/
```

The monitor waits for `WATCH_FAILURE_THRESHOLD` consecutive failures before sending **DOWN**, then sends one **RECOVERED** message when the target works again. It does not send the same outage alert on every check.

For a separate Railway watchdog service, use the same repository with root directory `/bot` and start command:

```
python watchdog.py
```

A monitor running inside the same process cannot report that process's death, which is why the external watchdog is intentionally separate.
