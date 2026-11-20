# 06 — First boot, verification, and getting out of trouble

This is the stage where the flash is done and the remaining work is proving it. It is
also where one genuinely confusing failure mode lives — the **recovery loop** — so
read section 6.3 before you reboot.

---

## 6.1 Before the first boot

Three things to set up while you still have a working recovery:

### Seed the ADB key

A data wipe removes `/data/misc/adb/adb_keys`, which is why the host starts asking for
authorisation again. Push your Mac's key in from TWRP **once**, and the host attaches
automatically on every future boot with no prompt.

```bash
adb push ~/.android/adbkey.pub /sdcard/mac_adbkey.pub
adb shell 'mkdir -p /data/misc/adb; cp /sdcard/mac_adbkey.pub /data/misc/adb/adb_keys; chown -R root:shell /data/misc/adb; chmod 0750 /data/misc/adb; chmod 0640 /data/misc/adb/adb_keys'
```

### Stage your fallbacks on the SD card

```bash
adb push romx/boot.img /sdcard/lineage-boot.img          # the LineageOS kernel
adb push RMM_Bypass_v3_corsicanu.zip /sdcard/             # optional
```

`/sdcard/lineage-boot.img` is your way out of the recovery loop. Stage it before you
need it.

### Understand what is about to happen

`BOOT` currently holds TWRP. The LineageOS system needs the ROM's own `boot.img` in
`BOOT`. There are two ways to do that, and the order matters:

| Option | How | Notes |
|---|---|---|
| **A — stay in TWRP** | Boot TWRP → `adb reboot bootloader` → samloader flash `--partition BOOT romx/boot.img` | This is what was done, and it worked. Requires one more Odin trip. |
| **B — sideload the ROM's boot.img** | `adb sideload` or push + flash from TWRP | Sideload is broken on this device's recoveries; use a file-based flash. |

Option A is the proven path. Take it.

---

## 6.2 The first boot

### Expect this

- **It is slow.** The first boot of a LineageOS build on this hardware took a while,
  and the USB gadget does not enumerate until Android's USB service starts. Two minutes
  with no USB device is normal; check again before panicking.
- **"An internal error has occurred"** may appear. The ROM maintainer states this is
  expected, because the `vendor` partition was built inside `system`. Dismiss it.
- **No face unlock** on these unofficial builds.
- The Play Store may take a while on first launch.

### Watch it

```bash
# from the Mac, in a loop
while true; do
  printf '%s  ' "$(date '+%H:%M:%S')"
  ioreg -p IOUSB -w0 2>/dev/null | grep -oE "(MSM8953|SAMSUNG_Android)@[0-9a-f]+" | head -1
  sleep 5
done
```

A healthy first boot shows the phone re‑enumerating as `SAMSUNG_Android`
(`0x04E8:0x6860`) and `adb devices` showing an **authorised** device.

### Verify

```bash
adb shell getprop ro.product.device        # j4primelte
adb shell getprop ro.build.version.sdk     # 32
adb shell getprop ro.product.cpu.abi       # armeabi-v7a
adb shell getprop ro.build.type            # userdebug
adb shell pm list packages | grep -i velvet # com.android.vending present?
```

Successful verification from the original session:

```
ro.product.cpu.abi=armeabi-v7a
ro.zygote=zygote32
ro.build.version.sdk=32
ro.build.type=userdebug
```

---

## 6.3 The recovery loop — and why it happens

**Symptom:** the phone boots into the **LineageOS recovery** instead of the system. Every
time. And the recovery's "Reboot system now" button just goes back to the recovery.

**Cause — and it is a genuine bug in the ROM's recovery, not your mistake:**

The LineageOS recovery creates only this path:

```
/dev/block/platform/soc/7824900.sdhci/by-name/
```

but the bootloader writes the "boot now" request to:

```
/dev/block/bootdevice/by-name/misc
```

So the recovery can never find the request it needs to clear, and the bootloader keeps
launching recovery. The kernel log says exactly this:

```
E:Failed to clear BOB message: failed to open /dev/block/bootdevice/by-name/misc
init: reboot-bootloader: Error writing bootloader_message: failed to stat /dev/block/bootdevice/by-name/misc try 1..10
```

**TWRP does create `/dev/block/bootdevice/by-name/`** — so TWRP can always clear the
request and boot the system. That is why TWRP is the escape hatch.

### Diagnosing it properly before you panic

Two checks distinguish "the recovery can't boot" from "the system never even tried":

