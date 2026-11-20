# 07 — Troubleshooting: every mistake that actually happened

This is the catalogue from the original session. Every entry is a real failure with the
real error text, the real cause, and what fixed it.

Nothing here is theoretical. If it is in this document, it happened.

---

## A. Flashing and the Odin session

### A1 — `FAIL! Auth`

**What you see:** samloader transmits the entire image — handshake, session, PIT, every
chunk — and then the Odin screen says:

```
FAIL! Auth
Only officially released binaries are allowed to be flashed
```

**Cause:** the bootloader refused the image because it was not Samsung‑signed. Either
`OEM LOCK: ON`, or the device is in KG Prenormal.

**Not a transfer problem.** The flash mechanism is fully proven at this point. Do not
rebuild samloader, do not change cables, do not re‑try the same image.

**Fix:** read the Odin screen and follow branch B or C in
[`02-diagnose-the-blockers.md`](02-diagnose-the-blockers.md).

> This failed **four separate times** in the original session, all with a perfectly
> clean protocol run, all with the same cause.

### A2 — `Failed to receive handshake response: Transfer timed out`

**What you see:** samloader cannot even start. Reports a timeout during the handshake.

**Cause:** usually one of these, in order of likelihood:

1. **The session is already spent.** Samsung grants one protocol session per entry
   into download mode. Run `adb reboot download` again — a fresh entry, a fresh session.
2. **Stock samloader's 1‑second handshake timeout.** Use the patched build
   (`HANDSHAKE_TIMEOUT` 1 s → 15 s).
3. **The phone is not in download mode.** Check `ioreg` for `MSM8953`.
4. **A hub or dock is in the way.** Use a USB‑A port directly.
5. **A charge‑only cable.**

**Also observed:** both the `nusb` and `libusb` backends behave identically here — this
is not a backend‑specific problem.

### A3 — "The phone is wedged" / "the cable is broken"

**What you see:** the phone is unresponsive to every device tool. It has been like this
for an hour. You start suspecting the hardware.

**Cause:** **it was not the hardware.** The tool's own default reboot had been taking
the phone out of download mode and burning the session; every subsequent command was
then fighting a session that no longer existed, timing out, and being read as a dead
cable.

**Fix:** `adb reboot download` to get a fresh entry, then make the **first** device
command the one you actually want. And pass `--no-reboot` so it never happens again.

This cost a large fraction of the session — hours of debugging a "broken" phone and
cable that were both fine.

### A4 — Piping samloader output into `head`

**What you see:** samloader dies mid‑handshake. Sometimes SIGPIPE, sometimes a garbled
session.

**Cause:** closing the pipe early sends SIGPIPE, killing samloader while it is holding
the device session open. The session is now corrupt and must be re‑entered.

**Fix:**

```bash
# WRONG
./samloader flash ... | head -20

# RIGHT
./samloader flash ... > flash.log 2>&1
```

**Never pipe a live device session into `head` or `grep`.** Log to a file, then read
the file.

### A5 — `samloader print-pit` with no `--file`

**What you see:** *"Unexpected handshake response"*, or the session is consumed for no
reason.

**Cause:** `print-pit` without `--file` tries to talk to the device instead of reading a
local file. `dump-pit` (device → file) and `print-pit` (file → stdout) are different
operations.

**Fix:**

```bash
./samloader-longtimeout dump-pit --no-reboot --output device.pit
./samloader-longtimeout print-pit --file device.pit
```

Also: `dump-pit` **reboots the phone afterwards** unless you pass `--no-reboot`.

### A6 — `dump-pit` without `--output`

**What you see:** a usage error. Harmless — no session is opened.

### A7 — samloader's default reboot

**What you see:** the phone reboots to Android after every flash. Next command fails.

**Cause:** samloader reboots by default after flashing.

**Fix:** `--no-reboot` on every command, unless you actually want the reboot.

### A8 — The phone rebooted into stock and re‑locked

**What you see:** everything you did seems undone. `OEM LOCK: ON` again, `RECOVERY`
back to stock, KG state possibly reset.

**Cause:** a stock boot restores the stock recovery and re‑locks the bootloader.

