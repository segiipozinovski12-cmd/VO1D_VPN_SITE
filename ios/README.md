# VO1D_VPN for iPhone

Native iPhone VPN client built with SwiftUI and Apple's NetworkExtension framework.

## Current native stack

- SwiftUI app — no WebView and no browser wrapper
- VO1D activation key login
- Keychain session storage
- near-monochrome animated CONNECT UI with adaptive Liquid Glass on supported iOS versions
- live server list and TCP ping
- country-neutral Fastest selection based on measured latency
- profile, nickname, favorites, reconnect, auto-connect, secure DNS, IPv6 and kill-switch preferences
- NETunnelProviderManager + Packet Tunnel extension
- real Xray/VLESS packet forwarding through SwiftyXrayKit
- VLESS/REALITY support comes from Xray-core inside the Packet Tunnel
- IPv4 + IPv6 default routes through the tunnel
- DNS routed through the packet tunnel
- Telegram remains the place where subscriptions are purchased

## Backend URL

The app reads `VO1D_API_BASE_URL` from the build settings. The Xcode project defaults to
`https://REPLACE_ME.invalid` so a production build must inject the actual deployed VO1D backend URL.

Example:

```bash
xcodebuild ... VO1D_API_BASE_URL="https://your-vo1d-backend.example"
```

## Native IPA build

The GitHub Actions workflow `.github/workflows/ios-build.yml` builds a real iPhone app with
the Packet Tunnel extension and packages an unsigned `VO1D_VPN-unsigned.ipa` artifact.

An unsigned IPA is useful for build verification but cannot be installed on a normal stock iPhone.
A device-installable IPA must be signed with an Apple Developer certificate and provisioning
profiles that authorize the Network Extension entitlement.

## Build locally

1. Use a Mac with Xcode.
2. Install XcodeGen: `brew install xcodegen`.
3. In `ios/`, run `xcodegen generate`.
4. Open `VO1D_VPN.xcodeproj`.
5. Set the Apple Developer Team for both targets.
6. Set `VO1D_API_BASE_URL` to the deployed backend.
7. Enable the Network Extensions / Packet Tunnel capability for both App IDs.
8. Run on a physical iPhone.

Telegram path for the account key: Profile -> **Ключ для iPhone**.

## Third-party tunnel core

VO1D uses SwiftyXrayKit as the Apple packet-tunnel bridge. See `THIRD_PARTY_NOTICES.md`.
