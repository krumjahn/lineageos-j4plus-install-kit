# 08 — Learnings

What was actually hard about this, why, and what a second attempt should do differently.
This is the part of the kit that survives even when the exact ROM link dies.

---

## 8.1 The shape of the problem

The request sounds like one task. It was four gates in series, each of which can fail
in a way that looks like the previous one failed:

```
locked bootloader  →  KG Prenormal  →  TWRP in the wrong partition  →  ROM install
                                                                     →  GApps
                                                                     →  recovery loop
```

Every one of them presents as *"the flash failed"*. That is the real difficulty. There
is no single error message; there is a chain of gates, and the symptoms overlap.

**The single most valuable thing you can do is read the Odin screen and photograph it.**
That one image would have collapsed several of these gates into a single decision. It
took hours to get, because it seemed like an obvious request that did not need to be
asked for urgently.

---

## 8.2 What cost the most time

### 1. `FAIL! Auth` looks like a flash failure and is not

The transfer completes. Every byte is acknowledged. The log looks like a success until
the last line. This is the perfect failure: the output says "OK" right up until it
says "no".

**Lesson:** when a flash fails, check *where* it failed. A failure at the very end,
after all data transferred, is an authorisation problem — go look at the bootloader
state, not at your tooling.

### 2. One Odin session per entry into download mode

This produced hours of phantom hardware faults. The phone was not wedged. The cable was
not broken. The tool had been rebooting the phone out of download mode after every
command, and each subsequent command was timing out against a dead session.

**Lesson:** the protocol's session model is part of the device's behaviour, not part of
the flasher. Learn it before you start, and make your first device command the one you
care about. Detection via `ioreg` rather than via a device command removes an entire
class of self‑inflicted failure.

### 3. The TWRP flash that worked perfectly and did nothing

Two clean flashes to `RECOVERY`, and the phone booted Samsung's stock recovery anyway.
The disproof took real work: extracting the compressed ramdisk from the TWRP image and
string‑searching it for `TeamWin` versus `Black Screen` / `Android Recovery`.

**Lesson:** "the flash reported success" and "the flash did what you wanted" are
different claims, and only the second one matters. On this device the bootloader loads
`BOOT`; `RECOVERY` is decoration.

### 4. The KG bypass, and the TLS wall

The published method — backdate the clock, check for updates — is correct and it works
without a SIM or a Google account, which is genuinely useful. But it has a dependency
nobody mentions: **backdating the clock breaks TLS**, and the distance you can travel
backwards is bounded by the certificate's `notBefore`.

The method needs "more than 7 days". TLS allowed exactly 9. That was the margin.

**Lesson:** the two constraints (minimum backdate, maximum backdate) meet in a narrow
window that has to be *measured*, not assumed. A probe script that tests several
dates and reports which ones complete a TLS handshake is worth more than any amount of
reading.

### 5. The one step no automation can replace

The factory reset wiped the saved Wi‑Fi networks. Android 9's shell cannot add one.
The entire KG bypass was blocked on a human picking up the phone and typing a Wi‑Fi
password.

**Lesson:** identify the human‑in‑the‑loop steps early and sequence around them. The
scripted parts were ready hours before the physical part was done.

### 6. The recovery loop, and why pstore mattered

The phone kept booting into the LineageOS recovery. The obvious hypothesis was
"installing Google apps broke the system" — and that hypothesis is wrong, and acting on
it would have wasted a lot of time.

Two checks settled it: `pstore/console-ramoops` had **zero** hits for `zygote`,
`system_server`, `boot_completed` or `apexd` (the system never tried to boot), and
`/dev/block/by-name/misc` read back all zeros (no stale boot request). The actual
cause was in the recovery's own log the whole time: it never creates
`/dev/block/bootdevice/by-name/`, so it can never clear the boot request.

**Lesson:** before blaming the most recent thing you changed, get evidence about
whether it was even reached. Two file reads settled what hours of guesswork would not.

---

## 8.3 Things that turned out to be non‑issues

