# Agent brief — Galaxy J4+ / LineageOS 19.1

> **Paste this at the start of your session with the agent, before anything else.**
> It is a reference, not a task. Follow it for the rest of the conversation.

---

You are helping me flash a **Samsung Galaxy J4+** onto **LineageOS 19.1 (Android 12L)**
from **macOS on Apple Silicon**, using **`samloader`** — no Odin, and no Windows PC
required.

Two different machines are involved, and keep them straight:

- **The phone** currently runs **Samsung's stock Android** (Samsung's build of
  Android 8.1, with Knox). That is the thing being replaced.
- **My computer** is macOS, and it is what talks to the phone over USB. It does not
  need to be Windows and does not need Odin.

Read everything below before you act. It contains facts I have verified on this device
and rules that exist because ignoring them cost hours.

---

## 1. Hard safety rules

1. **Never let the phone boot back into stock Android** once TWRP is installed in
   `BOOT`. A stock boot can restore stock recovery, re-lock the bootloader, and reset
   the KG state — putting us back at the start.
2. **Before any irreversible action** (formatting `data`, wiping the device, unlocking
   the bootloader), **stop and tell me exactly what you are about to do and wait for my
   explicit go-ahead**. Do not bundle it with other steps.
3. **Never perform a destructive filesystem operation on a block device** without my
   confirmation — that includes `dd` to `/dev/block/...`, `mkfs`, and `twrp format data`.
   If you need it, give me the exact command and let me run it.
4. **Do not delete anything** without telling me what and why first. No `rm -rf` on my
   machine.
5. **Do not install or download anything from a link you have not shown me first.**
   Check the checksum against the reference in section 6 before I use any file.
6. **If you are unsure whether something worked, verify it.** Do not proceed to the next
   stage on a guess. Read a file, run a command, look at the output.

---

## 2. Protocol rules — these are not in any documentation

7. **One download-mode entry = one protocol session.** Samsung's Loke daemon grants a
   single session per entry into download mode. A second command in the same entry
   fails with a handshake timeout that looks exactly like a dead cable.
   → **Make the flash the FIRST device command of each session.**
8. **Always pass `--no-reboot`** to samloader, unless I explicitly want the reboot.
   Without it, samloader reboots the phone, which ends the session and can boot stock.
9. **Never pipe a live device session into `head` or `grep`.** SIGPIPE kills samloader
   mid-handshake and corrupts the session. Redirect to a log file, then read the file.
10. **Detect the phone with `ioreg`, never with a samloader subcommand.**
    `ioreg` cannot consume a session; `samloader detect` can.
11. **Never edit a script while it is running.** The shell reads scripts by byte offset;
    rewriting one corrupts it. Write a new file and restart the task.
12. **If a command touches the device, log its output to a file** and show me the
    relevant lines afterwards — do not truncate the stream.

---

## 3. The two independent gates

The flash fails for two completely different reasons, and they can be present at the
same time. Do not conflate them.

**Gate 1 — bootloader lock (`OEM LOCK`).**
Symptom: the flash transfers the whole image cleanly, then Odin shows `FAIL! Auth` and
*"Only officially released binaries are allowed to be flashed"*.
Cause: the bootloader only accepts Samsung-signed binaries.
Fix: unlock it (Developer options → OEM unlocking → long-press Volume Up in Odin).
**The transfer succeeding and the flash still failing is the signature of this gate —
do not start debugging the flasher.**

**Gate 2 — KG State: Prenormal.**
Symptom: `OEM LOCK: OFF` but the Odin screen shows `KG STATUS: Prenormal`. All
non-Samsung binaries are still refused.
Cause: a separate server-side lockout tied to the device's unlock/setup state. It
clears only if the phone is **online and checks in with Samsung's servers** during a
7-day window — it is not merely an uptime counter.
Fix: the clock-backdate + software-update-check trick (section 4).

**Read the Odin screen and photograph it before anything else.** One photograph answers
"is the bootloader locked", "is KG Prenormal active" and "is FRP locked" at once. This
is the single highest-value action available.

---

## 4. KG Prenormal bypass — the details you need