**Fix:** start over at [`02-diagnose-the-blockers.md`](02-diagnose-the-blockers.md).
This is the single most expensive mistake available in this guide. **Never boot stock
once TWRP is in `BOOT`.**

---

## B. KG Prenormal

### B1 — `Can't check for update — Updates are temporarily unavailable.`

**Cause:** the phone has no internet. A factory reset wiped every saved Wi‑Fi network.

**Fix:** a human joins Wi‑Fi on the phone. Android 9's shell cannot add a network —
`cmd wifi` needs root, `cmd netpolicy` has no add‑network operation.

**Confirm:** `adb shell ping -c 2 8.8.8.8` and `adb shell ping -c 2 google.com` must
both resolve.

### B2 — Certificate errors after backdating the clock

**What you see:** `curl: ssl=9`, "certificate is not yet valid", the update check fails
with a network error even though the internet works.

**Cause:** a backdated clock breaks every TLS handshake. If the fake date is older than
the certificate's `notBefore`, every certificate is "not yet valid".

**The measured floor** (cert chain valid from `notBefore = Nov 3 2026 08:29:37 GMT`):

| Fake date | Days back | Result |
|---|---|---|
| Oct 29 | 15 | ❌ |
| Oct 22 | 22 | ❌ |
| Nov 1 | 12 | ❌ |
| Nov 2 | 11 | ❌ |
| Nov 3 | 10 | ❌ |
| **Nov 4** | **9** | ✅ |
| real clock | 0 | ✅ (control) |

**Fix:** back up **9 days**, and probe before you commit. The window shrinks by one day
every day that passes, because `notBefore` stays where it is.

### B3 — The update check "succeeded" but KG did not clear

**Cause:** the wrong thing was read, or the wrong thing was clicked.

Samsung renders the stored check time as:

- `Last successful check for update **at HH:MM**` — when the stored date **equals**
  the device's current date
- `Last successful check for update **on Nov 13**` — when it is older

A successful **backdated** check must read **`at HH:MM`**. `on Nov 13` is a stale check
from the real date — a false positive.

**The second cause:** the automation matched the *summary line* instead of the *Check
for update button*, and clicked the wrong element.

**Fix:** the rewritten UI scorer in [`scripts/adb-ui.py`](../scripts/adb-ui.py) scores
candidates — exact text +100, clickable +40, `resource-id` containing `button` +25,
shorter text preferred — and picks the button:

```
match "Check for update" (score 142) -> "Check for update" @ (554,1333)
```

### B4 — The fake date did not survive the reboot

**Symptom:** the clock snaps back to real time after rebooting. The check then registers
against the real date and the procedure fails silently.

**Fix:** `adb shell settings put global auto_time 0` **before** setting the clock, and
verify the date after every reboot.

### B5 — `adb shell date ...` does nothing

**What you see:** `bad date`, or the command silently no‑ops.

**Cause:** toybox `date` on this build will not accept a positional format.

**Fix:** `adb shell cmd alarm set-time <epoch_millis>`, with the epoch computed on the
Mac.

### B6 — Long‑pressing Volume Up does nothing

**Cause:** the KG gate is still active. The unlock only works once OEM unlocking is
enabled in Developer options **and** the KG state is cleared.

**Do not** assume the button or the cable is at fault.

---

## C. TWRP and recovery

### C1 — TWRP flashed perfectly, phone still boots "Android Recovery (user) v3.0 / Black Screen v0.4"

**Cause:** **the bootloader loads `BOOT`, not `RECOVERY`.** On this device the
`RECOVERY` partition is inert for booting. Both flashes were clean; they simply were
not being loaded.

**How it was confirmed:** the TWRP ramdisk was extracted and string‑searched — it
contains `TeamWin` and **zero** hits for `Black Screen` or `Android Recovery`. So the
menu on screen genuinely was Samsung's.

**Fix:** flash TWRP to **BOOT as well as RECOVERY**, in one session:

```bash
./samloader-longtimeout flash \
    --partition BOOT     twrp-3.7.0_j4primelte.img \
    --partition RECOVERY twrp-3.7.0_j4primelte.img \
    --no-reboot --verbose
```

