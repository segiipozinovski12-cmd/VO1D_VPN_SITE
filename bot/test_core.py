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
                "app_sessions","devices","gift_codes","promo_redemptions","payments","users",
            ):
                c.execute(f"DELETE FROM {table}")
            c.execute("""UPDATE app_embedded_licenses
              SET redeemed_user_id=0,redeemed_at=0,issued_at=0,active=1""")

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

    def test_app_key_auth_roundtrip(self):
        self.add_user(sub_until=app.now()+7*86400)
        key,status=app.issue_app_key(100)
        self.assertEqual(status,"ok")
        self.assertTrue(key.startswith("VOID-"))
        token,row,status=app.activate_app_key(key,"iphone-test","iPhone")
        self.assertEqual(status,"ok")
        self.assertTrue(token)
        self.assertEqual(int(row["id"]),100)
        session=app.app_session_user(token)
        self.assertIsNotNone(session)
        self.assertEqual(int(session["id"]),100)
        app.revoke_app_session(token)
        self.assertIsNone(app.app_session_user(token))

    def test_iPhone_plan_inventory_has_exactly_400_keys(self):
        self.assertEqual(len(app.APP_EMBEDDED_KEYS),400)
        for days in (30,90,180,365):
            codes=[
                code for code,plan_days in app.APP_EMBEDDED_KEYS.items()
                if int(plan_days)==days
            ]
            self.assertEqual(len(codes),100)
            self.assertTrue(all(code.startswith("VOID-") for code in codes))
            self.assertTrue(all(len(code.split("-"))==4 for code in codes))

    def test_iPhone_admin_issuer_never_reuses_reserved_key(self):
        first=app.issue_embedded_app_license(30)
        second=app.issue_embedded_app_license(30)
        self.assertIsNotNone(first)
        self.assertIsNotNone(second)
        self.assertNotEqual(first,second)

        first_hash=app._secret_hash(app.normalize_app_key(first))
        second_hash=app._secret_hash(app.normalize_app_key(second))
        with app.db() as db:
            rows=db.execute(
                """SELECT code_hash,issued_at,redeemed_user_id
                   FROM app_embedded_licenses
                   WHERE code_hash IN (?,?)""",
                (first_hash,second_hash)
            ).fetchall()

        self.assertEqual(len(rows),2)
        self.assertTrue(all(int(row["issued_at"])>0 for row in rows))
        self.assertTrue(all(int(row["redeemed_user_id"])==0 for row in rows))

        state=app.app_embedded_inventory()[30]
        self.assertEqual(state["free"],98)
        self.assertEqual(state["issued"],2)
        self.assertEqual(state["redeemed"],0)

    def test_iPhone_plan_key_activates_real_subscription(self):
        key=next(
            code for code,days in app.APP_EMBEDDED_KEYS.items()
            if int(days)==30
        )

        started=app.now()
        token,row,status=app.activate_app_key(
            key,
            "iphone-license-test",
            "iPhone"
        )

        self.assertEqual(status,"ok")
        self.assertTrue(token)
        self.assertLess(int(row["id"]),0)
        self.assertGreaterEqual(
            int(row["sub_until"]),
            started+30*86400-2
        )

        normalized=app.normalize_app_key(key)
        digest=app._secret_hash(normalized)
        with app.db() as db:
            license_row=db.execute(
                """SELECT * FROM app_embedded_licenses
                   WHERE code_hash=?""",
                (digest,)
            ).fetchone()
        self.assertIsNotNone(license_row)
        self.assertEqual(int(license_row["plan_days"]),30)
        self.assertEqual(
            int(license_row["redeemed_user_id"]),
            int(row["id"])
        )

        session=app.app_session_user(token)
        self.assertIsNotNone(session)
        self.assertEqual(int(session["id"]),int(row["id"]))

    def test_app_key_requires_active_subscription(self):
        self.add_user(sub_until=app.now()-1)
        key,status=app.issue_app_key(100)
        self.assertIsNone(key)
        self.assertEqual(status,"inactive")

    def test_app_activation_code_carries_backend(self):
        old=app.PUBLIC_URL
        app.PUBLIC_URL="https://vpn.example.test"
        try:
            key="VOID-ABCD-EFGH-JKLM-NPQR"
            code=app.app_activation_code(key)
            self.assertTrue(code.startswith("VO1D1."))
            _,encoded,returned=code.split(".",2)
            import base64
            encoded += "="*((4-len(encoded)%4)%4)
            self.assertEqual(base64.urlsafe_b64decode(encoded).decode(),"https://vpn.example.test")
            self.assertEqual(returned,key)
        finally:
            app.PUBLIC_URL=old


if __name__=="__main__":
    unittest.main(verbosity=2)
