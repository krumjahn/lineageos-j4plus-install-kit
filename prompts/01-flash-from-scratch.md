# 01 — Flash from scratch

> **Paste everything below into the agent**, after pasting `agent-brief.md`.

---

I want you to help me install **LineageOS 19.1** on my **Samsung Galaxy J4+**
(`SM-J415GN`, `j4primelte`) from macOS using `samloader`. The agent brief I just
pasted has the device facts, the protocol rules and the checksums — treat it as the
source of truth and do not contradict it.

The phone is currently on **stock Android** with **USB debugging enabled** and the
cable connected.

**Work through the stages below with me, one at a time.** Do not run ahead. After each
stage, verify the result and show me the output before moving on.

---

## Stage 0 — Confirm the starting point

Before doing anything else:

1. Check that `adb devices` shows my phone **authorised** (not `unauthorized`).
2. Read the device's identity:

```bash
adb shell getprop ro.product.device
adb shell getprop ro.build.version.release
adb shell getprop ro.product.cpu.abi
```

3. Tell me what you found and whether anything about it is a problem. **My phone may
   have a forgotten screen lock** — if the setup is complete and ADB is authorised, say
   so; if ADB needs authorisation, tell me to tick **"Always allow from this computer"**
   (not just OK).

Then tell me which stage I need, based on this:

- If the Odin screen will show `OEM LOCK: OFF` **and** no `KG STATUS:` line →
  **Stage 2** (skip Stage 1 entirely).
- If it shows `KG STATUS: Prenormal` → **Stage 1** first, then Stage 2.
- If it shows `OEM LOCK: ON` → we need to unlock the bootloader first; work with me on
  that before Stage 1.

**Do not enter download mode yet.** Ask me first.

---

## Stage 1 — Clear KG Prenormal (only if the Odin screen says so)

1. **The phone needs internet on Wi‑Fi.** Check and confirm:

```bash
adb shell ping -c 2 8.8.8.8
adb shell ping -c 2 google.com
```

If either fails, **stop and tell me to join Wi‑Fi on the phone by hand** — the shell
cannot add a network on this Android 9 build. Do not try to work around it.

2. **Probe the TLS floor before committing to a date.** Write a script that, for each
   candidate date (today minus 7, 8, 9, 10, 11, 12 days), sets the clock, then attempts
   an HTTPS request from the device, and reports which dates complete the handshake.
   Log the results to a file and show me the table.

   Expect exactly one working band: far enough back to satisfy "more than 7 days",
   but not so far that the certificate is "not yet valid". **Use the smallest
   backdate inside that band.** If the probe finds no working band, stop and tell me —
   do not guess.

3. **Run the sequence** with the date the probe chose:

```
internet off → set clock (auto_time=0, cmd alarm set-time) → reboot
→ internet on → software update check → reboot
→ clock restored → internet on → second check → reboot
```

   Use `adb shell svc wifi enable` / `svc wifi disable` to toggle the radio. Open the
   update page with `adb shell am start -a android.settings.SYSTEM_UPDATE_SETTINGS`
   and drive the **"Check for update" button** — not the summary line. If you need to
   find the button on screen, use the scorer in `scripts/adb-ui.py` (copy it into the
   working directory and adapt it). **When the update offers an actual firmware
   update, choose LATER — do not install it.**

4. **Verify with the marker, not with the exit code.** The success line must read
   `Last successful check for update at HH:MM`. A line reading `... on <a date>` is a
   stale check and does not count.

5. Confirm the state changed: Developer options shows **"OEM unlocking: Bootloader
   already unlocked"**, and the Odin screen shows `KG STATUS: Checking` or no KG line.

**Show me the evidence for each of these before continuing.**

---

## Stage 2 — Flash TWRP

1. Put the phone in download mode. Prefer `adb reboot download` over the buttons.
   Verify with `ioreg` that it enumerates as `MSM8953`.

2. Confirm the TWRP image is present and its **sha256** matches the brief. If the file
   is missing, tell me the URL and the checksum before you download anything.

3. **The flash must be the first device command of this session.** No `samloader
   detect`, no `dump-pit` first. Use `ioreg` for any detection.

```bash
./samloader-longtimeout flash \
    --partition BOOT     twrp-3.7.0_j4primelte.img \
    --partition RECOVERY twrp-3.7.0_j4primelte.img \
    --no-reboot --verbose > twrp-flash.log 2>&1
```

Log to the file. Then read the log and quote me the handshake, session, PIT,
partition-resolve and write lines, and the final status.

