# LineageOS 19.1 on the Samsung Galaxy J4+

Replace **Samsung's stock Android** on a 2018 Galaxy J4+ (`SM‑J415F` /
`SM‑J415GN`, codename `j4primelte`) with **LineageOS 19.1** — flashed from your
**Mac** with `samloader`.

Verified on real hardware — **13 November 2026, 49 hours from first attempt to a
working phone**, including every failure along the way.

> **Two different machines are involved, and "no Windows" is about one of them.**
>
> - **The phone** runs Samsung's stock Android right now — Samsung's own build of
>   Android 9 Pie (One UI 8.0), with Knox, Samsung Cloud and the rest. *That* is
>   what LineageOS replaces.
> - **Your computer** is what talks to the phone over USB. This kit does it from
>   macOS with a command-line tool called `samloader`, so you do **not** need a
>   Windows PC, and you do **not** need Odin or a Samsung account on your PC.
>
> If you do have a Windows PC, `samloader` ships a Windows build and needs no Odin
> and no Zadig driver there either — see [`docs/01`](docs/01-prerequisites-and-downloads.md).
> Nothing here requires Windows; this kit simply was never run on one.
>
> One more piece of vocabulary, because it trips people up constantly: **"the
> Odin screen" is on the phone.** In download mode the J4+ shows a white
> diagnostic screen (`OEM LOCK:`, `KG STATUS:`, …). That is what this kit means by
> the Odin screen, and it is not the Odin *software* — a Windows-only tool you do
> not need.

---

## Three ways in

### A — Run it

```bash
git clone https://github.com/krumjahn/lineageos-j4plus-install-kit
cd lineageos-j4plus-install-kit
./install.sh
```

`install.sh` drives the whole procedure and **stops and asks** at the three points
where a human is genuinely required: reading the Odin screen, joining Wi‑Fi, and
confirming the wipe. It is resumable — if anything interrupts it, run it again and
it picks up where it left off.

Not sure where you are?

```bash
./install.sh --status      # read-only report: USB mode, adb, files, progress
```

### B — Let an AI do it

Copy [`prompts/PASTE-THIS.md`](prompts/PASTE-THIS.md) into Claude Code, Codex,
Cursor, Aider, OpenCode, or any chat window with a capable model.

The prompt carries the device facts, the protocol rules and the safety rules, so
the agent does not have to rediscover them — and it tells the agent to stop and
ask you before anything irreversible.

There are more specialised prompts in [`prompts/`](prompts/) if you want to drive
one stage at a time.

### C — Read it

Start at [`QUICKSTART.md`](QUICKSTART.md) — a decision tree that tells you which
branch you are on. The full manual is in [`docs/`](docs/).

---

## Before you start

You need four things. Full details and download URLs in
[`docs/01-prerequisites-and-downloads.md`](docs/01-prerequisites-and-downloads.md).

