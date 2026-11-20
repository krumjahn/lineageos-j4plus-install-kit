# 05 — Installing LineageOS and Google apps

Everything from here happens inside TWRP, over ADB, with the phone in recovery.

---

## 5.1 Format `data`

```bash
adb shell "twrp format data"
```

Verified result: `/dev/block/mmcblk0p53` on `/data`, 25 GB, ext4, **no encryption**.

The `twrp` CLI only exists in TWRP. The LineageOS recovery has no `twrp` binary
(`/system/bin/sh: twrp: inaccessible or not found`).

> In the original session the final format was done through the TWRP **GUI** —
> `Factory reset → Format data/factory reset → Yes` — because Android's own
> `erase_volume()` is more correct than a shell format and it avoids any risk of
> formatting the wrong thing. It is also the one irreversible step where a human
> confirming the action is worth the ten seconds it costs.

### Do not use `no-verity-opt-encrypt`

You will see it recommended everywhere. On this device it is **not needed**, and it
does not work anyway:

- There is **no `vbmeta` partition** on this device (confirmed from the PIT). There is
  no verified boot chain to disable.
- The zip fails with `Updater process ended with ERROR: 1` and
  `/tmp/updater[63]: .: config.sh: No such file or directory`.
- This ROM ships the `vendor` partition inside `system`, so its `fstab.qcom` has no
  `/vendor` mount and the `02-no-dm-verity` / `01-no-force-encrypt` patches are moot.

---

## 5.2 Install the ROM

### Push it

`adb sideload` **does not work** here — on TWRP 3.7 it fails with
`sideload connection failed: closed` (the pre‑KitKat method also fails), and on the
LineageOS recovery it fails with `device unauthorized`. Use `adb push`:

```bash
adb shell mkdir -p /sdcard/j4
adb push lineage-19.1-20231011-UNOFFICIAL-j4primelte.zip /sdcard/j4/
```

A 619 MB push takes about 20 seconds over USB 2.

### Install it

```bash
adb shell "twrp install /sdcard/j4/lineage-19.1-20231011-UNOFFICIAL-j4primelte.zip"
```

Expect a multi‑minute run. Watch it:

```bash
adb shell tail -f /tmp/recovery.log
```

TWRP's log shows steady `writing 1024 blocks of new data`. A healthy completion:

```
-- Installation package complete, rebooting device
```

### Verify it landed

```bash
adb shell 'ls -l /system/bin/; cat /system/build.prop | grep -E "lineage_j4primelte|ro.build.version.sdk"'
```

Verified output on this device:

```
ro.product.cpu.abi=armeabi-v7a
ro.zygote=zygote32
ro.build.version.sdk=32
ro.build.type=userdebug
```

> **Note the architecture: 32‑bit ARM (`armeabi-v7a`), not ARM64.** During the original
> session this was briefly asserted as ARM64 and corrected. The `msm8953_64` string
> that appears in `fstab.qcom` is a device‑tree copy‑paste artifact and does **not**
> describe the architecture. The build.prop above is authoritative. This matters
> enormously for choosing the right Google apps package.

### The `/tmp` risk

TWRP's `/tmp` is tmpfs and on this device is about 899 MB, while the system partition
is 2.39 GB. The installer converts `system.new.dat.br` into a raw image, and that
conversion can need more space than `/tmp` has.

If the install dies partway through the system write, the fallback is to do the
conversion **on the Mac**:

```bash
brew install brotli
# decompress system.new.dat.br -> system.new.dat
# combine with system.transfer.list -> system.img
# push the 2.39 GB image, then write it to /dev/block/mmcblk0p47 from TWRP's shell
```

This did not need to be used — the install completed with `bytes_written_system:
1510322176` — but it is the known recovery path.

> ⚠️ A raw write over `/system` **wipes anything else you patched into it**, including
> the Google apps from section 5.3. If you use this fallback, install GApps afterwards.

---

## 5.3 Install Google apps

### Which package

**MindTheGapps 12.1.0 ARM.**

- The ROM is Android 12L / SDK 32 / `armeabi-v7a`.
- LineageOS 19.1 maps to **MindTheGapps 12.1.0**; **13.0.0 is for LineageOS 20 /
  Android 13** and will not work.
- **ARM, not ARM64** — this ROM is 32‑bit.

Download: <https://github.com/MindTheGapps/12.1.0-arm/releases/latest>

```
MindTheGapps-12.1.0-arm-20231025_200802.zip   228,186,029 bytes
```

That size must match the release metadata exactly. The inner `build.prop` should say
`arch=armv7l`, `version=32`, `version_nice=12.1.0`.

