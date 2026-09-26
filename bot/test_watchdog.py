#!/usr/bin/env python3
import os, tempfile, unittest

_TMP=tempfile.TemporaryDirectory()
os.environ["WATCH_PROJECT_URL"]="https://example.com"
os.environ["WATCH_TARGETS"]="tcp|RU-01|203.0.113.10|443\nhttp|STATUS|https://status.example.com/"
os.environ["VPN_NODES"]="vless://id@198.51.100.10:8443?security=reality#VO1D%20RU%2002"
os.environ["WATCH_FAILURE_THRESHOLD"]="3"
os.environ["WATCH_RECOVERY_THRESHOLD"]="1"
os.environ["WATCH_STATE_PATH"]=os.path.join(_TMP.name,"state.json")

import watchdog as app

class WatchdogTests(unittest.TestCase):
    def test_target_parsing(self):
        targets=app.parse_targets()
        kinds=[x["kind"] for x in targets]
        names=[x["name"] for x in targets]
        self.assertIn("health",kinds)
        self.assertIn("tcp",kinds)
        self.assertIn("VO1D PROJECT",names)
        self.assertIn("RU-01",names)
        self.assertTrue(any("VO1D RU 02" in x for x in names))

    def test_failure_threshold_and_recovery(self):
        state={}
        event=None
        for _ in range(2):
            state,event=app.transition(state,False)
            self.assertIsNone(event)
        state,event=app.transition(state,False)
        self.assertEqual(event,"down")
        self.assertEqual(state["state"],"down")
        state,event=app.transition(state,True)
        self.assertEqual(event,"recovered")
        self.assertEqual(state["state"],"up")

    def test_no_repeat_down_spam(self):
        state={}
        for _ in range(3):state,event=app.transition(state,False)
        self.assertEqual(event,"down")
        state,event=app.transition(state,False)
        self.assertIsNone(event)
        self.assertEqual(state["state"],"down")

if __name__=="__main__":
    unittest.main(verbosity=2)
