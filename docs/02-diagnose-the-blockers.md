# 02 — Diagnose the blockers

Do this before flashing anything. On this device there are **two independent gates**
between you and a working LineageOS, and they fail in ways that look identical.

---

## 2.1 The two gates

### Gate 1 — Bootloader lock (`OEM LOCK`)

Samsung bootloaders are locked by default. A locked bootloader will accept only
Samsung‑signed binaries. Everything else is rejected at the end of the transfer with:

```
FAIL! Auth
```

on the Odin screen, and:

```
Only officially released binaries are allowed to be flashed
```

**Critically: the transfer itself succeeds.** samloader hands over the handshake, opens
the session, reads the PIT, resolves the partition, and writes every byte — and *then*
the bootloader refuses the signature. The output looks like a success right up until the
last line. That is what makes this gate so confusing: you get a clean run that fails.

### Gate 2 — KG Prenormal (`KG STATUS`)

Even with `OEM LOCK: OFF`, a device in **KG State: Prenormal** refuses all non‑Samsung
binaries. e.foundation's wording: *"During the Prenormal period, you can NOT flash any
non‑Samsung binaries."*

This is a **separate** gate. Unlocking the bootloader does not clear it. Clearing the
bootloader lock does not clear it. It has its own procedure — see
[`03-kg-prenormal-bypass.md`](03-kg-prenormal-bypass.md).

The two gates can also be present together, which is what happened here.

> **A note on the "7 days" wording.** The 168‑hour lockout is real and widely
> described as *"7 days of uptime"*, but that is a simplification. The lockout is
> tied to the device's unlock/setup‑wizard state, and it only clears if the phone is
> **online and checks in with Samsung's servers** during that window. A phone sitting
> powered on but offline does not clear it. Keep it plugged in, on Wi‑Fi, and online.

---

## 2.2 Get into download mode

### By buttons

**Volume Up + Volume Down + Power**, hold until the screen goes black and the phone
vibrates, then release. You land on a blue warning screen; press **Volume Up** to
continue into Odin mode.

> ⚠️ **No Home button.** The J4+ has a *capacitive* home key, not a physical one, so
> you cannot hold it down. Every guide that says "Volume Down + Home + Power" is wrong
> for this device. The original session lost a lot of time to this.

Recovery / boot TWRP from download mode: hold **Volume Up + Volume Down + Power**,
release **Volume Down** when the screen goes off, keep **Volume Up + Power**.

Leave download mode / hard reset: **Volume Down + Power** for about 7 seconds.

### By adb (better)

If the phone is running Android with USB debugging enabled:

```bash
adb reboot download
```

This is the button‑free path and it is more reliable than the key combo — the physical
combo has a "Detected" screen that times out and falls back to Android.

**Download mode has no adb.** ADB only works once Android (or a recovery) is running.

### Verify

```bash
ioreg -p IOUSB -w0 2>/dev/null | grep -oE "(MSM8953|SAMSUNG_Android)@[0-9a-f]+[[:space:]]+<class IOUSBHostDevice, id 0x[0-9a-f]+" | head -1
```

| USB signature | Meaning |
|---|---|
| `MSM8953` — `0x04E8:0x685D` | Download / Odin mode |
| `SAMSUNG_Android` — `0x04E8:0x6860` | Android MTP |
| `0x18D1:0xD001` | adb (stock recovery or system) |
| `0x18D1:0x4EE2` | adb in TWRP |

---

## 2.3 Read the Odin screen

Take a photo of the Odin screen. This is the single most valuable piece of
information in the whole procedure, and reading it correctly saves hours.

> **"The Odin screen" is on the phone, not on your computer.** When a Samsung
> device is in download mode it shows a white diagnostic screen — that is what
> this document means by the Odin screen. It is *not* the Odin software, which is
> a Windows-only tool you do not need and do not have to install. This kit reads
> the same information over USB with `samloader`, and you photograph the phone's
> own screen.

A verified reading from this device:

```
ODIN MODE (HIGH SPEED)
PRODUCT NAME: SM-J415GN
CURRENT BINARY: Samsung Official
FRP LOCK: ON
OEM LOCK: OFF
KG STATUS: Prenormal
WARRANTY VOID: 0x0
QUALCOMM SECUREBOOT: ENABLE (CSB)
Only official released binaries are allowed to be flashed
```

Read it as a table:

