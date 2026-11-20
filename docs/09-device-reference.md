# 09 — Device reference

Verified facts about the device this kit was written for. Everything here was read off
the hardware, not copied from a forum post.

If you are working on a different `j4primelte` unit, re‑verify the ones marked
**device‑specific** — serial, sales code and bootloader string vary; the partition
map generally does not.

---

## 9.1 Identity

| Property | Value |
|---|---|
| Marketing name | Samsung Galaxy J4+ (2018) |
| Model | `SM-J415GN` (also SM‑J415F / FM / DS — all are `j4primelte`) |
| Device codename | `j4primelte` |
| Serial | `CXXXXXXXXXX` |
| Bootloader build | `J415GNDXS6BVJ1` |
| Sales code | `TGY` |
| Device ID | `0056997b9019` |
| Storage | 32 GB SAMSUNG QX63MB (FW 3) |
| SoC | Snapdragon 425 (MSM8937) |
| RAM / storage type | eMMC |
| Battery | **Non-removable** (the removable 2,600 mAh battery belongs to the older J4 / SM‑J400) |
| Home key | **Capacitive — cannot be held** |

> ⚠️ The J4+ has **no physical Home button**. Every guide that says
> "Volume Down + Home + Power" is wrong for this device.

---

## 9.2 USB signatures

| Mode | VID:PID | ioreg string |
|---|---|---|
| Download / Odin | `0x04E8:0x685D` | `MSM8953` |
| Android MTP | `0x04E8:0x6860` | `SAMSUNG_Android` |
| adb (system / stock recovery) | `0x18D1:0xD001` | `SAMSUNG_Android` |
| adb (TWRP) | `0x18D1:0x4EE2` | `SAMSUNG_Android` |

**Download mode has no ADB.** ADB requires a running Android or a recovery.

Detect without consuming the Odin session:

```bash
ioreg -p IOUSB -w0 2>/dev/null | grep -oE "(MSM8953|SAMSUNG_Android)@[0-9a-f]+[[:space:]]+<class IOUSBHostDevice, id 0x[0-9a-f]+" | head -1
```

---

## 9.3 Key combinations

| Action | Combination |
|---|---|
| Enter download mode | **Volume Up + Volume Down + Power**, then **Volume Up** on the warning screen |
| Enter download mode (no buttons) | `adb reboot download` — **more reliable than the buttons** |
| Unlock the bootloader | On the Odin warning screen, **hold Volume Up** (requires OEM unlocking enabled) |
| Recovery from download mode | Hold **Volume Up + Volume Down + Power**; release **Volume Down** when the screen goes off; keep **Volume Up + Power** |
| Boot TWRP | Same as recovery — but TWRP must be in `BOOT` |
| Leave download mode / hard reset | **Volume Down + Power** ~7–10 s |
| From TWRP to download mode | `adb reboot bootloader` — no button timing |

---

## 9.4 Partition table

From the device's own PIT (`device.pit`, 8192 bytes): project `COM_TAR2`, cpu tag
`MSM8937`, magic `0x12349876`, **57 entries**, block size **512 bytes**.

| Partition | ID | Blocks | by-name symlink | Notes |
|---|---|---|---|---|
| `BOOT` | 23 (`0x17`) | 65536 (32 MB) | `mmcblk0p23` | **the bootloader loads this** |
| `RECOVERY` | 24 (`0x18`) | 65536 (32 MB) | `mmcblk0p24` | inert for booting |
| `SYSTEM` | 47 (`0x47`) | — | `mmcblk0p47` | 2.39 GB |
| `VENDOR` | 48 (`0x48`) | — | `mmcblk0p48` | unused by this ROM |
| `ODM` | 49 (`0x49`) | — | `mmcblk0p49` | |
| `CACHE` | 50 (`0x4A`) | — | `mmcblk0p50` | |
| `USERDATA` | 53 (`0x35`) | — | `mmcblk0p53` | this is `data` |
| `PERSIST` | 31 (`0x1F`) | — | — | FRP lives here |
| `BACKUP` | 28 | — | — | 6 MB — **too small for TWRP** |
| `BOTA` | 26 (`0x1A`) | — | `mmcblk0p26` | Samsung bootloader state strings |
| `MISC` | 33 (`0x21`) | — | `mmcblk0p33` | boot request |
| `CONFIG` | — | — | — | `ro.frp.pst` |
| `FOTA` | 27 | — | — | |
| — | — | — | — | **no `vbmeta` partition** |

Block device paths seen inside recovery:

```
/dev/block/platform/soc/7824900.sdhci/by-name/
/dev/block/mmcblk0pNN
```

The `persistent` FRP path specifically:
`/dev/block/platform/soc/7824900.sdhci/by-name/persistent` — TWRP's own `recovery.fstab`
labels it `# Google FRP solution`.

---

## 9.5 The ROM

```
file:       lineage-19.1-20231011-UNOFFICIAL-j4primelte.zip
size:       619,370,620 bytes
pre-device: j4primelte
sdk:        32 (Android 12L)
build:      samsung/j4primeltedx/j4primelte:9/PPR1.180610.011/J415FXXU2BSDM
post-build: eng.gabrie.20231011.223248
```

On-device `build.prop` after install:

