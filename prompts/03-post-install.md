# 03 — Post-install: Google apps, FRP, and recovery

> **Paste everything below into the agent**, after pasting `agent-brief.md`.
> Use this when LineageOS is already installed and you are handling the tail end.

---

LineageOS 19.1 is on my **Samsung Galaxy J4+** (`SM-J415GN`, `j4primelte`). The agent
brief I just pasted has the device facts, the partition map, the protocol rules and the
checksums — treat it as the source of truth.

Depending on what I need, we will be doing one or more of:

- installing Google apps
- clearing FRP
- fixing a boot that lands in recovery instead of the system
- verifying the install and re-seeding my ADB key

**Work one task at a time. Verify before you continue, and show me the output.**

---

## Task A — Install Google apps

### A1 — Confirm the platform first

```bash
adb shell getprop ro.build.version.sdk
adb shell getprop ro.product.cpu.abi
adb shell getprop ro.build.type
```

Report these. The package choice depends on them:

| SDK / version | Architecture | Package |
|---|---|---|
| 32 (Android 12L) / LineageOS 19.1 | `armeabi-v7a` | **MindTheGapps 12.1.0 ARM** |
| 33 (Android 13) / LineageOS 20 | `armeabi-v7a` | MindTheGapps 13.0.0 ARM |

If the architecture is `arm64-v8a`, my device is **not** the one this kit describes —
**stop and tell me**.

### A2 — Check the space first

```bash
adb shell df -h /system
```

MindTheGapps needs roughly **500 MB free** in the system partition. If there is less,
**it will silently strip the Play Store** (`remove_big_optional_apps` removes Velvet).
Tell me before installing if space is tight.

### A3 — Install

The LineageOS recovery's installer is the right tool, because MindTheGapps' own
`update-binary` is written for exactly this layout — `system` inside the system
partition, `product` and `system_ext` as symlinks.

```bash
# extract the installer from the zip (check the internal path with unzip -l first)
unzip -o MindTheGapps-12.1.0-arm-20231025_200802.zip 'META-INF/com/google/android/update-binary' -d mtg

adb push mtg/update-binary /data/update-binary
adb push MindTheGapps-12.1.0-arm-20231025_200802.zip /data/mtg.zip
adb shell "sh /data/update-binary /data 1 /data/mtg.zip"
```

Note: the file is 228,186,029 bytes. Verify that.

### A4 — Verify

```bash
adb shell 'ls -l /system/product/priv-app/Velvet/Velvet.apk \
                /system/product/priv-app/GmsCore/GmsCore.apk \
                /system/system_ext/priv-app/GoogleServicesFramework/GoogleServicesFramework.apk'
adb shell 'ls /system/product/etc/permissions/privapp-permissions-google-product.xml \
           /system/system_ext/etc/permissions/privapp-permissions-google-system-ext.xml'
adb shell 'ls /system/addon.d/'
```

Expect: `Velvet.apk` (~228 MB), `GmsCore.apk` (~99 MB), the two permission XMLs, and
`30-gapps.sh` (~2.2 KB). All `root:root`, mode `0644`, context
`u:object_r:system_file:s0`.

**If the Play Store is missing but the other apps are present, the space check in A2
is the reason.**

---

## Task B — Clear FRP

### B1 — Is it actually FRP?

`FRP LOCK: ON` on the Odin screen, or a setup wizard demanding a Google account, or
*"VERIFICATION FAILED"* at setup.

### B2 — Get a root shell

FRP clearing needs root. TWRP has it. The LineageOS recovery does not have the `twrp`
CLI, but it does have a root shell — if `adb shell` is `unauthorized` there, seed my
ADB key first (Task D).

### B3 — Use LineageOS' own script

`wipe-frp.sh` lives at `prebuilt/common/bin/wipe-frp.sh` in
`LineageOS/android_vendor_lineage`:

<https://github.com/LineageOS/android_vendor_lineage/blob/master/prebuilt/common/bin/wipe-frp.sh>

**Important:** it is only installed into recovery from 2025 onward and is **not present
on the `lineage-19.1` branch**, so push it manually:

```bash
curl -fsSL https://raw.githubusercontent.com/LineageOS/android_vendor_lineage/master/prebuilt/common/bin/wipe-frp.sh -o wipe-frp.sh
adb push wipe-frp.sh /data/local/tmp/wipe-frp.sh
adb shell "chmod 0755 /data/local/tmp/wipe-frp.sh"
adb shell "/data/local/tmp/wipe-frp.sh"
```

The script resolves its target from the **`ro.frp.pst`** property, which on Samsung is
the **`persistent`** partition. It accepts a partition override as its first argument
if I want to target something else.

If the raw URL 404s on the default branch, try the `lineage-24.0` branch explicitly —
and tell me which URL you used.

---

## Task C — The phone boots recovery instead of the system

**Get the evidence before touching anything.**

```bash
adb pull /sys/fs/pstore/console-ramoops pstore-console.log
grep -E "zygote|system_server|boot_completed|apexd" pstore-console.log
```

- **Zero hits** → the system never attempted to boot. The fault is upstream.
- **Hits** → the system did start and crashed. Different problem — show me the lines.

Then show me the recovery's own error. The known cause is that the LineageOS recovery
creates only `/dev/block/platform/soc/7824900.sdhci/by-name/` and never
`/dev/block/bootdevice/by-name/`, so it cannot clear the boot request the bootloader
wrote to `/dev/block/bootdevice/by-name/misc`:

```
E:Failed to clear BOB message: failed to open /dev/block/bootdevice/by-name/misc
init: reboot-bootloader: Error writing bootloader_message: failed to stat /dev/block/bootdevice/by-name/misc try 1..10
```

**Fix — restore the LineageOS kernel to `BOOT`:**

```bash
# stage the fallback first
adb push romx/boot.img /sdcard/lineage-boot.img

# to download mode, without buttons
adb reboot bootloader

# the flash must be the first device command of this session
./samloader-longtimeout flash --partition BOOT romx/boot.img --no-reboot --verbose > flash-boot.log 2>&1
```

**Alternative:** get TWRP into `BOOT` again and use `Reboot → System` from TWRP —
TWRP creates the `bootdevice/by-name` path and can always clear the request.

**Never let it boot stock.** If it lands in stock, stop and tell me.

---

## Task D — Re-seed the ADB key

After any `data` format, `/data/misc/adb/adb_keys` is gone and I get the authorisation
prompt again. From TWRP:

```bash
adb push ~/.android/adbkey.pub /sdcard/mac_adbkey.pub
adb shell 'mkdir -p /data/misc/adb; cp /sdcard/mac_adbkey.pub /data/misc/adb/adb_keys; chown -R root:shell /data/misc/adb; chmod 0750 /data/misc/adb; chmod 0640 /data/misc/adb/adb_keys'
```

Then confirm with `adb devices -l` after a reboot.

---

## Task E — Final verification

Run all of these and report the results plainly:

```bash
adb shell getprop ro.product.device
adb shell getprop ro.build.version.sdk
adb shell getprop ro.product.cpu.abi
adb shell getprop ro.build.type
adb shell pm list packages | grep -iE "velvet|gmscore"
adb devices -l
```

Then confirm the partition state: **`BOOT` holds the LineageOS `boot.img`**, and
**`RECOVERY` still holds TWRP** — TWRP in `RECOVERY` is my safety net and I want to
keep it there.

Finally, tell me plainly:

- Is the phone running LineageOS 19.1?
- Are Google apps present, including the Play Store?
- Is ADB authorised without a prompt?
- Is there anything you would do differently on the next run?
