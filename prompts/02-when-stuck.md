# 02 — When something failed and you do not know why

> **Paste everything below into the agent**, after pasting `agent-brief.md`.
> Use this when you are already mid-procedure and something has broken.

---

The flash on my **Samsung Galaxy J4+** (`SM-J415GN`, `j4primelte`) has failed and I
do not know why. The agent brief I just pasted has the device facts, the protocol
rules, the partition map and the checksums — treat it as the source of truth.

**Do not guess at a fix yet.** Work through this in order and show me the evidence at
each step. If you hit something that is not in the brief, say so explicitly and show
me the raw output rather than trying a sequence of workarounds.

---

## Step 1 — Pin down where it failed

Ask me for, and record:

- The **exact** error text (copy it, do not paraphrase).
- The **exact command** I ran.
- Whether the phone was in **download mode**, in **TWRP**, in the **LineageOS
  recovery**, in **stock Android**, or **not responding at all**.
- A **photo of the phone's screen**.

Then classify it:

| Where it failed | Most likely |
|---|---|
| During the samloader handshake | Session already spent, stock timeout, wrong cable/port |
| After all data transferred, with `FAIL! Auth` | Bootloader locked, or KG Prenormal |
| TWRP flashed, phone booted something else | `BOOT` vs `RECOVERY` — see step 4 |
| During `twrp install` | `/tmp` space, or `sideload` not supported |
| Phone boots recovery over and over | The recovery cannot clear the boot request |
| Bootloader will not unlock | KG state, or OEM unlocking not enabled |

---

## Step 2 — Establish the ground truth from the device

Run these and show me the raw output. Do not summarise.

```bash
# 1. is the phone enumerated, and in what mode?
ioreg -p IOUSB -w0 2>/dev/null | grep -oE "(MSM8953|SAMSUNG_Android)@[0-9a-f]+[[:space:]]+<class IOUSBHostDevice, id 0x[0-9a-f]+" | head -1

# 2. is adb up, and authorised?
adb devices -l

# 3. if Android is running, what is it?
adb shell getprop ro.product.device
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.sdk
adb shell getprop ro.product.cpu.abi
adb shell getprop ro.boot.selinux
```

Then ask me for the **Odin screen**, photographed, if the phone is in download mode. I
need three lines: `OEM LOCK:`, `KG STATUS:` (or its absence), and `FRP LOCK:`.

---

## Step 3 — Check the things that are cheap to check and expensive to skip

**a) Session state.** If the phone is in download mode, has a samloader command been
run since it entered download mode? Samsung grants **one protocol session per
download-mode entry**. If a command has already been run, the session is spent and a
handshake timeout is expected — it is **not** a dead cable or a broken phone.

**b) The flash must be the first device command.** If a detection command or a PIT
dump ran first, that consumed the session. Fix: leave and re-enter download mode, then
make the flash the first command.

**c) Check for a truncated download.** Verify the TWRP image's sha256 against the
brief. A 6,885-byte file is the download interstitial, not the image.

**d) Check for a piped command.** If the output was piped into `head` or `grep`, the
session may be corrupted by SIGPIPE.

**e) Check for a default reboot.** If the command ran without `--no-reboot`, samloader
rebooted the phone at the end, which ends the session and may have booted stock.

---

## Step 4 — Specific failures

### "The flash said `FAIL! Auth`"

**The transfer worked.** That is the signature of an authorisation failure, not a
transport failure. Do not rebuild samloader, do not change cables, do not retry the
same image.

- If `OEM LOCK: ON` → the bootloader is locked.
- If `KG STATUS: Prenormal` → the KG gate is active, and it blocks non-Samsung
  binaries even with `OEM LOCK: OFF`.

Tell me which, and what the fix is, before doing anything.

### "TWRP flashed successfully but the phone booted 'Android Recovery (user) v3.0 / Black Screen v0.4'"

**This bootloader loads `BOOT`, not `RECOVERY`.** The `RECOVERY` partition is inert.
Flash TWRP to **both** partitions in one session:

```bash
./samloader-longtimeout flash \
    --partition BOOT     twrp-3.7.0_j4primelte.img \
    --partition RECOVERY twrp-3.7.0_j4primelte.img \
    --no-reboot --verbose > twrp-flash.log 2>&1
```

### "The phone boots the LineageOS recovery and 'Reboot system now' loops back"

**Do not blame the ROM or the GApps yet.** Get the evidence first:

```bash
adb pull /sys/fs/pstore/console-ramoops pstore-console.log
grep -E "zygote|system_server|boot_completed|apexd" pstore-console.log
```

- **Zero hits** → the system never attempted to boot. The fault is upstream.
- **Hits present** → the system did start and crashed; that is a different problem.

Then show me the recovery's own error. The known cause is that the LineageOS recovery
never creates `/dev/block/bootdevice/by-name/`, so it cannot clear the boot request
the bootloader wrote to `/dev/block/bootdevice/by-name/misc`. TWRP *does* create it.

**Fix:** restore the ROM's `boot.img` into `BOOT` via samloader, or boot the system
from TWRP.

### "The phone is unresponsive to every tool"

Before assuming hardware: **re-enter download mode** (`adb reboot download`) and try
a fresh session with the flash as the first device command. If it works, the phone
was never broken.

### "The update check fails with 'Can't check for update'"

Check internet first (`adb shell ping -c 2 8.8.8.8`). If the phone has no internet,
**I have to join Wi-Fi by hand** — the shell cannot add a network on this build.

### "The update check fails with a certificate error"

The backdate is too far. Probe several dates and find the TLS floor. The certificate's
`notBefore` is the limit.

### "ADB says `unauthorized`"

The data wipe removed `/data/misc/adb/adb_keys`. From TWRP (which has root), seed my
Mac's public key:

```bash
adb push ~/.android/adbkey.pub /sdcard/mac_adbkey.pub
adb shell 'mkdir -p /data/misc/adb; cp /sdcard/mac_adbkey.pub /data/misc/adb/adb_keys; chown -R root:shell /data/misc/adb; chmod 0750 /data/misc/adb; chmod 0640 /data/misc/adb/adb_keys'
```

---

## Step 5 — Propose a plan, then wait

Once you have the evidence:

1. **State the root cause** in one sentence, with the evidence that supports it.
2. **State the fix** as concrete commands.
3. **Flag anything irreversible** and wait for my explicit go-ahead before running it.
4. **Do not proceed past a stage you have not verified.** Show me the output that
   proves the stage worked.

And the one rule that overrides everything else: **never let the phone boot back into
stock Android.** If it lands there, stop and tell me — a stock boot can re-lock the
bootloader and reset the KG state.