### C2 — `adb reboot recovery` boots the wrong recovery

**What you see:** you expected TWRP; you got the LineageOS recovery.

**Cause:** `adb reboot recovery` boots the **ROM's own embedded recovery** (the Android
12 generic ramdisk inside the ROM's `boot.img`). The `RECOVERY` partition is ignored.

**Fix:** use TWRP in `BOOT` as your working recovery, and get to download mode with
`adb reboot bootloader`.

### C3 — The LineageOS recovery cannot clear the boot request (recovery loop)

**What you see:** every "Reboot system now" goes back to the recovery.

**Cause:** the recovery creates `/dev/block/platform/soc/7824900.sdhci/by-name/` but
the bootloader writes the request to `/dev/block/bootdevice/by-name/misc`:

```
E:Failed to clear BOB message: failed to open /dev/block/bootdevice/by-name/misc
init: reboot-bootloader: Error writing bootloader_message: failed to stat /dev/block/bootdevice/by-name/misc try 1..10
```

TWRP creates that path, so TWRP can always boot the system.

**Fix:** restore the LineageOS `boot.img` to `BOOT` via samloader, or boot system from
TWRP. Full detail in
[`06-verify-first-boot-and-recovery.md`](06-verify-first-boot-and-recovery.md) §6.3.

### C4 — `twrp: inaccessible or not found`

**Cause:** the `twrp` CLI only exists in TWRP. You are in the LineageOS recovery.

**Fix:** either use TWRP, or run the installer directly (see E3).

### C5 — ADB is `unauthorized` in recovery

**Cause:** the data wipe removed `/data/misc/adb/adb_keys`.

**Fix:** from TWRP (which has root), seed the key — §6.1 in the verify document.

### C6 — `VERIFICATION FAILED` after an install

**Cause:** expected on this device when encryption is involved.

**Fix:** format `/data` (Format, not Wipe — see D4) and reinstall.

---

## D. ROM installation

### D1 — `adb sideload` fails

**What you see:**
- On TWRP 3.7: `sideload connection failed: closed` (the pre‑KitKat method also fails)
- On the LineageOS recovery: `device unauthorized`

**Fix:** `adb push` the file, then install it from a shell or the GUI. Sideload is not
available on this device's recoveries.

### D2 — The install dies during the system write

**Cause:** TWRP's `/tmp` is tmpfs with about 899 MB, and converting `system.new.dat.br`
into a raw image for a 2.39 GB partition can need more than that.

**Fix:** convert on the Mac (`brew install brotli`, decompress `.br`, combine with
`system.transfer.list`), push the 2.39 GB image, and write it to `/dev/block/mmcblk0p47`
from TWRP's shell.

> ⚠️ A raw write over `/system` **erases the Google apps** you installed. Reinstall
> GApps afterwards.

This fallback was not needed — the install completed with `bytes_written_system:
1510322176` — but it is the known path.

### D3 — `no-verity-opt-encrypt-6.1.zip` fails

**What you see:**

```
Updater process ended with ERROR: 1
/tmp/updater[63]: .: config.sh: No such file or directory
```

**Cause:** the zip does not work with this recovery, **and it is not needed** — this
device has **no `vbmeta` partition**, and this ROM carries `vendor` inside `system`, so
the dm‑verity and force‑encrypt patches are moot.

**Fix:** skip it entirely.

### D4 — Use "Format data", not "Wipe data"

**Cause:** Samsung's encryption is not supported by TWRP on this device, so a "Wipe" of
`/data` can leave the partition in a state the system cannot mount.

**Fix:** in TWRP, use **Advanced → Format Data** (or `twrp format data`), which
reformats the filesystem properly.

### D5 — Reading a partition to compare it

**What you see:** `adb shell cat /dev/block/by-name/recovery` → *Permission denied*.

**Cause:** no root in Android.

**Fix:** read it from TWRP, where you have root. And note that the ramdisk is
**compressed** — `strings` will not find anything. You must extract it (kernel
12,382,949 B, ramdisk 15,124,136 B gzip, page size 2048) and decompress with Python's
`gzip` before searching. This is how the TWRP‑versus‑stock‑recovery question was
actually answered.

---