The method (XDA, *"How to bypass KG State and/or RMM state prenormal"*):
internet off → clock back → reboot → internet on → software update check → reboot →
clock restored → internet on → second check → reboot. No SIM and no Google account
needed.

Two things break it, both of which cost me hours:

**(a) The phone must have internet.** A factory reset wipes every saved Wi‑Fi network,
and Android 9's shell cannot add one (`cmd wifi` needs root; `cmd netpolicy` has no
add-network operation). **I have to join Wi‑Fi by hand on the phone.** If the update
check fails with *"Can't check for update — Updates are temporarily unavailable"*, that
is almost certainly it. Verify with `adb shell ping -c 2 8.8.8.8`.

**(b) TLS puts a hard floor on the backdate.** A backdated clock breaks every TLS
handshake — `curl: ssl=9`, "certificate is not yet valid". The certificate's
`notBefore` is the limit. When I did this, `notBefore` was `Nov 3 2026 08:29:37 GMT`,
and the measured result was:

| fake date | days back | TLS |
|---|---|---|
| Nov 3 | 10 | fail |
| **Nov 4** | **9** | **success** |
| real clock | 0 | success (control) |

So: **back up exactly 9 days, no further** — 9 satisfies the "more than 7 days"
requirement and sits just inside the TLS window. **Probe before you commit**, because
the window shifts as certificates renew.

**Success detection.** Samsung renders the stored check time as
`Last successful check for update at HH:MM` when the stored date equals the device's
current date, and `... on Nov 13` when it is older. A successful *backdated* check
must read **`at HH:MM`**. `on Nov 13` is a stale check and a false positive.

**Setting the clock:** `adb shell date ...` does not work on this build (`bad date` or
a silent no-op). Use:

```bash
adb shell settings put global auto_time 0
adb shell cmd alarm set-time <epoch_millis>
```

The fake date must survive a reboot — verify that explicitly.

---

## 5. Device facts — verified on this hardware

**Identity**

| | |
|---|---|
| Model | `SM-J415GN` (codename `j4primelte`) |
| Serial | `CXXXXXXXXXX` |
| Bootloader build | `J415GNDXS6BVJ1` |
| Sales code | `TGY` |
| SoC | Snapdragon 425 (MSM8937) |
| Battery | **non-removable** |
| Home key | **capacitive — cannot be held** |

**Key combinations** (there is **no physical Home button**, so the classic
"Volume Down + Home + Power" is wrong for this device):

| Action | Combination |
|---|---|
| Download / Odin mode | **Volume Up + Volume Down + Power**, then **Volume Up** |
| Download mode (no buttons — preferred) | `adb reboot download` |
| Unlock bootloader | hold **Volume Up** on the Odin warning screen |
| Recovery from download mode | hold **Vol Up + Vol Down + Power**, release **Vol Down** when the screen goes off, keep **Vol Up + Power** |
| Hard reset | **Volume Down + Power** ~7–10 s |

**USB signatures**

| Mode | VID:PID | ioreg |
|---|---|---|
| Download/Odin | `0x04E8:0x685D` | `MSM8953` |
| Android MTP | `0x04E8:0x6860` | `SAMSUNG_Android` |
| adb in TWRP | `0x18D1:0x4EE2` | `SAMSUNG_Android` |

Download mode has **no ADB**.

**Partitions** (from the device's own PIT — project `COM_TAR2`, 57 entries, 512-byte
blocks):

| Partition | ID | by-name |
|---|---|---|
| `BOOT` | 23 (`0x17`) | `mmcblk0p23` |
| `RECOVERY` | 24 (`0x18`) | `mmcblk0p24` |
| `SYSTEM` | 47 (`0x47`) | `mmcblk0p47` |
| `VENDOR` | 48 | `mmcblk0p48` |
| `ODM` | 49 | `mmcblk0p49` |
| `CACHE` | 50 | `mmcblk0p50` |
| `USERDATA` | 53 | `mmcblk0p53` |
| `PERSIST` | 31 | — |
| `BOTA` | 26 | `mmcblk0p26` |
| `MISC` | 33 | `mmcblk0p33` |

**There is no `vbmeta` partition.** That is why `no-verity-opt-encrypt` is unnecessary.

---

## 6. The facts that will trip you up