```bash
# 1. the kernel log from the last boot
adb pull /sys/fs/pstore/console-ramoops pstore-console.log
grep -E "zygote|system_server|boot_completed|apexd" pstore-console.log
```

If there are **zero** hits for `zygote`, `system_server`, `boot_completed` and `apexd`,
the system never attempted to boot — the problem is upstream of the system, not inside
it.

```bash
# 2. is there a stale boot request on disk?
adb shell 'dd if=/dev/block/by-name/misc bs=1M count=1 2>/dev/null | xxd | head -5'
```

All zeros means no stale request — again, the problem is not the system.

Samsung's own bootloader state strings live in the `bota` partition
(`mmcblk0p26`): `HALT: reboot into dload mode...`, `recovery`.

> In the original session these two checks were run *before* concluding the GApps
> install had broken the system. They proved it had not: the system had never tried to
> boot. Without them, the natural conclusion — "installing Google apps bricked it" —
> would have sent the process down the wrong path for hours.

### The fix

Restore the LineageOS kernel to `BOOT`, replacing TWRP:

```bash
# 1. get into download mode from the recovery
adb reboot bootloader
# (the Mac should now see MSM8953)

# 2. flash the ROM's boot.img into BOOT
cd ~/Desktop/j4-flash
./samloader-longtimeout flash --partition BOOT romx/boot.img --no-reboot --verbose > flash-boot.log 2>&1
```

Verified result: `rc=0`, and the phone then booted straight into LineageOS.

> The Odin `CloseConnection` "reboot to recovery" opcode (value 3) is **not honoured**
> by this bootloader — no ACK, the device stays in download mode. Use `adb reboot
> bootloader` and let the flash command end the session.

### Alternative: boot system from TWRP

TWRP can clear the boot request and boot the system directly:

```bash
adb reboot bootloader     # -> download mode
# flash TWRP to BOOT + RECOVERY again
./samloader-longtimeout flash \
    --partition BOOT     twrp-3.7.0_j4primelte.img \
    --partition RECOVERY twrp-3.7.0_j4primelte.img \
    --no-reboot --verbose
# boot TWRP, then: Reboot -> System
```

Either route works. The first is fewer steps.

---

## 6.4 Recovery cheat sheet

| Situation | What to do |
|---|---|
| Phone boots LineageOS recovery | Restore `romx/boot.img` to BOOT via samloader (§6.3), or boot system from TWRP |
| Phone boots TWRP | You are in control. `adb reboot bootloader` → download mode → flash whatever you need |
| Phone boots nothing | Hold **Volume Down + Power** ~7 s for a hard reset, then `adb reboot download` and flash |
| Phone boots stock Android | **Stop.** You have re-locked it. See the warning below |
| ADB says `unauthorized` | The data wipe removed the key. Re-seed it from TWRP (§6.1) |
| ADB says `device` but nothing works | The recovery's `adbd` may be in a restricted state — try `adb kill-server && adb start-server` |

> ### ⚠️ Never boot back into stock
> A stock boot can restore the stock recovery, re‑lock the bootloader and reset the KG
> state — putting you back at step 2 of this guide. If you end up there by accident,
> expect to redo stages 2 through 4.

---

## 6.5 Final checklist

- [ ] Phone boots into LineageOS (not recovery, not TWRP, not stock)
- [ ] `ro.build.version.sdk` = 32
- [ ] `ro.product.cpu.abi` = `armeabi-v7a`
- [ ] Google Play Store present (`com.android.vending`)
- [ ] ADB authorised without a prompt (the key was seeded)
- [ ] `BOOT` holds the LineageOS `boot.img`, **not** TWRP
- [ ] `RECOVERY` still holds TWRP — **keep it there as your safety net**
- [ ] Wi‑Fi joined
- [ ] FRP cleared if it was locked
- [ ] You know how to get back to download mode: `adb reboot download`

---

### A note on the two commands that were wrong during this session

Two claims made during the work were later corrected, and both are worth recording
because they would have sent anyone following along down a wrong path:

1. **"The ROM is ARM64."** It is **32‑bit ARM**. The `msm8953_64` string in
   `fstab.qcom` is a device‑tree copy‑paste artifact. This matters enormously for
   choosing the GApps package.
2. **"The RMM bypass removed a `libvkjson.so` copy."** There was only ever one copy,
   in `system/lib`, and it survived. The ROM install overwrote it, which is what
   actually changed.

Both were found by checking the device rather than reasoning from the symptoms.

---

Next: [`07-troubleshooting.md`](07-troubleshooting.md) — the complete failure catalogue.