4. **If it ends in `FAIL! Auth`:** stop. That is the bootloader lock or KG, not a
   transfer problem. Tell me what the Odin screen says now.

5. Boot into TWRP and tell me what is on screen — specifically the TWRP version
   banner. If it says *"Android Recovery (user) v3.0"* or *"Black Screen v0.4"*, then
   TWRP is not in `BOOT` and we have a problem to work out.

6. Once TWRP is confirmed up, seed my ADB public key into `/data/misc/adb/adb_keys`
   so I stop getting authorisation prompts, and confirm `adb devices` shows the phone.

---

## Stage 3 — Format data and install the ROM

1. **Stop and ask me before formatting `data`.** Give me the exact command. I will
   run it, or I will say yes to you running it.

2. Then, in TWRP:

```bash
adb shell "twrp format data"
```

3. Push and install the ROM:

```bash
adb push <rom.zip> /sdcard/j4/
adb shell "twrp install /sdcard/j4/<rom.zip>"
```

This takes several minutes. Watch `/tmp/recovery.log` and tell me the final result
code and the bytes written.

4. Verify the install by reading `/system/build.prop` and confirm:
   `ro.build.version.sdk=32`, `ro.product.cpu.abi=armeabi-v7a`.

5. **Do not install `no-verity-opt-encrypt`** — there is no vbmeta partition on this
   device and it fails anyway.

---

## Stage 4 — Install Google apps

1. Choose the package based on what Stage 3 verified: **MindTheGapps 12.1.0 ARM**
   (`MindTheGapps-12.1.0-arm-20231025_200802.zip`, 228,186,029 bytes). Confirm the
   size matches. If Stage 3 showed a different Android version, tell me and we will
   work out the right package from the LineageOS GApps matrix.

2. Install it by running MindTheGapps' own `update-binary` from a root recovery shell
   — it is written for exactly this layout (system inside the system partition,
   `product` and `system_ext` as symlinks):

```bash
adb push <extracted>/update-binary /data/update-binary
adb push MindTheGapps-12.1.0-arm-20231025_200802.zip /data/mtg.zip
adb shell "sh /data/update-binary /data 1 /data/mtg.zip"
```

3. Verify: `product/priv-app/Velvet/Velvet.apk` (Play Store),
   `product/priv-app/GmsCore/GmsCore.apk`, the `privapp-permissions-google-*.xml`
   files, and `addon.d/30-gapps.sh` all exist, owned `root:root`, mode `0644`.

4. Confirm the system partition had **at least ~500 MB free** before installing —
   MindTheGapps strips the Play Store if it does not.

---

## Stage 5 — Restore the LineageOS kernel and boot

`BOOT` currently holds TWRP. The system needs the ROM's `boot.img`.

1. **Stop and confirm with me**, then push the fallback files to the SD card first:
   `romx/boot.img` as `/sdcard/lineage-boot.img`, plus the TWRP image.

2. Get to download mode (`adb reboot bootloader` from TWRP) and flash the LineageOS
   kernel into `BOOT`:

```bash
./samloader-longtimeout flash --partition BOOT romx/boot.img --no-reboot --verbose > flash-boot.log 2>&1
```

3. Let it reboot and watch for USB enumeration. A slow first boot with no USB device
   for a couple of minutes is normal.

4. **If it boots into the LineageOS recovery instead of the system:** do **not** blame
   the ROM or the GApps. Run the pstore check first:

```bash
adb pull /sys/fs/pstore/console-ramoops pstore-console.log
grep -E "zygote|system_server|boot_completed|apexd" pstore-console.log
```

   Zero hits means the system never tried to boot. Then show me the recovery's own
   error about `/dev/block/bootdevice/by-name/misc` and we will restore `boot.img`
   again or boot system from TWRP.

5. **Verify the final state** and report it to me:

```bash
adb shell getprop ro.build.version.sdk
adb shell getprop ro.product.cpu.abi
adb shell pm list packages | grep -i velvet
```

Tell me plainly whether the phone is now running LineageOS 19.1 with Google apps, and
whether `BOOT` holds the LineageOS kernel while `RECOVERY` still holds TWRP.

---

## Throughout

- One stage at a time. Verify, then report, then continue.
- **Never boot the phone into stock.** If it lands there, stop and tell me.
- Log device output to files; never pipe it into `head`.
- If you hit something not covered by the brief, **say so and show me the output**
  rather than trying a sequence of workarounds.
