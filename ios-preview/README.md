# VO1D iPhone Simulator preview

The preview shares the real SwiftUI app source in `../ios/VO1DVPN`. It has no Packet Tunnel target, Swift package dependency, VPN entitlement, backend requirement or signing requirement. Demo mode is compiled only for an iOS Simulator.

```sh
cd ~/Downloads/VO1D_VPN_SITE-main/ios-preview
xcodegen generate
open VO1D_VPN_PREVIEW.xcodeproj
```

Select **VO1D_VPN_PREVIEW**, choose an **iPhone Simulator**, and press **Run**. Requires Xcode with iOS 17 or newer and XcodeGen (`brew install xcodegen`).

The first launch opens Home automatically. Connect takes about 840 ms. Demo ping and traffic are local simulations; no tunnel is installed. Log Out returns to an **Enter demo** button without requiring a key. Nickname, avatar, favorites, last manually selected location and preferences persist locally.

## Validation

```sh
xcodegen generate
xcodebuild -project VO1D_VPN_PREVIEW.xcodeproj -scheme VO1D_VPN_PREVIEW \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

# Use an installed simulator name (xcrun simctl list devices available).
xcodebuild -project VO1D_VPN_PREVIEW.xcodeproj -scheme VO1D_VPN_PREVIEW \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test
```

GitHub Actions selects an available iPhone automatically, runs unit and UI tests, and uploads screenshots and the `.xcresult` report as `VO1D-preview-validation`.

The unit suite exercises cancellation, route switching, country-neutral Fastest selection, persistence and separation of session ticks from the app publisher. The UI journey covers launch, connect, disconnect, search, favorites, ping refresh, route switching, profile and settings.

Production builds remain in `../ios`. A physical iPhone uses API key activation, `NETunnelProviderManager`, Packet Tunnel and the existing pinned Xray package. Unsigned compile:

```sh
cd ../ios
xcodegen generate
xcodebuild -project VO1D_VPN.xcodeproj -scheme VO1D_VPN \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build
```

A successful unsigned build verifies compilation, not real-device routing, DNS behavior or frame rate. Real VPN installation still requires Network Extension provisioning. Speed and traffic counters display `—` on iPhone until the tunnel core provides actual measurements.