| Line | Reading | Action |
|---|---|---|
| `OEM LOCK: ON` | Bootloader locked | Section 2.4 |
| `OEM LOCK: OFF` | Bootloader unlocked | Good — proceed |
| `KG STATUS: Prenormal` | KG gate active | [`03-kg-prenormal-bypass.md`](03-kg-prenormal-bypass.md) |
| no `KG STATUS:` line at all | Device does not report KG state | **Fast path** — skip stage 3 entirely |
| `FRP LOCK: ON` | Factory Reset Protection | [`05-install-lineageos-and-gapps.md`](05-install-lineageos-and-gapps.md) |
| `CURRENT BINARY: Samsung Official` | Normal | — |

**The decisive question is whether a `KG STATUS:` line exists at all.** If it does not,
this device does not implement KG/RMM and the whole stage‑3 ordeal is unnecessary.
That distinction is why the original session burned hours waiting for an Odin screen
photo before it could choose a path.

---

## 2.4 Unlock the bootloader (`OEM LOCK: ON`)

Unlocking a Samsung bootloader **wipes the device**. Plan for it.

### Step 1 — Get into stock Android, and clear a forgotten screen lock if needed

If you know the screen lock password, skip to step 2.

If you do **not** know it, the screen lock still blocks Developer options, and you
cannot enable OEM unlocking without reaching Settings. The way in is stock recovery:

1. Boot to recovery (from download mode: hold Volume Up + Volume Down + Power, release
   Volume Down when the screen goes off, keep Volume Up + Power).
2. In stock recovery: **Wipe data / factory reset** → confirm. This clears the screen
   lock without the password.
3. Reboot to system and complete the setup wizard.

> ⚠️ A factory reset **can reinstate** the KG Prenormal state. If the device was
> already in Prenormal, expect to deal with stage 3 regardless — and expect the phone
> to come back with no saved Wi‑Fi networks, which blocks the KG bypass until a human
> joins Wi‑Fi again.

### Step 2 — Enable OEM unlocking

On the phone:

```
Settings → About phone → Software information → tap Build number 7 times
Settings → Developer options → OEM unlocking → ON
```

> The `OEM unlocking` toggle is greyed out if the device is in KG Prenormal — that is
> another symptom of the same gate.

### Step 3 — Unlock via Odin

> **This is a device you own.** Unlocking the bootloader wipes it and voids the
> warranty. On a phone you did not buy — to resell it — this is a different
> activity with criminal consequences in many countries.

1. `adb reboot download` (or the button combo).
2. On the Odin warning screen, press and **hold Volume Up** for several seconds.
   The screen shows *"Volume up and long press: Device unlock mode."*
3. The phone vibrates and the screen changes — the bootloader is now unlocked and the
   device is wiped.

> In the original session, long‑pressing Volume Up did nothing while the KG gate was
> active. It only worked **after** OEM unlocking was enabled and the KG state was
> cleared. If long‑press does nothing, do not assume the cable or the button is at
> fault — check the KG state first.

### Step 4 — Confirm

Re‑enter download mode and check that the Odin screen now reads `OEM LOCK: OFF`.

---

## 2.5 Capture the device's own facts

Do not trust a table on the internet; read it off your device.

```bash
cd ~/Desktop/j4-flash
./samloader-longtimeout detect --verbose
```

Verified output from this device:

```
Model: SM-J415GN
Serial: CXXXXXXXXXX
Bootloader: J415GNDXS6BVJ1
Sales Code: TGY
```

Note the **bootloader build string** (`J415GNDXS6BVJ1`). The stock firmware you flash
must match it exactly, or the phone may reject it.

---

## 2.6 Checklist before you flash

- [ ] Model confirmed as `j4primelte` (SM‑J415F/FM/DS/GN)
- [ ] Odin screen read and photographed
- [ ] `OEM LOCK: OFF`
- [ ] `KG STATUS:` line absent, **or** the stage‑3 bypass is planned
- [ ] `FRP LOCK` state known
- [ ] Phone has working internet (needed for stage 3)
- [ ] ADB authorised with **"Always allow from this computer"** ticked
- [ ] TWRP image downloaded and **both** checksums verified
- [ ] ROM and MindTheGapps downloaded and sizes verified
- [ ] `samloader` built with the handshake timeout patch
- [ ] You have read [`QUICKSTART.md`](../QUICKSTART.md) and you are ready to let the
      phone be erased

---

Next: [`03-kg-prenormal-bypass.md`](03-kg-prenormal-bypass.md) (if needed), then
[`04-flash-twrp.md`](04-flash-twrp.md).
