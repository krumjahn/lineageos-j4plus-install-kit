# 08 — Why the procedure is shaped this way

Optional background. Everything actionable is in
[`07-troubleshooting.md`](07-troubleshooting.md) — this page only explains the shape
of the thing, for when you want to know why a rule exists.

---

## It is four gates, not one task

```
locked bootloader  ->  KG Prenormal  ->  TWRP in the wrong partition  ->  recovery loop
```

Each presents as *"the flash failed"*. That is the real difficulty: there is no
single error message, there is a chain, and the symptoms overlap. The single most
valuable thing you can do is read the Odin screen and photograph it — one
photograph answers "is the bootloader locked", "is KG active" and "is FRP locked"
at once.

---

## Five rules that exist because of one specific failure

| Rule | The failure that created it |
|---|---|
| `--no-reboot` on every samloader command | The default reboot took the phone out of download mode and burned the session, so every later command timed out and it looked like a dead cable |
| The flash is the **first** device command in a session | A detection command consumed the only session, then the real flash failed for no visible reason |
| Detect with `ioreg`, never with a samloader subcommand | `samloader detect` consumes a session; `ioreg` cannot |
| Never pipe a live session into `head` | SIGPIPE killed samloader mid-handshake and corrupted the session |
| Flash TWRP to **BOOT and RECOVERY** | Two flawless flashes to `RECOVERY` did nothing, because this bootloader reads `BOOT` |

---

## Two things that looked like software bugs and were not

- **The phone had no internet** because a factory reset wiped every saved Wi‑Fi
  network, and Android 9's shell cannot add one. The KG bypass needs the update
  server, so the whole stage was blocked on a human typing a Wi‑Fi password.
- **The 168-hour KG lockout is not an uptime counter.** It is tied to the
  device's unlock/setup state and only clears if the phone is online and checking
  in with Samsung's servers. A phone powered on but offline does not clear it.

---

## If you did it again

1. **Photograph the Odin screen before touching anything.** Biggest single time
   saver.
2. **Flash TWRP to both partitions in the first session** — you need `BOOT`
   anyway, and doing it twice costs another session.
3. **Probe the TLS floor before starting the KG bypass.** One script, five
   candidate dates, a minute. The method wants more than 7 days back; TLS
   allowed exactly 9.
4. **Join Wi‑Fi immediately after any factory reset**, before you need the
   network.
5. **Seed the ADB key into `/data`** from TWRP right after formatting. It
   removes every authorisation prompt for the rest of the job.
6. **Stage `romx/boot.img` and the TWRP image on the SD card** while you still
   have a recovery. They are the fastest way out of anything.
7. **Install GApps from the LineageOS recovery** using MindTheGapps' own
   `update-binary`, instead of reflashing TWRP into `BOOT` and back again.
8. **Never boot stock.** Write it on a sticky note. It is the only irreversible
   mistake available.

---

## The transferable habit

Almost none of the difficulty was *"flashing LineageOS is hard"*. It was
diagnosing a device that reports its problems inaccurately:

- `FAIL! Auth` means *"I did not like your signature"*, not *"your transfer broke"*.
- A handshake timeout means *"my session is spent"*, not *"your cable is broken"*.
- A flash that reports success may have written to a partition nobody reads.
- A phone that boots the wrong thing may be working perfectly.
- A check that reports success may have registered against the wrong date.

Every one of those cost hours. The habit that fixed all of them was the same:
**stop inferring from the symptom and go read the device.** Dump the PIT. Read
the Odin screen. Pull the crash log. Check the timestamps.
