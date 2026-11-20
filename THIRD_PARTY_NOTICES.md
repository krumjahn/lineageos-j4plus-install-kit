# Third-party notices

This project links to, quotes from, and is informed by work published by other
people and projects. None of it is vendored into this repository except where
explicitly stated below.

---

## LineageOS

The `wipe-frp.sh` reference in `docs/05-install-lineageos-and-gapps.md` points at
the official LineageOS FRP removal script:

- Repository: <https://github.com/LineageOS/android_vendor_lineage>
- Path: `prebuilt/common/bin/wipe-frp.sh`
- License: Apache License 2.0 (the LineageOS project is licensed under AOSP
  Apache 2.0 terms)

The script itself is **not** included here. This repository links to it so that
you always fetch the current version from the source of truth. Note that it is
only shipped into recovery from 2025 onward and is **not** present on the
`lineage-19.1` branch, so you will need to push it manually.

The LineageOS GApps guidance referenced in `docs/01` and `docs/05` comes from
<https://wiki.lineageos.org/gapps/>.

---

## Team Win / TWRP

TWRP for the `j4primelte` device is distributed by Team Win:

- Device page: <https://twrp.me/samsung/samsunggalaxyj4plus.html>
- Device tree: <https://github.com/TeamWin/android_device_samsung_j4primelte>
- Maintainer of this device's build: `kycii91`
- License: GPL-3.0

The TWRP image is **not** included in this repository. Its published SHA-256
and MD5 are recorded in `docs/01` and `docs/09` so you can verify the download.

---

## MindTheGapps

MindTheGapps is a separate project by the MindTheGapps team:

- <https://github.com/MindTheGapps/12.1.0-arm/releases/latest>
- License: Apache License 2.0

The package is **not** included here. The expected file size and the correct
version for LineageOS 19.1 on 32-bit ARM are documented in `docs/05`.

---

## samloader (samloader-rs)

The flashing tool used throughout this guide:

- <https://github.com/topjohnwu/samloader-rs>
- License: GPL-3.0

The upstream project is **not** vendored here. `docs/01` documents the two
source patches that were needed on the version used (a longer handshake timeout,
and the `smol` feature on the `nusb` backend). **Check whether upstream has
since landed them before you re-apply them yourself.**

---

## XDA forums

Several procedures in this guide follow community threads on XDA. The most
relevant:

- "Unofficial 12.1 LineageOS 19.1 for Galaxy J4 (j4primelte)" —
  <https://xdaforums.com/t/unofficial-12-1-lineageos-19-1-for-galaxy-j4-j4primelte.4517067/>
  (closed; its ROM link is dead)
- "Recovery [ROOT] [TWRP 3.3.1-1] Galaxy J4 (J415F/FN/G/DS)" —
  <https://xdaforums.com/t/recovery-root-twrp-3-3-1-1-galaxy-j4-j415f-fn-g-ds.3876876/>
- "How to bypass KG State and/or RMM state prenormal" — the source of the
  clock-backdate method in `docs/03`
- The current build line for this device —
  <https://xdaforums.com/t/revive-os-j4-plus-unofficial-nov-2026.4766304/>

Thread content is user-contributed and is quoted here for attribution.

---

## e.foundation and TheCustomDroid

Used as references for the KG State / RMM State mechanism:

- <https://community.e.foundation/t/know-your-hardware-samsung/28639/>
- <https://www.thecustomdroid.com/prenormal-rmm-state-on-samsung-galaxy-guide/>

---

## Samsung, of course

The firmware, the bootloader, the Odin/Loke protocol and the KG State lockout are
Samsung's. This project is an independent, unaffiliated set of notes and scripts
produced by a user documenting their own device. It is not endorsed by, nor
affiliated with, Samsung, LineageOS, Team Win, MindTheGapps or LineageOSOS.