The LineageOS wiki is explicit that GApps must be installed **via recovery
immediately after installing LineageOS**, and that `/data` must be formatted first.
Both are done.

### The method

Two ways. The one that worked here, and why.

**Recommended — run MindTheGapps' own `update-binary` from a root recovery shell.**
The script is written for exactly this layout: it looks for `system` inside the system
partition and treats `product` and `system_ext` as symlinks. That matches this ROM.

```bash
# extract the installer from the zip
unzip -o MindTheGapps-12.1.0-arm-20231025_200802.zip 'META-INF/com/google/android/update-binary' -d mtg
# (the path inside the zip may be 'update-binary' at the root - check with: unzip -l)

adb push mtg/update-binary /data/update-binary
adb push MindTheGapps-12.1.0-arm-20231025_200802.zip /data/mtg.zip
adb shell "sh /data/update-binary /data 1 /data/mtg.zip"
```

**Alternative — install the zip from the TWRP GUI** (Install → pick the zip). This is
the normal path and it works, but it requires the phone's screen and the user. The
`update-binary` route is scriptable, which is what made it possible to finish the whole
session unattended.

> The **LineageOS recovery** can also do this, and in the original session it was used
> rather than reflashing TWRP into `BOOT` for the GApps step — reflowing `BOOT` to
> TWRP and back again is a needless extra trip through Odin.

### Verify

```bash
adb shell 'ls -l /system/product/priv-app/Velvet/Velvet.apk \
                /system/product/priv-app/GmsCore/GmsCore.apk \
                /system/system_ext/priv-app/GoogleServicesFramework/GoogleServicesFramework.apk'
adb shell 'ls /system/etc/permissions/privapp-permissions-google-product.xml \
           /system_ext/etc/permissions/privapp-permissions-google-system-ext.xml'
adb shell 'ls /system/addon.d/'
```

Verified on this device:

| Item | Path |
|---|---|
| Play Store | `product/priv-app/Velvet/Velvet.apk` (228 MB) |
| Google Play Services | `product/priv-app/GmsCore/GmsCore.apk` (99 MB) |
| Google Setup Wizard | `system_ext/priv-app/SetupWizard/SetupWizard.apk` |
| Google Services Framework | `system_ext/priv-app/GoogleServicesFramework/` |
| Permissions | `product/etc/permissions/privapp-permissions-google-product.xml` |
| Boot script | `addon.d/30-gapps.sh` (2,261 B) |

All files `root:root`, mode `0644`, SELinux context `u:object_r:system_file:s0`.

> The system partition had **892 MB free** against roughly 500 MB needed, so
> MindTheGapps' `remove_big_optional_apps` path — which strips Velvet, the Play Store —
> never ran. If you see no Play Store after installing, that is almost certainly why:
> you were short on space.

---

## 5.4 RMM bypass

`RMM_Bypass_v3_corsicanu.zip` was installed in the original session, but it turned out
to be **unnecessary** for this ROM and **moot** after the ROM install overwrote it.

Why: there is no `vaultkeeper`, no `Rlc` and no `KnoxGuard` anywhere in a LineageOS
build. The patch has nothing to patch.

If you are following the community procedure anyway, install it **after** the ROM, not
before — both helper zips patch `/system`, and the ROM install overwrites `/system`.
Installing it first, as happened in the original session, means it is gone by the time
the ROM finishes.

---

## 5.5 Clear FRP if needed

If the Odin screen showed `FRP LOCK: ON`, or the setup wizard asks for a Google account
you do not have:

> **This is for a phone you own.** Clearing the activation lock on your own device
> because you forgot the account is routine. Clearing it on a phone you did not buy,
> in order to resell it, is a different activity — and a criminal one in many
> countries. Do not use this section for that.

```bash
# the official LineageOS script
adb push wipe-frp.sh /data/local/tmp/wipe-frp.sh
adb shell "chmod 0755 /data/local/tmp/wipe-frp.sh"
adb shell "/data/local/tmp/wipe-frp.sh"
```

It runs against the `persistent` and `config` partitions. TWRP's own `recovery.fstab`
labels `/dev/block/platform/soc/7824900.sdhci/by-name/persistent` as
`# Google FRP solution`.

Source: <https://github.com/LineageOS/android_vendor_lineage/blob/master/prebuilt/common/bin/wipe-frp.sh>

> In the original session FRP was cleared the other way — the user signed in with an
> existing Google account during the stock setup wizard. The `wipe-frp.sh` route exists
> so that **no spare Google account is needed**, which is the cleaner path for anyone
> starting fresh.

---

Next: [`06-verify-first-boot-and-recovery.md`](06-verify-first-boot-and-recovery.md)
