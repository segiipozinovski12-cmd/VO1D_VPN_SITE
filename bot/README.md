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


## VO1D Community

Optional public-relay country subscription. It is deliberately separate from the private VO1D node subscription.

Variables:
- COMMUNITY_ENABLED=1
- COMMUNITY_COUNTRIES=JP,US,NL,SG,DE,GB,FR,PL,CA
- COMMUNITY_PER_COUNTRY=2
- COMMUNITY_REFRESH_SECONDS=900

The Community feed consumes public third-party relay data from Au1rxx/free-vpn-subscriptions, keeps only supported URI schemes, checks candidate TCP reachability from the VO1D bot service, and renames display labels as `VO1D Community · CC · NN`.

Community relays are not operated by VO1D and must not be represented as private VO1D infrastructure. Keep the owned VPS subscription as the privacy-focused option.
