#!/usr/bin/env python3
import os
import tempfile
import unittest

_TMP=tempfile.TemporaryDirectory()
os.environ["DB_PATH"]=os.path.join(_TMP.name,"vo1d-test.db")
os.environ["BOT_TOKEN"]="test-token"
os.environ["ADMIN_ID"]="1"
os.environ["COMMUNITY_ENABLED"]="0"

import main as app


class CoreLogicTests(unittest.TestCase):
    def setUp(self):
        with app.db() as c:
            for table in (
                "payment_receipts","balance_transactions","subscription_events",
                "referral_rewards","reminders","trial_claims","pending_actions",
                "devices","gift_codes","promo_redemptions","payments","users",
            ):
                c.execute(f"DELETE FROM {table}")

    def add_user(self,uid=100,balance=0,sub_until=0,auto_renew=0,auto_renew_days=30):
        with app.db() as c:
            c.execute(
                """INSERT INTO users(
                  id,username,first_name,joined_at,last_seen,trial_claimed,sub_until,banned,
                  balance_cents,sub_token,vpn_uuid,auto_renew,auto_renew_days,notifications,welcome_done
                ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    uid,"user","User",app.now(),app.now(),0,int(sub_until),0,
                    int(balance),f"token-{uid}",f"00000000-0000-4000-8000-{uid:012d}",
                    int(auto_renew),int(auto_renew_days),1,1,
                ),
            )

    def test_manual_payment_grants_exact_plan_days(self):
        self.add_user()
        pid=app.make_payment(100,"card",30)
        result=app.fulfill_manual_payment(pid)
        self.assertEqual(result["status"],"ok")
        self.assertEqual(result["days"],30)
        with app.db() as c:
            event=c.execute("SELECT days,source FROM subscription_events WHERE user_id=100").fetchone()
        self.assertEqual(event["days"],30)
        self.assertEqual(event["source"],"manual:card")

    def test_auto_renew_survives_database_init(self):
        self.add_user(auto_renew=1)
        app.init_db()
        with app.db() as c:
            value=c.execute("SELECT auto_renew FROM users WHERE id=100").fetchone()["auto_renew"]
        self.assertEqual(value,1)

    def test_auto_renew_charges_balance_once(self):
        old_end=app.now()+3600
        self.add_user(balance=500,sub_until=old_end,auto_renew=1,auto_renew_days=30)
        old_send_once=app.send_once
        old_notify=app.notify_referral_reward
        app.send_once=lambda *args,**kwargs: True
        app.notify_referral_reward=lambda *args,**kwargs: None
        try:
            app.process_auto_renewals()
        finally:
            app.send_once=old_send_once
            app.notify_referral_reward=old_notify
        with app.db() as c:
            user=c.execute("SELECT balance_cents,sub_until FROM users WHERE id=100").fetchone()
            payments=c.execute("SELECT COUNT(*) n FROM payments WHERE user_id=100 AND method='balance' AND status='paid'").fetchone()["n"]
        self.assertEqual(user["balance_cents"],500-app.PLANS[30]["usd"])
        self.assertGreaterEqual(user["sub_until"],old_end+30*86400)
        self.assertEqual(payments,1)

    def test_only_vless_credentials_are_personalized(self):
        old=app.PER_USER_KEYS
        app.PER_USER_KEYS=True
        row={"vpn_uuid":"11111111-1111-4111-8111-111111111111"}
        try:
            vless="vless://old-id@example.com:443?security=reality#VO1D"
            trojan="trojan://secret@example.com:443?security=tls#VO1D"
            self.assertTrue(app.personalize_node(vless,row).startswith("vless://11111111-1111-4111-8111-111111111111@"))
            self.assertEqual(app.personalize_node(trojan,row),trojan)
        finally:
            app.PER_USER_KEYS=old

    def test_database_health(self):
        self.assertTrue(app.database_healthy())


if __name__=="__main__":
    unittest.main(verbosity=2)
