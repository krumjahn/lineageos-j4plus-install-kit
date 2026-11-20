# 03 — Bypassing KG State: Prenormal

This is the stage that took the longest in the original session — roughly a day of it.
It is also the reason this kit exists, because the obvious guide (the XDA "How to bypass
KG State and/or RMM state prenormal" thread) does not mention the two things that
actually broke it here.

If your Odin screen shows **no `KG STATUS:` line**, skip this document entirely.

---

## 3.1 What you are actually doing

A device in KG Prenormal will only accept Samsung‑signed binaries. The bypass works
because Samsung's update server records "this device checked for updates successfully
at time T" against the device's clock. Move the clock back, check for updates, move the
clock forward, check again, and the server's record is now more than seven days old —
which is the threshold that clears the Prenormal state.

The method needs **no SIM card** and **no Google account**. Both are optional
according to Samsung's own Odin documentation ("either by WiFi or Mobile Data"). That
matters, because the practical route to getting a device past this gate usually
involves accounts you do not want to create.

### The sequence

```
1. Internet OFF
2. Clock back 9 days
3. Reboot
4. Internet ON
5. Software update check  →  success marker appears against the FAKE date
6. Internet OFF
7. Reboot
8. Clock back to real time
9. Internet ON
10. Software update check  →  success marker appears against the REAL date
11. Reboot
12. Developer options → "OEM unlocking: Bootloader already unlocked"
    Odin screen → KG STATUS: Checking, or the line is gone
```

Two checks, not one. The first check registers the backdated timestamp; the second
registers it as historical rather than current.

---

## 3.2 The two faults that break it

### Fault 1 — The phone has no internet

**Symptom:** the software update check returns
`Can't check for update — Updates are temporarily unavailable.` Every time.

**Cause:** a factory reset wipes all saved Wi‑Fi networks. The phone is on Wi‑Fi but
disconnected, so `ping 8.8.8.8` gives `Network is unreachable` and `ping google.com`
gives `unknown host`.

**Why you cannot script it:** on Android 9's shell, `cmd wifi` requires root and
`cmd netpolicy` has no add-network operation. There is no shell route to join a
network on an unrooted stock device.

**Fix — this needs a human, once:**

```
Settings → Wi‑Fi → select your network → enter the password
```

Confirm on the phone before continuing:

```bash
adb shell ping -c 2 8.8.8.8
adb shell ping -c 2 google.com
```

Both must resolve.

> In the original session this was the blocking physical step: the automation was
> fully written and ready, and the whole stage was dead until someone picked up the
> phone and joined the Wi‑Fi. It is the only step in the entire procedure that cannot
> be automated away.

### Fault 2 — TLS has a hard floor on how far back you can go

**Symptom:** with the clock set back, every HTTPS request fails. `curl` reports
`ssl=9`; the phone says `certificate is not yet valid`. The update check fails with a
network error even though the internet is working.

**Cause:** a backdated clock breaks every TLS handshake. The certificate chain is
valid from a fixed `notBefore` date — and if your fake date is *older* than
`notBefore`, every certificate looks "not yet valid" and the connection cannot be
established.

On the date this was done, Google's certificate chain was valid from
`notBefore = Nov 3 2026 08:29:37 GMT` to `notAfter = Jan 26 2027`.

**The probe that found it.** Each candidate backdate was tried and the TLS handshake
was checked:

| Fake date | Days back | TLS result |
|---|---|---|
| Oct 29 | 15 | ❌ fail |
| Oct 22 | 22 | ❌ fail |
| Nov 1 | 12 | ❌ fail |
| Nov 2 | 11 | ❌ fail |
| Nov 3 | 10 | ❌ fail |
| **Nov 4** | **9** | ✅ **success** |
| real clock (control) | 0 | ✅ success |

**Fix:** back up **9 days**, and no further. Nine satisfies the method's "more than
seven days" requirement and sits just inside the TLS window.

> The window moves. Every day that passes, `notBefore` stays where it is and the
> number of days you can go back *shrinks by one*. If your probe shows Nov 4 failing,
> check whether the certificate has been renewed, and probe again. If the required
> window has closed entirely — you would need to go back more than 7 days but TLS
> refuses — that is the point where the paid Windows tools (ChimeraTool, HydraTool)
> or the 168‑hour uptime wait become the practical options.

---

## 3.3 The third fault: how you know it worked

**Symptom:** the update check appears to succeed, but the KG state does not clear.

**Cause:** the success marker was read wrong, or the wrong UI element was tapped.

Samsung renders the stored check time differently depending on whether the stored date
matches the device's current date:

| Stored date | On screen |
|---|---|
| Same day as the device's clock | `Last successful check for update at HH:MM` |
| Older | `Last successful check for update on Nov 13` |

So a successful **backdated** check must read **`at HH:MM`**. A line reading
`on Nov 13` is a *false positive* — it is showing a stale check from the real date, not
your new one. Matching the substring `on Nov` against the wrong date will convince you
it worked when it did not.

> In the original session, the automation matched the **summary line** ("Last
> successful check for update on Nov 13") instead of the **Check for update button**,
> clicked the wrong thing, and reported success. The UI driver was rewritten to score
> candidate elements — exact text +100, clickable +40, `resource-id` containing
> `button` +25, shorter text preferred — and it then found the real button
> (`match "Check for update" (score 142) -> "Check for update" @ (554,1333)`).
> That scorer is included as [`scripts/adb-ui.py`](../scripts/adb-ui.py).

---

## 3.4 Running it

### Set the clock

`adb shell date` does **not** work on this build (`bad date`, or a silent no-op). The
working method is the alarm service:

```bash
# 1. turn off automatic time
adb shell settings put global auto_time 0

# 2. set the clock to 09:00 on the target backdate
#    epoch milliseconds, computed on the Mac
FAKE=$(TZ=UTC date -j -f "%Y-%m-%d %H:%M:%S" "2026-11-04 04:00:00" "+%s")
adb shell cmd alarm set-time $((FAKE * 1000))

# 3. verify
adb shell date
```

**The fake date must survive a reboot.** In the original session it did — with
`auto_time=0`, the backdated clock persisted across every reboot, which is what makes
the sequence work at all. Verify this explicitly after your first reboot; if the clock
snaps back to real time, the check will register against the real date and the whole
procedure fails silently.

### Drive the update check

```bash
# keep the screen alive and unlocked
adb shell settings put system screen_off_timeout 1800000
adb shell svc power stayon true
adb shell input keyevent 224        # KEYCODE_WAKEUP
adb shell wm dismiss-keyguard

# open the software update page
adb shell am start -a android.settings.SYSTEM_UPDATE_SETTINGS

# list the visible text so you can find the button
python3 ../scripts/adb-ui.py texts

# tap it (the scorer picks the button, not the summary line)
python3 ../scripts/adb-ui.py tap-any "Check for update|Download and install|..."
```

When the check succeeds, Samsung sometimes offers an update. **Choose "LATER" — do not
install it.** Installing an update during the backdated window would set the clock and
the check date to something else entirely.

### Repeat for the second check

After the first successful check:

```
internet OFF → reboot → clock back to real time → internet ON → check again → reboot
```

Verify the marker now reads `at HH:MM` against the **real** date.

### Confirm

- Developer options shows **"OEM unlocking: Bootloader already unlocked"**.
- The Odin screen shows `KG STATUS: Checking`, or the `KG STATUS:` line is gone.

Then flash TWRP.

---

## 3.5 If it does not work

| Symptom | Likely cause | Action |
|---|---|---|
| Update check fails, no network error | Phone has no internet | Section 3.2 fault 1 — join Wi‑Fi by hand |
| Update check fails with a certificate error | Backdate too far | Section 3.2 fault 2 — probe, reduce the backdate |
| Marker reads `on Nov 13` | Matched the stale summary line | Section 3.3 — use `at HH:MM` |
| Marker correct but KG still Prenormal | Check did not stick, or the clock snapped back on reboot | Verify the fake date survived the reboot |
| Second check fails | Clock not restored, or phone lost internet | Re‑verify both |

**The fallbacks** (and their honest costs):

- **The 7-day / 168-hour lockout window.** The phone must stay **online and checking
  in with Samsung's servers** for the duration. This is tied to the device's
  unlock/setup-wizard state, not to a simple uptime counter, so a phone left powered
  on but offline will not clear it. Keep it on Wi‑Fi, powered on, and online. Costs a
  week of wall-clock time, but no money and no Windows.
- **ChimeraTool / HydraTool** on Windows. Costs money and a Windows machine, but it is
  fast and it does not depend on a TLS window.
- **RMM bypass zip from TWRP** — circular while KG is closed, because you need TWRP
  to flash the zip and you cannot flash TWRP while KG is closed. It was used in the
  original session as a later belt‑and‑braces step, not as the primary unlock.

---

Next: [`04-flash-twrp.md`](04-flash-twrp.md)
