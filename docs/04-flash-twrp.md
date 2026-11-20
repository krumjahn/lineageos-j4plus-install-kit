# 04 — Flashing TWRP

This is where it stops being theory. Two things about this device make the TWRP flash
unusual, and both were discovered the hard way.

---

## 4.1 The rule that breaks everything else

**Samsung grants one protocol session per entry into download mode.**

The Loke daemon on the device will accept a single command sequence per download‑mode
entry. If you run a second command without leaving and re‑entering download mode, the
handshake fails with something like:

```
Failed to receive handshake response: Transfer timed out
```

This looks exactly like a broken cable, a dead phone, or a bad USB port. It is not. In
the original session this produced hours of phantom "the phone is wedged" symptoms
before the real cause was found — **the tool's own default reboot** was taking the
phone out of download mode and burning the session, and then the next command was
fighting a session that no longer existed.

Practical rules:

1. **One command per download‑mode entry.** Flash TWRP, exit, re‑enter, flash
   something else.
2. **Always `--no-reboot`.** Without it samloader reboots the phone at the end of the
   flash — which both ends the session and, worse, can boot the phone into stock.
3. **Detect with `ioreg`, never with a device command.** `ioreg` cannot consume a
   session. `samloader detect` can.

```bash
# detect - never consumes the session
ioreg -p IOUSB -w0 2>/dev/null | grep -oE "(MSM8953|SAMSUNG_Android)@[0-9a-f]+[[:space:]]+<class IOUSBHostDevice, id 0x[0-9a-f]+" | head -1
```

---

## 4.2 The rule that breaks the flash itself

**The bootloader loads `BOOT`, not `RECOVERY`.**

On most Samsung devices, flashing a custom recovery to the `RECOVERY` partition is
enough. **It is not enough here.**

What happened in the original session:

1. TWRP was flashed to `RECOVERY` twice. Both flashes were *perfectly clean* — Odin
   acknowledged every block, samloader reported success, the return code was 0.
2. The phone was rebooted.
3. It booted **"Android Recovery (user) v3.0 / Black Screen v0.4"** — Samsung's stock
   recovery, which does not even enumerate over USB.

The flashes had worked. They just were not being loaded.

The fix was verified by extracting the ramdisk from the TWRP image and confirming it
contains `TeamWin` strings and **zero** hits for `Black Screen` or `Android Recovery`
— so the menu the user was looking at genuinely was Samsung's, not a TWRP that had
failed to boot.

**Flash TWRP to `BOOT` as well as `RECOVERY`.** With both written, the phone booted
straight into TWRP `3.7.0_9-kycii91`.

> A later subtlety, discovered much further on: `adb reboot recovery` on this device
> boots the **ROM's own embedded recovery** (the Android 12 generic ramdisk inside the
> ROM's `boot.img`), not whatever is in the `RECOVERY` partition. So the `RECOVERY`
> partition is inert in two different ways. TWRP in `BOOT` is what gives you a usable
> recovery.

---

## 4.3 The flash

### Before you start

- The phone is in download mode and enumerating as `MSM8953`.
- The bootloader is unlocked (`OEM LOCK: OFF`).
- KG is not Prenormal.
- `twrp-3.7.0_j4primelte.img` checksum verified.
- You have read section 4.1.

### Enter download mode

```bash
adb reboot download        # from Android or from a recovery
```

or **Volume Up + Volume Down + Power**, then **Volume Up** on the warning screen.

Verify, then wait a few seconds for the session to settle:

```bash
ioreg -p IOUSB -w0 2>/dev/null | grep -oE "MSM8953@[0-9a-f]+" | head -1
```

### Flash

**This must be the first device command of the session.**

```bash
cd ~/Desktop/j4-flash
./samloader-longtimeout flash \
    --partition BOOT     twrp-3.7.0_j4primelte.img \
    --partition RECOVERY twrp-3.7.0_j4primelte.img \
    --verbose 2>&1 | tee twrp-flash.log
```

Two partitions in one session — that is allowed, and it is what worked. Two *separate
invocations* in one session is not.

What a healthy run looks like:

```
... handshake OK (LOKE received)
... session begun
... PIT read
... partition_id 0x17 (BOOT)
... 27 data chunks transmitted
... partition_id 0x18 (RECOVERY)
... 27 data chunks transmitted
... session closed
```

### If you get `FAIL! Auth`

The transfer completed and the bootloader refused the image. This is not a transfer
problem — go back to [`02-diagnose-the-blockers.md`](02-diagnose-the-blockers.md):
it is `OEM LOCK: ON` or `KG STATUS: Prenormal`.

### If the handshake times out

```
Failed to receive handshake response: Transfer timed out
```

Usually one of:

- You already used the session. Leave and re‑enter download mode.
- Stock samloader with a 1‑second timeout. Use the patched build.
- The phone is not actually in download mode. Check `ioreg`.
- A hub or dock is in the way. Plug into a USB‑A port directly.
- A data-less USB cable.

### Never pipe this into `head`

```bash
# WRONG - SIGPIPE kills samloader mid-handshake and corrupts the session
./samloader-longtimeout flash ... | head -20

# RIGHT - log to a file, then read the file
./samloader-longtimeout flash ... > twrp-flash.log 2>&1
```

---

## 4.4 Boot into TWRP

```bash
# if ADB is up (from a running Android or recovery)
adb reboot bootloader     # -> Samsung download mode
```

then flash TWRP again (as above) and reboot. Or use the buttons:

**Volume Up + Volume Down + Power**, release **Volume Down** when the screen goes off,
keep **Volume Up + Power**.

You should land on the TWRP main screen — the teal/grey one with the big orange
`Reboot` / `Wipe` / `Mount` / `Backup` buttons. The title bar should read
`TWRP 3.7.0_9-kycii91` and the device `j4primelte`.

> If you land on Samsung's **"Android Recovery (user) v3.0 / Black Screen v0.4"**, then
> TWRP was not in `BOOT`. Go back to section 4.2.

### ADB in TWRP

```bash
adb devices
# TWRP shows up as 0x18D1:0x4EE2
```

If it shows `unauthorized`, the data wipe removed `/data/misc/adb/adb_keys`. Fix from
TWRP (which has root):

```bash
adb shell 'mkdir -p /data/misc/adb; cp /sdcard/mac_adbkey.pub /data/misc/adb/adb_keys; chown -R root:shell /data/misc/adb; chmod 0750 /data/misc/adb; chmod 0640 /data/misc/adb/adb_keys'
```

Push your Mac's public key there first:

```bash
adb push ~/.android/adbkey.pub /sdcard/mac_adbkey.pub
```

This is worth doing every time you format data — it means the host attaches
automatically on every subsequent boot with no prompt.

---

## 4.5 If TWRP is installed, do not go back to stock

**Once TWRP is in `BOOT`, never boot the phone back into stock Android.**

A stock boot can restore the stock recovery, re‑lock the bootloader, and reset the KG
state. It also destroys any progress. If you need a stock system for some reason, read
this guide first and accept that you may have to redo stages 2 through 4.

This is the single rule in this document with the most expensive consequences.

---

Next: [`05-install-lineageos-and-gapps.md`](05-install-lineageos-and-gapps.md)