Worth recording, because each one looked important:

- **`no-verity-opt-encrypt`** — not needed (no `vbmeta` partition), and broken anyway.
- **The RMM bypass zip** — unnecessary for a LineageOS build; there is no
  `vaultkeeper`, `Rlc` or `KnoxGuard` in LineageOS to patch. It was installed anyway
  and then overwritten by the ROM install.
- **`vendor`** — deliberately empty. This ROM carries `vendor` inside `system`, and
  `fstab.qcom` has no `/vendor` mount. Not a bug.
- **macOS's "Samsung Smart Switch must be installed" MTP error** — harmless; ADB does
  not need it.
- **The phone having no SIM** — irrelevant. The KG bypass does not need one.

---

## 8.4 What would be faster next time

If you are doing this again, in order of expected time saved:

1. **Photograph the Odin screen before touching anything.** One image answers "is the
   bootloader locked", "is KG Prenormal active", and "is FRP locked" at once.
2. **Know that this device loads `BOOT`.** Flash TWRP to both partitions the first
   time, every time.
3. **Measure the TLS floor before you start the KG bypass.** One probe script, five
   candidate dates, one minute — instead of discovering the boundary by failure.
4. **Join Wi‑Fi immediately after any factory reset.** Everything downstream of the KG
   bypass depends on it, and it needs a human.
5. **Build samloader with the long handshake timeout from the start.** Stock samloader
   on a slow handshake produces a convincing "dead cable" message.
6. **Seed the ADB key into `/data` from TWRP** immediately after formatting. It removes
   every authorisation prompt from then on.
7. **Keep `romx/boot.img` and `twrp.img` on the SD card** before rebooting. They are
   the fastest way out of any recovery problem.
8. **Do not pipe device output into `head`.** Log to a file. It costs one extra
   command and removes a whole class of session corruption.
9. **Never boot stock.** Write it on a sticky note. It is the only irreversible
   mistake in the whole procedure.

---

## 8.5 On using an agent for this

Working with a coding agent on a device‑flashing task was a good fit, with three
caveats that the prompts in this kit encode:

**Good:** an agent can hold the entire protocol model in its head — the session rules,
the partition map, the failure taxonomy — while a human does the six things that need
a human: photographing a screen, reading an Odin display, joining Wi‑Fi, confirming a
factory reset, tapping through a recovery menu, and deciding whether to continue.

**Caveat 1 — the agent cannot see the phone.** Every observation must be relayed. An
agent that assumes the phone did what the log says will confidently proceed into the
next stage while the phone is showing an error. The prompts require a human read of
the physical screen before each irreversible step.

**Caveat 2 — irreversible steps need a checkpoint, not a prompt.** "Format data" and
"wipe" are the kind of thing an agent will execute without asking if the instruction
says "install LineageOS". The prompts make the agent stop and get an explicit go.

**Caveat 3 — the evidence lives in logs, not in the conversation.** The decisive
discoveries in this session — the TLS floor, the recovery‑loop root cause, the
`BOOT`-vs-`RECOVERY` finding — all came from pulling a file and reading it. An agent
that skips the verification step will produce a confident, wrong answer. The prompts
require verification before proceeding.

---

## 8.6 The meta‑lesson

Almost none of the difficulty was "flashing LineageOS is hard". It was **diagnosing a
device that reports its problems inaccurately**.

- `FAIL! Auth` means "I did not like your signature", not "your transfer broke".
- A handshake timeout means "my session is spent", not "your cable is broken".
- A flash that reports success may have written to a partition nobody reads.
- A phone that boots the wrong thing may be working perfectly.
- A check that reports success may have registered against the wrong date.

Every one of those cost hours. The habit that fixed all of them was the same: **stop
inferring from symptoms, go read the device.** Dump the PIT. Read the Odin screen.
Pull the pstore log. Check the timestamps.

That is the transferable part, and it is why this kit is worth more than a list of
commands.

---

Next: [`09-device-reference.md`](09-device-reference.md)
