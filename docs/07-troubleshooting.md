# 07 — Troubleshooting (Q&A)

Find your symptom in the index, jump to the question.

If you are **not sure what is wrong**, run these four commands first. Between them
they answer most of this page:

```bash
ioreg -p IOUSB -w0 2>/dev/null | grep -oE "(MSM8953|SAMSUNG_Android)@[0-9a-f]+" | head -1
adb devices -l
adb shell getprop ro.build.version.release   # if adb is up
cat ~/Desktop/j4-flash/logs/*.log             # whatever you have already logged
```

> Not sure whether you need a Windows PC? The phone runs Samsung's stock Android
> and your computer is the one that talks to it — [Q30](#q30) spells out which is
> which.

---

## Symptom index

| What you see | Go to |
|---|---|
| `FAIL! Auth` | [Q1](#q1) |
| `Only officially released binaries are allowed to be flashed` | [Q1](#q1) |
| `Failed to receive handshake response` | [Q2](#q2) |
| The phone ignores every tool | [Q3](#q3) |
| samloader died mid-transfer | [Q4](#q4) |
| Handshake times out on a clean session | [Q5](#q5) |
| `Unexpected handshake response` | [Q6](#q6) |
| The phone rebooted back to stock Android | [Q7](#q7) |
| `Can't check for update — Updates are temporarily unavailable` | [Q8](#q8) |
| `certificate is not yet valid` / `curl: ssl=9` | [Q9](#q9) |
| The check says `on Nov 13` instead of `at HH:MM` | [Q10](#q10) |
| The clock snapped back to real time | [Q11](#q11) |
| `bad date` from `adb shell date` | [Q12](#q12) |
| The phone boots "Android Recovery (user) v3.0" | [Q13](#q13) |
| `adb reboot recovery` boots the wrong thing | [Q14](#q14) |
| `sideload connection failed: closed` | [Q15](#q15) |
| `device unauthorized` from adb | [Q16](#q16) |
| `Updater process ended with ERROR: 1` | [Q17](#q17) |
| `twrp: inaccessible or not found` | [Q18](#q18) |
| The phone loops into recovery | [Q19](#q19) |
| `Failed to clear BOB message` | [Q19](#q19) |
| `Permission denied` reading a block device | [Q20](#q20) |
| `VERIFICATION FAILED` | [Q21](#q21) |
| No Play Store after installing GApps | [Q22](#q22) |
| Google apps vanished after a later install | [Q23](#q23) |
| `/data` will not mount, or `twrp format data` misbehaves | [Q24](#q24) |
| The install died during the system write | [Q25](#q25) |
| Nothing happens when I long-press Volume Up | [Q26](#q26) |
| `dm-verity` / bootloop right after install | [Q27](#q27) |
| I need to start completely over | [Q28](#q28) |
| I am not sure which stage I am at | [Q29](#q29) |
| "Do I need Windows?" / "Is the phone running Windows?" | [Q30](#q30) |

---

## Before you start

<a id="q30"></a>
### Q30. Do I need Windows? Is the phone running Windows?

**A:** Two different machines are involved, and the questions about them have
different answers.

| | What it is | What the answer is |
|---|---|---|
| **The phone** | The Galaxy J4+ itself. It runs **Samsung's stock Android** — Samsung's own build of Android 8.1, with Knox, Samsung Cloud and the rest. | That is **exactly what LineageOS replaces**. The phone never runs Windows and never needs to. |
| **Your computer** | The machine you plug the phone into. This kit drives it from **macOS** with `samloader`. | You do **not** need a Windows PC, and you do **not** need Odin or Zadig. `samloader` speaks Samsung's Loke/Odin protocol directly over USB. |

The one place a Windows PC genuinely shows up is the **KG Prenormal** fallback: if
the free clock-backdating method does not clear the KG gate, the alternatives are the
paid Windows tools (ChimeraTool, HydraTool) or the 7-day wait. That is a fork in the
road, not a requirement — see [`03-kg-prenormal-bypass.md`](03-kg-prenormal-bypass.md).

> `samloader` does ship a **Windows build**, and on it the default USB backend is
> VCOM, so it needs no Odin and no driver swap there either. If your computer is
> Windows, the official Odin guide may still be the shorter path for you — this kit
> exists because it was written on a Mac.

---

## A. Connecting and detecting

<a id="q29"></a>
### Q29. Which stage am I at?

**A:** Run `./install.sh --status`. It reports the USB mode, whether adb is
authorised, whether the phone has internet, which files are present, and which
stages are already done. It is read-only and changes nothing.

---

<a id="q2"></a>
### Q2. `Failed to receive handshake response: Transfer timed out`.

**A:** Nine times out of ten this is a **spent session**, not a broken cable, and
not a dead phone.

Samsung grants **one protocol session per entry into download mode.** If any
earlier command already used it — a detection call, a PIT dump, or a previous
flash without `--no-reboot` — then this command is fighting a session that no
longer exists, and the handshake times out.

**Fix:** leave and re-enter download mode to get a fresh session, then make the
**flash** the first device command of that session:

```bash
adb reboot download
ioreg -p IOUSB -w0 2>/dev/null | grep -oE "MSM8953@[0-9a-f]+" | head -1
```

See [Q3](#q3) for the full list of things that can eat a session, and [Q5](#q5)
if the handshake still times out on a genuinely fresh one.

---

<a id="q3"></a>
### Q3. The phone ignores every tool. Is it dead?

**A:** Almost certainly not. This is the single most expensive false alarm in the
whole procedure, and it cost hours in the original session.

Samsung grants **one protocol session per entry into download mode**. If a previous
command took the phone out of download mode (or samloader rebooted it at the end
because `--no-reboot` was missing), every later command times out against a session
that no longer exists — and a timeout looks exactly like a dead cable.

**Fix:**

```bash
adb reboot download          # fresh entry, fresh session
ioreg -p IOUSB -w0 2>/dev/null | grep -oE "MSM8953@[0-9a-f]+" | head -1
```

Then make the **flash** the first device command of that session. Do not run
`samloader detect` or `dump-pit` first.

Also check: a data-capable cable, a direct USB‑A port (not a hub), and the phone
actually in download mode (`MSM8953`).

---

<a id="q26"></a>
### Q26. Nothing happens when I long-press Volume Up on the Odin screen.

**A:** The unlock long-press only works when the **OEM Unlock** toggle is on in
Developer options **and** the KG gate is cleared. While KG Prenormal is active,
the long-press does nothing at all.

Check the Odin screen: if it says `KG STATUS: Prenormal`, that is the reason.
Otherwise, confirm `OEM unlocking` is ON in Developer options.

---

<a id="q16"></a>
### Q16. adb says `unauthorized`.

**A:** The data wipe removed `/data/misc/adb/adb_keys`, so the phone no longer
recognises your Mac.

**Fix A — tick the box.** On the phone, in the authorisation prompt, choose
**"Always allow from this computer"**, not just OK.

**Fix B — pre-seed the key** (better, because it survives every future wipe).
From TWRP, which has root:

```bash
adb push ~/.android/adbkey.pub /sdcard/mac_adbkey.pub
adb shell 'mkdir -p /data/misc/adb; cp /sdcard/mac_adbkey.pub /data/misc/adb/adb_keys; chown -R root:shell /data/misc/adb; chmod 0750 /data/misc/adb; chmod 0640 /data/misc/adb/adb_keys'
```

---

<a id="q5"></a>
### Q5. The handshake times out even on a fresh session.

**A:** Stock samloader has a **one-second** handshake timeout. On a Mac, that is a
coin flip.

**Fix:** use a build with the timeout patched to 15 seconds. See
[`docs/01`](01-prerequisites-and-downloads.md) §1.5 — `HANDSHAKE_TIMEOUT` in
`odin/src/session.rs`, and the `smol` feature on the `nusb` crate.

---

<a id="q4"></a>
### Q4. samloader died part-way through.

**A:** You piped its output into `head` or `grep`. SIGPIPE killed the process
while it held the device session open, and the session is now corrupt.

**Fix:** never pipe a live device session. Log to a file, then read the file:

```bash
./samloader-longtimeout flash ... > flash.log 2>&1
```

Then leave and re-enter download mode for a fresh session.

---

<a id="q6"></a>
### Q6. `samloader print-pit` says "Unexpected handshake response".

**A:** `print-pit` without `--file` tries to talk to the device instead of reading
a local file, and it consumes the session.

**Fix:**

```bash
./samloader-longtimeout dump-pit --no-reboot --output device.pit   # device -> file
./samloader-longtimeout print-pit --file device.pit                # file -> stdout
```

Note that `dump-pit` reboots the phone afterwards unless you pass `--no-reboot`.

---

## B. The flash itself

<a id="q1"></a>
### Q1. `FAIL! Auth` — "Only officially released binaries are allowed to be flashed".

**A:** The transfer worked. All 27.5 MB went through and the bootloader refused the
signature at the end. This is an **authorisation** failure, not a transport
failure — do not rebuild samloader, change cables or retry the same image.

Two possible causes, both visible on the Odin screen:

| Odin screen | Cause | Fix |
|---|---|---|
| `OEM LOCK: ON` | Bootloader is locked | Unlock it — [`docs/02`](02-diagnose-the-blockers.md) §2.4 |
| `KG STATUS: Prenormal` | The separate KG gate | [`docs/03`](03-kg-prenormal-bypass.md) |

If **both** are present, clear KG first — the unlock long-press will not work
while KG is active.

---

<a id="q7"></a>
### Q7. The phone rebooted back into stock Android.

**A:** If TWRP is already in `BOOT`, a stock boot can restore stock recovery and
**re-lock the bootloader** — you are back at the start.

**Fix:** if it is still unlocked, continue: `adb reboot download`, then flash TWRP
to BOOT and RECOVERY again. If it re-locked, redo the unlock.

**Prevention:** this is why every script here refuses to let the phone reach
stock, and why `install.sh` never issues a plain reboot once TWRP is in place.

Before TWRP is installed, booting stock is harmless and sometimes necessary (the
KG bypass needs stock Android).

---

## C. KG Prenormal

<a id="q8"></a>
### Q8. `Can't check for update — Updates are temporarily unavailable`.

**A:** The phone has no internet. A factory reset wipes every saved Wi‑Fi network,
and Android 9's shell cannot add one — `cmd wifi` needs root and `cmd netpolicy`
has no add-network operation.

**Fix:** join Wi‑Fi **on the phone** (Settings → Wi‑Fi). This is the one step no
automation can do for you.

**Check:** `adb shell ping -c 2 8.8.8.8` must succeed.

---

<a id="q9"></a>
### Q9. `certificate is not yet valid`, `curl: ssl=9`, or the update check fails with a network error.

**A:** You backdated the clock too far. A backdated clock breaks every TLS
handshake, because the certificate is "not yet valid" in the past. The
certificate chain's `notBefore` is the hard floor.

Measured on the run this kit is based on (chain valid from
`notBefore = Nov 3 2026 08:29:37 GMT`):

| Backdate | Result |
|---|---|
| 22 days | fail |
| 15 days | fail |
| 12 days | fail |
| 11 days | fail |
| 10 days | fail |
| **9 days** | **success** |
| real clock (control) | success |

The method needs **more than 7 days**. TLS allowed exactly 9.

**Fix:** use a 9-day backdate, and probe rather than guess — `02-kg-bypass.sh`
does this automatically. The window closes by one day every day that passes,
because `notBefore` stays where it is while today moves forward.

---

<a id="q10"></a>
### Q10. The check succeeded but the KG state did not clear. The screen says `on Nov 13`.

**A:** That is a **false positive**. Samsung renders the stored check time
differently depending on whether the stored date matches today's date:

| Stored date | On screen |
|---|---|
| Same day as the device's clock | `Last successful check for update at HH:MM` |
| Older | `Last successful check for update on Nov 13` |

A successful *backdated* check must read **`at HH:MM`**. `on Nov 13` is a stale
check from the real date — the backdated check never registered.

**Fix:** make sure the update check ran **while the clock was backdated**, and
check for `at HH:MM` specifically. If your automation is matching the wrong
element, use `scripts/adb-ui.py`, which scores candidates instead of taking the
first match — exact text +100, clickable +40, button-ish `resource-id` +25.

---

<a id="q11"></a>
### Q11. The backdated clock snapped back to real time after the reboot.

**A:** The check then registers against the real date and the procedure fails
silently.

**Fix:** turn off automatic time **before** setting the clock, and verify after
every reboot:

```bash
adb shell settings put global auto_time 0
adb shell cmd alarm set-time <epoch_millis>
adb reboot
adb shell date          # must still show the fake date
```

---

<a id="q12"></a>
### Q12. `adb shell date 09131200002026.00` returns `bad date`.

**A:** toybox `date` on this build will not accept a positional format. It also
silently no-ops if you get the format wrong.

**Fix:** `adb shell cmd alarm set-time <epoch_millis>`, with the epoch computed on
the Mac.

---

## D. TWRP and recovery

<a id="q13"></a>
### Q13. TWRP flashed with no errors, but the phone boots "Android Recovery (user) v3.0 / Black Screen v0.4".

**A:** **This bootloader loads `BOOT`, not `RECOVERY`.** The `RECOVERY` partition
is inert on this device. You wrote a recovery to a partition nothing reads. Both
flashes really did succeed.

**Fix:** flash TWRP to **both** partitions, in one session:

```bash
./samloader-longtimeout flash \
    --partition BOOT     twrp-3.7.0_j4primelte.img \
    --partition RECOVERY twrp-3.7.0_j4primelte.img \
    --no-reboot --verbose
```

**How to prove it, if you doubt it:** the TWRP ramdisk is compressed, so
`strings` finds nothing. Extract it and gunzip it, then search — the real TWRP
contains `TeamWin` and **zero** hits for `Black Screen` or `Android Recovery`.

---

<a id="q14"></a>
### Q14. `adb reboot recovery` boots the LineageOS recovery, not TWRP.

**A:** Expected. That command boots the ROM's **own embedded recovery** (the
Android 12 generic ramdisk inside the ROM's `boot.img`). The `RECOVERY` partition
is ignored.

**Fix:** use TWRP in `BOOT` as your working recovery, and reach download mode with
`adb reboot bootloader`.

---

<a id="q18"></a>
### Q18. `twrp: inaccessible or not found`.

**A:** The `twrp` CLI only exists in TWRP. You are in the LineageOS recovery.

**Fix:** in the LineageOS recovery, run the installer's `update-binary` by hand
instead — see [Q22](#q22) for the exact commands.

---

<a id="q19"></a>
### Q19. The phone loops into recovery. "Reboot system now" comes straight back.

**A:** Two different causes. **Check the evidence before you act** — the obvious
explanation (Google apps broke it) is usually wrong.

**Step 1 — did the system even try to boot?**

```bash
adb pull /sys/fs/pstore/console-ramoops pstore-console.log
grep -E "zygote|system_server|boot_completed|apexd" pstore-console.log
```

- **Zero hits** → the system never attempted to boot. The fault is upstream.
- **Hits present** → the system did start and crashed. Different problem.

**Step 2 — is there a stale boot request?**

```bash
adb shell 'dd if=/dev/block/by-name/misc bs=1M count=1 2>/dev/null | xxd | head -5'
```

All zeros means no stale request.

**The usual cause**, visible in the recovery's own log:

```
E:Failed to clear BOB message: failed to open /dev/block/bootdevice/by-name/misc
init: reboot-bootloader: Error writing bootloader_message: failed to stat /dev/block/bootdevice/by-name/misc try 1..10
```

The LineageOS recovery creates only
`/dev/block/platform/soc/7824900.sdhci/by-name/`, but the bootloader writes the
request to `/dev/block/bootdevice/by-name/misc`. The recovery can never clear it.
TWRP *does* create that path, which is why TWRP can always boot the system.

**Fix:** restore the ROM's `boot.img` into `BOOT` via samloader, or boot the
system from TWRP. See [`docs/06`](06-verify-first-boot-and-recovery.md) §6.3.

---

## E. Installing the ROM

<a id="q20"></a>
### Q20. `adb shell cat /dev/block/by-name/recovery` returns `Permission denied`.

**A:** Android runs without root, so you cannot read a block device from a running
system. That is by design, not a broken phone.

**Fix:** read it from **TWRP**, which has root. And note that the recovery ramdisk
is **compressed**, so `strings` on the raw partition finds nothing — extract the
image and decompress it before searching. This is how the "TWRP flashed fine but
the phone booted stock recovery" question ([Q13](#q13)) was actually settled.

---

<a id="q15"></a>
### Q15. `adb sideload` fails — `sideload connection failed: closed`, or `device unauthorized`.

**A:** Sideload does not work on this device's recoveries. The TWRP 3.7 sideload
protocol fails, the pre‑KitKat method fails, and the LineageOS recovery requires
host authorisation for sideload too.

**Fix:** push the file and install it from a shell:

```bash
adb push lineage-19.1-20231011-UNOFFICIAL-j4primelte.zip /sdcard/j4/
adb shell "twrp install /sdcard/j4/lineage-19.1-20231011-UNOFFICIAL-j4primelte.zip"
```

---

<a id="q17"></a>
### Q17. `Updater process ended with ERROR: 1` / `config.sh: No such file or directory`.

**A:** That is the `no-verity-opt-encrypt` zip. It fails because it does not work
with this recovery, **and because you do not need it**: this device has **no
`vbmeta` partition**, and this ROM carries `vendor` inside `system`, so its
`fstab.qcom` has no `/vendor` mount and the dm‑verity patches are moot.

**Fix:** skip it. See [Q27](#q27) if you are actually bootlooping.

---

<a id="q21"></a>
### Q21. `VERIFICATION FAILED` at setup.

**A:** Usually FRP (Factory Reset Protection) still being active, or `/data`
carrying an encryption state TWRP could not clear.

**Fix:**

1. Format `/data` with **Format**, not Wipe — see [Q24](#q24).
2. If a Google account is demanded, clear FRP from recovery with LineageOS's own
   script:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/LineageOS/android_vendor_lineage/master/prebuilt/common/bin/wipe-frp.sh -o wipe-frp.sh
   adb push wipe-frp.sh /data/local/tmp/wipe-frp.sh
   adb shell "chmod 0755 /data/local/tmp/wipe-frp.sh"
   adb shell "/data/local/tmp/wipe-frp.sh"
   ```

   It resolves its target from `ro.frp.pst`, which on Samsung is the
   **`persistent`** partition. Note it is **not** present on the `lineage-19.1`
   branch, so you must push it manually.

---

<a id="q24"></a>
### Q24. `/data` will not mount, or a Wipe left it unusable.

**A:** Samsung's encryption is not supported by TWRP on this device. A **Wipe**
can leave the partition unmountable; a **Format** re-creates it properly.

**Fix:** in TWRP use **Advanced → Format Data** (or `twrp format data`), and
confirm.

---

<a id="q25"></a>
### Q25. The install died while writing the system partition.

**A:** TWRP's `/tmp` is tmpfs with roughly 899 MB, and converting
`system.new.dat.br` into a raw image for a 2.39 GB partition can need more than
that.

**Fix:** convert on the Mac and write the raw image:

```bash
brew install brotli
# decompress system.new.dat.br, combine with system.transfer.list -> system.img
adb push system.img /sdcard/
# then, from TWRP's root shell:
dd if=/sdcard/system.img of=/dev/block/mmcblk0p47
```

**Note:** a raw write over `/system` **erases the Google apps**, so install them
afterwards.

---

<a id="q27"></a>
### Q27. The phone bootloops right after the install, with dm-verity errors.

**A:** You probably did not need `no-verity-opt-encrypt` (see [Q17](#q17)), but if
you installed it and it half-worked, the fix is the same as [Q25](#q25): format
`/data` and re-install. There is no `vbmeta` partition to patch on this device.

---

## F. Google apps

<a id="q22"></a>
### Q22. The Play Store is missing after installing MindTheGapps.

**A:** MindTheGapps strips "optional big apps" — including Velvet, the Play
Store — when the system partition does not have enough room.

**Fix:** make sure there is **at least ~500 MB free in `/system`** before
installing. Check with `adb shell df -h /system`. The original run had 892 MB
free, so it never triggered.

**To install GApps in the LineageOS recovery**, where there is no `twrp` CLI:

```bash
unzip -o MindTheGapps-12.1.0-arm-20231025_200802.zip 'META-INF/com/google/android/update-binary' -d mtg
adb push mtg/update-binary /data/update-binary
adb push MindTheGapps-12.1.0-arm-20231025_200802.zip /data/mtg.zip
adb shell "sh /data/update-binary /data 1 /data/mtg.zip"
```

Then verify `product/priv-app/Velvet/Velvet.apk`, `product/priv-app/GmsCore/GmsCore.apk`,
`product/etc/permissions/privapp-permissions-google-product.xml` and
`addon.d/30-gapps.sh` all exist.

---

<a id="q23"></a>
### Q23. The Google apps disappeared after a later install.

**A:** The ROM install overwrote `/system`, and both GApps and the RMM bypass zip
patch `/system`.

**Fix:** install order is **Format Data → ROM → Google apps → RMM bypass** (if
used at all). The RMM bypass is unnecessary for a LineageOS build — there is no
`vaultkeeper`, `Rlc` or `KnoxGuard` in LineageOS for it to patch.

---

## G. Getting unstuck

<a id="q28"></a>
### Q28. I need to start completely over.

**A:** In order:

1. **Never boot stock** unless TWRP is not yet in BOOT — that is the one step
   that can undo everything.
2. From TWRP: `adb shell "twrp format data"`.
3. Re-install the ROM and Google apps.
4. Restore the ROM's `boot.img` into BOOT.
5. Verify with `adb shell getprop ro.build.version.sdk` → `32`.

If you have already booted stock and the bootloader re-locked, you are back at
[`docs/02`](02-diagnose-the-blockers.md) §2.4.

---

## Still stuck?

Open an issue with:

- the exact model and variant (`SM‑J415F`, `SM‑J415GN`, …)
- the **exact** error text, copied rather than paraphrased
- whether you were in download mode, TWRP, the LineageOS recovery, or stock
- the output of `./install.sh --status`
- your macOS version, your architecture, and your samloader version

---

Background on *why* the procedure is shaped this way: [`08-learnings.md`](08-learnings.md).