| | |
|---|---|
| **A Galaxy J4+** | `SM‑J415F` / `SM‑J415FM` / `SM‑J415DS` / `SM‑J415GN`. Nothing else — the partition map and the recovery quirks are device-specific. Ships with Samsung's stock Android, which is what gets replaced. |
| **A Mac** | macOS on Apple Silicon (Intel works too) — this is the computer you flash *from*. `brew install android-platform-tools` |
| **samloader** | The flasher. A prebuilt binary from [the releases page](https://github.com/topjohnwu/samloader-rs) works on macOS, Linux and Windows. On the Windows build it needs **no Odin and no Zadig** either. |
| **Three files** | `twrp-3.7.0_j4primelte.img`, a LineageOS 19.1 ROM, `MindTheGapps-12.1.0-arm-20231025_200802.zip` |

**Everything gets wiped.** Back up first. Do not start on the only phone you own.

---

## The three things that go wrong

Almost everyone hits these. The full catalogue is
[`docs/07-troubleshooting.md`](docs/07-troubleshooting.md) — a searchable Q&A.

**1. `FAIL! Auth`, after a perfectly clean transfer.**
The flash worked. The bootloader refused the signature because it is locked, or
because the device is in **KG State: Prenormal** — a separate gate that refuses
all non-Samsung binaries even with `OEM LOCK: OFF`. Read the Odin screen; one
photograph tells you which.

**2. TWRP flashed with zero errors, and the phone booted stock recovery anyway.**
This bootloader loads `BOOT`, not `RECOVERY`. Flash TWRP to **both** partitions,
in one session.

**3. The phone ignores every tool and looks dead.**
It is not dead. Samsung grants **one protocol session per entry into download
mode**, and a missing `--no-reboot` lets the flasher take the phone out of
download mode and burn it. Every later command then times out, which looks
exactly like a broken cable.

---

## Contents

```
lineageos-j4plus-install-kit/
├── install.sh                 ← THE COMMAND. Guided install + --status
├── README.md                  ← you are here
├── QUICKSTART.md              ← decision tree
├── LICENSE  CONTRIBUTING.md  SECURITY.md  THIRD_PARTY_NOTICES.md
├── docs/
│   ├── 01-prerequisites-and-downloads.md
│   ├── 02-diagnose-the-blockers.md
│   ├── 03-kg-prenormal-bypass.md
│   ├── 04-flash-twrp.md
│   ├── 05-install-lineageos-and-gapps.md
│   ├── 06-verify-first-boot-and-recovery.md
│   ├── 07-troubleshooting.md   ← Q&A with a symptom index
│   ├── 08-learnings.md         ← why the procedure is shaped this way
│   └── 09-device-reference.md  ← partitions, USB IDs, key combos, checksums
├── prompts/
│   ├── PASTE-THIS.md           ← copy this into any AI agent
│   ├── agent-brief.md
│   ├── 01-flash-from-scratch.md
│   ├── 02-when-stuck.md
│   └── 03-post-install.md
├── scripts/
│   ├── 00-preflight.sh
│   ├── 01-flash-twrp.sh
│   ├── 02-kg-bypass.sh
│   ├── 03-install-rom-and-gapps.sh
│   └── adb-ui.py               ← finds UI elements by scoring, not by first match
├── tests/check_links.py
└── .github/workflows/ci.yml    ← shellcheck, bash -n, py_compile, link check
```

`install.sh` orchestrates the four scripts in `scripts/`. You can run them
individually if you want to — see [`scripts/README.md`](scripts/README.md).

---

## Two warnings

**Never boot the phone back into stock Android** once TWRP is in `BOOT`. A stock
boot can restore stock recovery and re-lock the bootloader, undoing the whole
procedure. This is the only irreversible mistake available, and every script here
is built to prevent it.

**This is an unofficial ROM.** `j4primelte` has never been an officially
supported LineageOS device — there is no device page on the wiki and no official
version. The build is `userdebug` with permissive SELinux and an old security
patch. Fine for a device on a shelf, a test phone, or a dedicated media player.
Not fine for banking on. Known limitations of these builds: VoLTE and
Samsung-proprietary bits do not work, traffic statistics are broken, FM radio is
partial, and face unlock is absent.

---

## Provenance

Everything here came from one real session on a MacBook Pro M3 Pro, completed
13 November 2026. Nothing is hypothetical.

- **Verified on this device** — commands that were actually run and produced the
  stated output.
- **Verified upstream** — facts checked against LineageOS, Team Win, XDA or the
  project repositories.
- **Reconstructed** — the scripts were rewritten from the session's originals for
  this kit. They are faithful to what was run, but **read them before you trust
  them with a device.**

Where the session and upstream disagreed, upstream is quoted and the disagreement
is called out.

---

## Contributing

Corrections to the device facts are the most valuable contribution — if one is
wrong for your regional variant, people will brick phones. See
[CONTRIBUTING.md](CONTRIBUTING.md).

Found a bug? Open an issue with the **exact** error text, copied rather than
paraphrased, and the output of `./install.sh --status`.

---

## License

MIT — see [LICENSE](LICENSE). Third-party projects referenced here are credited
in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Flashing a phone voids its warranty in most jurisdictions, can destroy data, and
can permanently brick the device if the procedure is followed incorrectly. Keith
Rumjahn is not responsible for damage to devices, data, or warranty. Everything
here was performed on hardware the author owns, at their own risk.

This project is independent and unaffiliated with Samsung, LineageOS, Team Win,
MindTheGapps and LineageOSOS.
