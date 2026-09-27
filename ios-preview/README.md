# VO1D_VPN Simulator Preview

This project is only for Xcode Simulator / UI preview.

It uses the real VO1D SwiftUI application sources from ../ios/VO1DVPN, but does not embed the Packet Tunnel extension or Xray package.

In iOS Simulator the app automatically:
- skips key login;
- creates a demo active subscription;
- loads demo countries;
- changes ping values;
- simulates Connecting / Connected / Disconnecting;
- allows server switching, Profile and Settings.

## Open

```bash
cd ~/Downloads/VO1D_VPN_SITE-main/ios-preview
xcodegen generate
open VO1D_VPN_PREVIEW.xcodeproj
```

Then choose any iPhone Simulator and press Run.