## E. Google apps

### E1 — Play Store missing after installing MindTheGapps

**Cause:** MindTheGapps' `remove_big_optional_apps` path strips Velvet (the Play
Store) when there is not enough room in `/system`.

**Fix:** make sure there is at least ~500 MB free in the system partition before
installing. The original session had 892 MB free, so it never triggered.

### E2 — Wrong GApps version or architecture

**Symptoms:** installation fails, or apps crash on launch, or the Play Store will not
install.

**Cause:** MindTheGapps **13.0.0** is for LineageOS 20 / Android 13; this ROM is
LineageOS 19.1 / Android 12L → **12.1.0**. And the ARM64 package is wrong: this ROM
is **32‑bit ARM**.

**Correct package:** `MindTheGapps-12.1.0-arm-20231025_200802.zip` (228,186,029 bytes).

### E3 — Installing GApps in the LineageOS recovery

**What you see:** the usual "Install zip" flow is not available in the LineageOS
recovery's menu, and `twrp install` is not a command there.

**Fix:** run MindTheGapps' own installer by hand from a root shell:

```bash
adb push mtg/update-binary /data/update-binary
adb push MindTheGapps-12.1.0-arm-20231025_200802.zip /data/mtg.zip
adb shell "sh /data/update-binary /data 1 /data/mtg.zip"
```

### E4 — GApps vanished after a later install

**Cause:** the ROM install overwrote `/system`, and both GApps and the RMM bypass patch
`/system`.

**Fix:** install order is **Format Data → ROM → GApps → RMM bypass** (if used).

### E5 — FRP: "VERIFICATION FAILED" or a Google account prompt at setup

**Cause:** FRP is still active.

**Fix:** clear it in recovery with LineageOS' `wipe-frp.sh`.

> **Branch caveat:** the script lives at `prebuilt/common/bin/wipe-frp.sh` in
> `LineageOS/android_vendor_lineage`, but it is only installed into recovery from
> 2025 onward — **it is not present on the `lineage-19.1` branch**. Push it manually
> from recovery. The script resolves its target from the **`ro.frp.pst`** property,
> which on Samsung is the **`persistent`** partition; it accepts a partition override
> as its first argument.

---

## F. First boot

### F1 — "An internal error has occurred"

**Cause:** expected. The ROM's `vendor` was built inside `system`.

**Fix:** dismiss it.

### F2 — No USB device for two minutes after rebooting

**Cause:** normal. The USB gadget appears only once Android's USB service starts.

**Fix:** wait. Check again.

### F3 — The system never booted at all (not a recovery loop)

**Diagnose before you blame the ROM:**

```bash
adb pull /sys/fs/pstore/console-ramoops pstore-console.log
grep -E "zygote|system_server|boot_completed|apexd" pstore-console.log
```

Zero hits means the system never attempted to boot — the fault is upstream (usually the
recovery or the bootloader), not in the ROM.

### F4 — Traffic statistics show nothing

**Cause:** known limitation of these unofficial builds — the kernel's eBPF traffic
accounting is broken.

**Fix:** live with it, or use a different ROM.

### F5 — Face unlock missing, Gcam not installed

**Cause:** known limitations of the unofficial builds, not a flashing fault.

---

## G. macOS and tooling

### G1 — `brew install heimdall`

**What you see:** no such formula. `brew install --cask heimdall-suite` → cask disabled
(Mar 2026). The Heimdall GitHub release binaries → 404; the repo has source only.

**Fix:** use samloader. Heimdall 1.4.0 was installed from the `.dmg` as a fallback and
failed the handshake anyway — *"Device detected" but "ERROR: Protocol initialisation
failed!"* — because Heimdall does not speak the Odin/Loke protocol this bootloader
expects.

### G2 — Heimdall's `libusb` will not load on Apple Silicon

**What you see:** a dyld error about `libusb-1.0.dylib`.

**Cause:** Heimdall ships an **x86_64** `libusb`; Homebrew's is **arm64‑only**.

**Fix:** copy Heimdall's own bundled dylib next to the binary and point at it:

```bash
DYLD_LIBRARY_PATH=/Users/you/Desktop/j4-flash ./heimdall detect
```

