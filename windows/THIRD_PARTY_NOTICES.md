# Third-party components

- **sing-box 1.14.2**, SagerNet / nekohasekai. Original source and exact tag:
  https://github.com/SagerNet/sing-box/tree/v1.14.2 . Distributed without
  modifications in the Windows bundle. The upstream LICENSE is embedded
  and included as `LICENSES/sing-box-LICENSE.txt` in the ZIP distribution.
  The upstream binary includes its own dependencies, including libcronet.
- **Wintun 0.14.1**, WireGuard LLC. https://www.wintun.net/ . Original archive:
  https://www.wintun.net/builds/wintun-0.14.1.zip . The upstream LICENSE is
  embedded and included as `LICENSES/wintun-LICENSE.txt` in the ZIP.
- **Microsoft .NET 8 / WPF**, Microsoft and contributors:
  https://github.com/dotnet/runtime and https://github.com/dotnet/wpf .
  Distributed as the unmodified self-contained runtime under their upstream
  licenses and included third-party notices.

Pinned archive SHA-256 values and original download URLs are recorded in
`scripts/fetch_runtime.py`. The build verifies each downloaded archive.
The source for the VO1D GUI, configuration adapter and native WFP guard
is in this repository's `windows` directory.