```
ro.product.cpu.abi=armeabi-v7a      <- 32-bit ARM, NOT arm64
ro.zygote=zygote32
ro.build.version.sdk=32
ro.build.type=userdebug
ro.build.fingerprint=samsung/j4primeltedx/j4primelte:9/PPR1.180610.011/J415FXXU2BSDM:user/release-keys
```

**The `msm8953_64` string in `fstab.qcom` is a device-tree copy-paste artifact and does
not describe the architecture.** Read `build.prop`.

---

## 9.6 Checksums

| File | Hash | Value |
|---|---|---|
| `twrp-3.7.0_j4primelte.img` | sha256 | `7dabdee3b26dd5781593690f61a927630d14e3fd61233c2894666029ee518632` |
| `twrp-3.7.0_j4primelte.img` | md5 | `0be9a3683a81fc8d255953e94bb77ae9` |
| ROM `boot.img` | md5 | `8dbc48b893e4f52c42579ad6f870dadc` |
| `RMM_Bypass_v3_corsicanu.zip` | md5 | `056eeebb2d6c59bc8d975f0ba2349eb2` |
| `RMM_Bypass_v3_corsicanu.zip` | sha256 | `42ec18878d336a7b0927bb87251bb548e020d4faa052679abe2ae0402b643bfc` |
| `MindTheGapps-12.1.0-arm-20231025_200802.zip` | size | `228,186,029` bytes (must match the release exactly) |

---

## 9.7 File sizes

| File | Size |
|---|---|
| `twrp-3.7.0_j4primelte.img` | 27,510,784 B |
| ROM `boot.img` | 13,107,200 B |
| ROM `recovery.img` (from the zip) | 21,053,440 B |
| Stock `boot.img` (from firmware) | 14,729,744 B |
| Stock `recovery.img` (from firmware) | 19,046,928 B |
| Stock firmware package | 2,675,118,600 B |
| TWRP kernel (extracted) | 12,382,949 B |
| TWRP ramdisk (extracted, gzip) | 15,124,136 B, page size 2048 |

---

## 9.8 Recovery paths, ranked by speed

| From | To | Command |
|---|---|---|
| Running Android | Download mode | `adb reboot download` |
| Running Android | TWRP | `adb reboot bootloader` → flash TWRP to BOOT+RECOVERY |
| TWRP | Download mode | `adb reboot bootloader` |
| TWRP | System | `Reboot → System` (TWRP clears the boot request correctly) |
| Any recovery | Download mode | `adb reboot bootloader` |
| Nowhere | Hard reset | Volume Down + Power, ~7–10 s |

---

## 9.9 Environment used for the original session

| | |
|---|---|
| Mac | MacBook Pro, Mac15,6, Apple M3 Pro, macOS Darwin 27.0.0 arm64 |
| Homebrew | 7.0.11 at `/opt/homebrew/bin/brew` |
| ADB | `~/Library/Android/sdk/platform-tools/adb` (1.0.41 / 36.0.0) |
| Rust | via rustup at `~/.cargo/bin` (cargo 1.99.1) |
| Tools | `brotli`, `lz4`, `timeout`, `mavis-trash` |
| USB | direct USB‑A port — **not** a hub |

### USB topology (useful if enumeration misbehaves)

- `AppleT8122USBXHCI@01000000` — USB‑A ports
- `AppleT8122USBXHCI@00000000` — USB‑C / Thunderbolt, carries a GenesysLogic USB 2.1 hub
  with the LAN dongle, camera, microphone and other peripherals
- `AppleT8122USBXHCI@02000000` — the controller the phone sat on (`MSM8953@02100000`)

The hub's LAN dongle port logged `hardware connection lost` repeatedly. Keep the phone
on a direct USB‑A port.

---

## 9.10 Sources

| Topic | Link |
|---|---|
| LineageOS GApps matrix | <https://wiki.lineageos.org/gapps/> |
| LineageOS FAQ | <https://wiki.lineageos.org/faq/> |
| LineageOS wiki device list (no `j4primelte`) | <https://wiki.lineageos.org/devices/> |
| TWRP device page | <https://twrp.me/samsung/samsunggalaxyj4plus.html> |
| TWRP Europe mirror | <https://eu.dl.twrp.me/j4primelte/> |
| samloader-rs | <https://github.com/topjohnwu/samloader-rs> |
| `wipe-frp.sh` | <https://github.com/LineageOS/android_vendor_lineage/blob/master/prebuilt/common/bin/wipe-frp.sh> |
| MindTheGapps 12.1.0 ARM | <https://github.com/MindTheGapps/12.1.0-arm/releases/latest> |
| J4+ TWRP / recovery thread (XDA) | <https://xdaforums.com/t/recovery-root-twrp-3-3-1-1-galaxy-j4-j415f-fn-g-ds.3876876/> |
| LOS 19.1 j4primelte thread (XDA, closed) | <https://xdaforums.com/t/unofficial-12-1-lineageos-19-1-for-galaxy-j4-j4primelte.4517067/> |
| Current build line (XDA) | <https://xdaforums.com/t/revive-os-j4-plus-unofficial-nov-2026.4766304/> |
| KG / RMM background | <https://community.e.foundation/t/know-your-hardware-samsung/28639/> |

---

Back to [`README.md`](../README.md) · [`QUICKSTART.md`](../QUICKSTART.md)