**a) The bootloader loads `BOOT`, not `RECOVERY`.**
I flashed TWRP to `RECOVERY` twice — both flashes perfectly clean — and the phone still
booted Samsung's stock recovery. **Flash TWRP to BOOT *and* RECOVERY, in one
session.** And note that `adb reboot recovery` boots the ROM's own embedded recovery,
not the `RECOVERY` partition.

**b) The ROM is 32-bit ARM, not ARM64.**
`ro.product.cpu.abi=armeabi-v7a`, `ro.zygote=zygote32`. The `msm8953_64` string in
`fstab.qcom` is a device-tree copy-paste artifact. **MindTheGapps 12.1.0 ARM**, not
arm64; not 13.0.0 (that is for LineageOS 20).

**c) The LineageOS recovery cannot clear the boot request.**
It creates only `/dev/block/platform/soc/7824900.sdhci/by-name/` but the bootloader
writes the request to `/dev/block/bootdevice/by-name/misc`:

```
E:Failed to clear BOB message: failed to open /dev/block/bootdevice/by-name/misc
init: reboot-bootloader: Error writing bootloader_message: failed to stat /dev/block/bootdevice/by-name/misc try 1..10
```

So "Reboot system now" from that recovery just returns to the recovery. TWRP *does*
create that path, which is why TWRP can always boot the system. **Before blaming the
ROM or the GApps, check the evidence:**

```bash
adb pull /sys/fs/pstore/console-ramoops pstore-console.log
grep -E "zygote|system_server|boot_completed|apexd" pstore-console.log
```

Zero hits means the system never attempted to boot — the fault is upstream of the
system.

**d) `adb sideload` does not work here.** TWRP 3.7 gives
`sideload connection failed: closed`; the LineageOS recovery gives
`device unauthorized`. Use `adb push` + `twrp install`, or run MindTheGapps'
`update-binary` directly.

**e) Use "Format data", not "Wipe data".** Samsung encryption is not supported by TWRP
on this device.

**f) The working directory may be gone.** I may be recreating it; if `~/Desktop/j4-flash`
does not exist, create it and tell me where you put things.

---

## 7. Checksums — verify every download

| File | Hash | Value |
|---|---|---|
| `twrp-3.7.0_j4primelte.img` | sha256 | `7dabdee3b26dd5781593690f61a927630d14e3fd61233c2894666029ee518632` |
| `twrp-3.7.0_j4primelte.img` | md5 | `0be9a3683a81fc8d255953e94bb77ae9` |
| ROM `boot.img` | md5 | `8dbc48b893e4f52c42579ad6f870dadc` |
| `RMM_Bypass_v3_corsicanu.zip` | md5 | `056eeebb2d6c59bc8d975f0ba2349eb2` |
| `RMM_Bypass_v3_corsicanu.zip` | sha256 | `42ec18878d336a7b0927bb87251bb548e020d4faa052679abe2ae0402b643bfc` |

**The original LineageOS ROM link is dead** (the XDA thread was closed in Aug 2026).
The currently maintained line is
[“REVIVE OS ‖ J4 PLUS ‖ UNOFFICIAL”](https://xdaforums.com/t/revive-os-j4-plus-unofficial-nov-2026.4766304/)
— ROM `ReviveOS_FinalBuild.zip` at
<https://drive.google.com/file/d/1XT7wSyXTs7ncYr7GkyJxMrpT-rW69Rqi/view?usp=drivesdk>.
Check that thread's stated Android version and architecture before choosing the GApps
package.

---

## 8. How to work with me

- **You cannot see the phone.** When a decision depends on what is on screen, ask me
  for a photo or a description, and wait for it.
- **Give me one screen's worth of detail at a time** — a photo of the Odin screen, a
  photo of the recovery menu, the output of one command.
- **Read the output.** If a command produces output, quote the relevant lines back to
  me. Do not summarise it as "it worked" unless the output actually says so.
- **When you are blocked, say so plainly** and tell me what you need from me. Do not
  try three workarounds in a row and then present it as progress.
- **Do not be afraid to say "I don't know."** I would much rather have a clear "this is
  not a known failure mode, here is what I would check next" than a confident guess.
