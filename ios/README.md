# VO1D_VPN for iPhone

Native SwiftUI client for VO1D.

## Implemented

- VO1D activation key login, similar to an account-key flow
- Keychain session storage
- black / white / gray UI
- animated circular CONNECT control
- country list from the VO1D backend
- live TCP latency probes from the iPhone
- profile sheet, nickname, auto-connect and kill-switch preferences
- NetworkExtension manager and Packet Tunnel extension shell
- backend endpoints for activation, account state, servers and per-country tunnel config

## VPN core

The UI, account system and NetworkExtension container are implemented. VLESS packet forwarding still needs a compatible iOS packet-tunnel core linked into PacketTunnel/TunnelCoreAdapter.swift. NetworkExtension itself does not implement VLESS.

The adapter is intentionally separate so VO1D can choose the tunnel core and license before release.

## Build

1. Install Xcode on macOS.
2. Install XcodeGen with Homebrew: brew install xcodegen
3. Run xcodegen generate in this folder.
4. Open VO1D_VPN.xcodeproj.
5. Set the Apple Developer Team for both targets.
6. Set VO1D_API_BASE_URL in VO1DVPN/Resources/Info.plist to the deployed backend.
7. Enable the Packet Tunnel Network Extension capability for the App ID.
8. Link the production tunnel core before testing real VPN traffic.

Telegram path: Profile -> Ключ для iPhone.