(Moot if you are using samloader, which is the recommendation.)

### G3 — The nusb crate panics

**What you see:** `Awaiting blocking syscall without an async runtime`.

**Cause:** `nusb` needs the `smol` feature.

**Fix:** `nusb = { version = "0.2.7", features = ["smol"] }` in `Cargo.toml`, build with
`--features nusb,rusb`.

### G4 — `cargo build --features verbose`

**What you see:** unknown feature.

**Cause:** there is no `verbose` feature. Verbose is a flag: `--verbose`.

### G5 — macOS MTP error: *"the connected device is unable to access data on this device… Android File Transfer or Samsung Smart Switch must be installed"*

**Cause:** harmless. macOS does not have a Samsung MTP driver.

**Fix:** ignore it. ADB does not need it. Tap OK and carry on.

### G6 — ADB asks for authorisation on every boot

**Cause:** the data wipe removed the key, or you ticked "OK" instead of "Always allow
from this computer".

**Fix:** tick **"Always allow"**, or pre‑seed the key from TWRP (§6.1).

### G7 — Editing a bash script while it is running

**What you see:** the script's behaviour changes underneath it. In the original session
this corrupted the runner and killed the job mid‑flash.

**Cause:** the shell reads scripts by byte offset. Rewriting a running script changes
those offsets.

**Fix:** never edit a running script. Write a new file and restart the task.

### G8 — Long background tasks die at 60 minutes

**Cause:** background bash tasks are capped.

**Fix:** long watchers must be re‑armed. Check the task status before assuming a
watcher is still alive.

### G9 — A flaky USB hub

**Symptom:** the LAN dongle's hub port logs `hardware connection lost` repeatedly; USB
devices vanish.

**Fix:** plug the phone into a **USB‑A port directly**, not through a hub or dock.

---

## H. Downloads

### H1 — TWRP download returns a 6,885‑byte HTML file

**Cause:** `dl.twrp.me` serves an interstitial to plain clients.

**Fix:** fetch the `.html` page first with a cookie jar and a browser Referer + User‑
Agent, then fetch the `.img` with the same cookies. If `dl.twrp.me` is unreachable,
use `https://eu.dl.twrp.me/j4primelte/`.

### H2 — MindTheGapps download returns HTML

**Cause:** an interstitial requiring a two‑step with a shared cookie jar, then the
tokenised `/d/<token>/<epoch>/...` path.

**Fix:** the GitHub release is a direct asset link and is much easier:
<https://github.com/MindTheGapps/12.1.0-arm/releases/latest>

### H3 — SourceForge serves a Cloudflare challenge; AndroidFileHost serves a JS mirror picker

**Fix:** use the direct mirror:
`https://master.dl.sourceforge.net/project/m30lte-dev/RMM%20Lock/RMM_Bypass_v3_corsicanu.zip`
— or download in a real browser and move the file.

### H4 — The LineageOS ROM link is dead

**What you see:** *"Sorry, the file you have requested does not exist."* on Google Drive.

**Cause:** the XDA thread's ROM link died; the thread was closed in Aug 2026.

**Fix:** use the currently maintained build line. See
[`01-prerequisites-and-downloads.md`](01-prerequisites-and-downloads.md).

---

## I. Facts that were wrong

Three claims that were believed during the session and later disproved by checking the
device. They are listed here because **the reasoning from symptoms would have led you
the wrong way**.

| Claim | Reality | How it was found |
|---|---|---|
| "The ROM is ARM64." | It is **32‑bit ARM** (`armeabi-v7a`, `ro.zygote=zygote32`). | The `msm8953_64` string in `fstab.qcom` is a device‑tree copy‑paste artifact. Decompressed `system.new.dat.br` and read `build.prop`. |
| "The RMM bypass removed a `libvkjson.so` copy." | There was only ever one copy, in `system/lib`, and it survived. The ROM install overwrote it. | Checked the filesystem rather than inferring from a missing file. |
| "The phone is broken / the cable is bad." | Both were fine. The tool's own default reboot was burning the session. | Read the protocol behaviour instead of the symptom. |

---

Next: [`08-learnings.md`](08-learnings.md)
