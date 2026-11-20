# QUICKSTART — find your path

Read this page, find the branch that matches your phone, and go to that document.

---

## Before anything else

- [ ] This phone will be **erased**. Back it up.
- [ ] You are on **macOS**. If you have Windows, the official Odin guide is easier.
- [ ] You have the device in front of you and can press three buttons and reach the
      USB cable.
- [ ] You have ~2 hours of uninterrupted time for the first attempt. The full session
      that produced this kit took 49 hours; a clean run is far shorter, but the first
      run never is.

---

## Step 0 — Which phone is this?

This kit is for the **Galaxy J4+**, codename `j4primelte`:
SM‑J415F, SM‑J415FM, SM‑J415DS, SM‑J415GN.

Check the exact model:

- **On the box or under the battery**: `SM-J415...`
- **In download mode on the Odin screen**: `PRODUCT NAME: SM-J415GN`
- **Via adb once Android is running**: `adb shell getprop ro.product.device`

**If yours is a Galaxy J4 (SM‑J410...), or a J5, J7, A3, or any other model — stop.**
The partition names, the key combos, the KG behaviour and the recovery quirks in this
kit are specific to `j4primelte`.

> The J4+ has a **capacitive home key**, not a physical one. You cannot hold it down.
> Every classic "Volume Down + Home + Power" guide on the internet is wrong for this
> device. Use **Volume Up + Volume Down + Power**.

---

## Step 1 — Diagnose before you touch anything

Read [`docs/02-diagnose-the-blockers.md`](docs/02-diagnose-the-blockers.md), then put the
phone into download mode and photograph the Odin screen.

You need three facts off that screen:

| What to look for | What it means |
|---|---|
| `OEM LOCK: ON` | Bootloader is locked. TWRP will be rejected with `FAIL! Auth`. You need the unlock path first. |
| `OEM LOCK: OFF` | Bootloader is unlocked. Good. |
| `KG STATUS: Prenormal` | A separate gate. **All** non‑Samsung binaries are refused even with `OEM LOCK: OFF`. Must be cleared. |
| No `KG STATUS:` line at all | No KG gate on this device. You can skip straight to flashing. |
| `FRP LOCK: ON` | Factory Reset Protection is active. You will need to clear it. |

Then pick your branch:

---

### Branch A — `OEM LOCK: OFF` and **no** `KG STATUS` line

Fast path. Go straight to [`docs/04-flash-twrp.md`](docs/04-flash-twrp.md).

### Branch B — `OEM LOCK: ON`

The bootloader is locked. You need to:

1. Get into stock Android (recovery → `Wipe data / factory reset` clears a forgotten
   screen lock without the password).
2. Enable **OEM unlocking** in Developer options.
3. Enter download mode and long‑press **Volume Up** to unlock the bootloader.
4. Re‑enter download mode and confirm `OEM LOCK: OFF`.

Then re‑diagnose and come back here. Full detail:
[`docs/02-diagnose-the-blockers.md`](docs/02-diagnose-the-blockers.md).

> Unlocking a bootloader on Samsung **wipes the device**. That is expected.

### Branch C — `KG STATUS: Prenormal`

This is the branch that took the longest in the original session, and it is the one
this kit exists for. Go to [`docs/03-kg-prenormal-bypass.md`](docs/03-kg-prenormal-bypass.md).

In short: the phone needs a working internet connection, then a **9‑day clock
backdate** followed by a **Software update check**, then a clock restore and a second
update check. The success marker is subtle and the docs explain it.

### Branch D — `FRP LOCK: ON`

Clear it in recovery after TWRP is installed, using LineageOS's own `wipe-frp.sh`
against the `persistent` and `config` partitions. See
[`docs/05-install-lineageos-and-gapps.md`](docs/05-install-lineageos-and-gapps.md).

---

## Step 2 — Flash, install, verify

| Stage | Document | Time |
|---|---|---|
| Flash TWRP to **BOOT and RECOVERY** | [`docs/04-flash-twrp.md`](docs/04-flash-twrp.md) | ~5 min |
| Format data, install ROM, install Google apps | [`docs/05-install-lineageos-and-gapps.md`](docs/05-install-lineageos-and-gapps.md) | ~30 min |
| First boot, verify, and what to do if it loops | [`docs/06-verify-first-boot-and-recovery.md`](docs/06-verify-first-boot-and-recovery.md) | ~15 min |

---

## Step 3 — When it goes wrong

**Go straight to [`docs/07-troubleshooting.md`](docs/07-troubleshooting.md).**

It is organised as symptom → real cause → fix, and it contains every failure that
actually happened during the original session, including the ones that were caused by
tools that looked like they were working.

Three that catch almost everyone:

| Symptom | Cause | Fix |
|---|---|---|
| `FAIL! Auth` after a full, clean transfer | Bootloader locked, or KG Prenormal active | Branch B or C above |
| TWRP flashed fine, phone still boots "Android Recovery" | Bootloader loads `BOOT`, not `RECOVERY` | Flash TWRP to BOOT too |
| Phone boots into recovery over and over | LineageOS recovery cannot clear the boot request | Restore the LineageOS `boot.img` to BOOT, or use TWRP to boot system |

---

## Things that will waste your time if you do not know them

1. **One Odin session per entry into download mode.** Samsung's Loke daemon grants a
   single protocol session per entry. A second command in the same entry fails with a
   handshake timeout that looks exactly like a broken cable. Leave and re‑enter download
   mode between commands.
2. **`--no-reboot` on every samloader command.** Without it, samloader reboots the phone
   out of download mode at the end and burns the session.
3. **Never pipe a live device session into `head` or `grep`.** SIGPIPE kills the process
   mid‑handshake and corrupts the session. Log to a file instead.
4. **`adb sideload` does not work** on this device's TWRP 3.7 or its LineageOS recovery.
   Use `adb push` + `twrp install`, or run MindTheGapps' `update-binary` directly.
5. **Never boot back into stock Android** once TWRP is installed. A stock boot can
   restore stock recovery and re‑lock the bootloader.

---

## Reference

- Verified device facts (partitions, USB IDs, key combos, checksums):
  [`docs/09-device-reference.md`](docs/09-device-reference.md)
- Hard‑won lessons and their reasoning: [`docs/08-learnings.md`](docs/08-learnings.md)
- Prompts for coding agents: [`prompts/`](prompts/)
