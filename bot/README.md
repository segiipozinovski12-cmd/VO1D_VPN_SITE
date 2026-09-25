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
   TRIAL_HOURS=24
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
