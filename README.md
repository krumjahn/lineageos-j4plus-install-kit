# LineageOS 19.1 on the Samsung Galaxy J4+ — Complete Install Kit

**Device:** Samsung Galaxy J4+ — SM‑J415F / SM‑J415GN, codename `j4primelte`
**Target:** LineageOS 19.1 (Android 12L) + MindTheGapps 12.1.0 (ARM / armeabi‑v7a)
**Host:** macOS on Apple Silicon. No Windows, no Odin, no virtual machine.
**Status:** verified booting — LineageOS 19.1 with Google apps, confirmed 13 Nov 2026, 23:17 HKT
**Elapsed:** ~49 hours from the first request to a working phone

> **⚠️ This will erase your phone.**
> Flashing LineageOS wipes Android completely. If it goes wrong, you can end up with a
> phone that boots nothing. Read `QUICKSTART.md` first, then `docs/01-prerequisites-and-downloads.md`.
> Backup anything you cannot lose. Do not start on the only phone you own.

---

## What this is

A complete, reproducible record of installing LineageOS on a Galaxy J4+ **without Odin and
without Windows**, written down from an actual 49‑hour session in which it was done — including
every mistake, every dead end, and every thing that was believed to be true at one point and
turned out not to be.

It has four parts:

| Part | What it is | Where |
|---|---|---|
| **The guide** | Step‑by‑step procedure, in order, with every command | [`docs/`](docs/) |
| **The post‑mortem** | Every failure: symptom → real cause → fix | [`docs/07-troubleshooting.md`](docs/07-troubleshooting.md) |
| **The learnings** | What was hard, why, and what would be faster next time | [`docs/08-learnings.md`](docs/08-learnings.md) |
| **The prompt pack** | Prompts you can paste into any coding agent to reproduce this | [`prompts/`](prompts/) |

Plus [`scripts/`](scripts/) — helper scripts reconstructed from the session, and
[`tests/`](tests/) — the link checker that CI runs on every push.

## The short version

If you only read one page, read [`QUICKSTART.md`](QUICKSTART.md).

The whole procedure in eight lines:

1. Get the phone onto stock Android with a working internet connection, USB debugging on.
2. Read the Odin screen. If it says `KG STATUS: Prenormal`, you must clear it first.
3. Clear KG Prenormal with the **9‑day clock backdate + Software update check** trick.
4. Flash TWRP to **BOOT *and* RECOVERY** (BOOT is the one that actually matters).
5. In TWRP: format `data`, install the LineageOS zip.
6. Install MindTheGapps 12.1.0 ARM from recovery, into the system partition.
7. Put the LineageOS `boot.img` back into BOOT.
8. Boot. Verify. Done.

Everything else is detail.

## What made this hard

Three things, in order of how long they cost:

1. **`FAIL! Auth` on every flash.** The bootloader was locked. TWRP transferred all 27 MB
   perfectly and *then* got rejected — the flash mechanism was never the problem.
2. **`KG STATUS: Prenormal`.** A separate gate from the bootloader lock. Even with
   `OEM LOCK: OFF`, Samsung refuses all non‑Samsung binaries. This is what the clock
   trick clears.
3. **TWRP flashed successfully but the phone still booted stock recovery.** The bootloader
   loads `BOOT`, and `RECOVERY` is inert on this device. Flash TWRP to `BOOT` too.

Details, exact error strings and fixes: [`docs/07-troubleshooting.md`](docs/07-troubleshooting.md).

## Contents

```
lineageos-j4plus-install-kit/
├── README.md                    ← you are here
├── QUICKSTART.md                ← decision tree; read this next
├── LICENSE                      ← MIT
├── CONTRIBUTING.md              ← how to help; what I most want corrected
├── SECURITY.md                  ← reporting a vuln; what is deliberately excluded
├── THIRD_PARTY_NOTICES.md       ← LineageOS, TWRP, MindTheGapps, samloader, XDA
├── docs/
│   ├── 01-prerequisites-and-downloads.md
│   ├── 02-diagnose-the-blockers.md
│   ├── 03-kg-prenormal-bypass.md
│   ├── 04-flash-twrp.md
│   ├── 05-install-lineageos-and-gapps.md
│   ├── 06-verify-first-boot-and-recovery.md
│   ├── 07-troubleshooting.md    ← every mistake, symptom → cause → fix
│   ├── 08-learnings.md          ← what was hard and why
│   └── 09-device-reference.md   ← partitions, USB IDs, key combos, verified facts
├── prompts/
│   ├── README.md
│   ├── agent-brief.md           ← paste this into any agent first
│   ├── 01-flash-from-scratch.md
│   ├── 02-when-stuck.md
│   └── 03-post-install.md
├── scripts/
│   ├── README.md
│   ├── 00-preflight.sh
│   ├── 01-flash-twrp.sh
│   ├── 02-kg-bypass.sh
│   ├── 03-install-rom-and-gapps.sh
│   └── adb-ui.py                ← the UI driver that finds "Check for update"
├── tests/
│   └── check_links.py           ← CI: every relative link must resolve
└── .github/workflows/ci.yml     ← shellcheck, bash -n, py_compile, link check
```

## Who this is for

You have a Galaxy J4+ and you want LineageOS on it without Windows.

**This repo is specific to the Galaxy J4+** — codename `j4primelte`, models
`SM‑J415F`, `SM‑J415FM`, `SM‑J415DS`, `SM‑J415GN`. The partition map, the key
combinations, the KG behaviour and the recovery quirks are all specific to this
device.

If yours is a Galaxy J4 (SM‑J410), a J5, a J7, an A3, or anything else, **stop.**
The guide will not apply to you.

If your variant differs from the one here, the most valuable thing you can do is
[tell me what was different](CONTRIBUTING.md). Regional variants sometimes differ
in ways that matter.

## Provenance

Everything in this kit was derived from one real session on a MacBook Pro M3 Pro
(macOS, Apple Silicon), completed on 13 November 2026. Nothing here is hypothetical.

Three categories of content, and they are worth distinguishing:

- **Verified on this device.** Commands that were actually run and produced the stated
  output. Marked ✅ in the docs.
- **Verified upstream.** Facts checked against LineageOS, TeamWin, XDA or the project
  repositories. Marked 📎 with a source link.
- **Reconstructed.** The helper scripts in `scripts/` were rewritten from the session's
  scripts for this kit. The session originals were deleted with the working directory.
  They are faithful to what was run, but **read them before you trust them with a device.**

Where the session and upstream disagreed, upstream is quoted and the disagreement is
called out — see `docs/08-learnings.md`.

## Using the prompt pack

The prompts in [`prompts/`](prompts/) are written to work with any coding agent
(Claude Code, Codex, Cursor, Aider, OpenCode, or a raw LLM in a chat window). They are
deliberately conservative: they tell the agent to stop and ask before anything
irreversible, to log device output to a file rather than piping it, and to never
reboot the phone back into stock.

Start with [`prompts/agent-brief.md`](prompts/agent-brief.md) — it carries the safety
rules and the hard‑won device facts. Then pick a task prompt.

## Contributing

Pull requests are welcome, and the most valuable ones are corrections to the device
facts — partition names, USB IDs, key combinations, PIT layout. If one of those is
wrong for your regional variant, people will brick phones.

See [CONTRIBUTING.md](CONTRIBUTING.md) for what would help most and the ground rules
the scripts follow.

If you have flashed a J4+ variant and found something this repo gets wrong,
[open an issue](https://github.com/krumjahn/lineageos-j4plus-install-kit/issues) with
the exact error text — copied, not paraphrased.

## License and disclaimer

Documentation and scripts in this kit are provided as‑is for educational and repair
purposes, under the [MIT License](LICENSE).

Flashing a phone voids its warranty in most jurisdictions, can destroy data, and can
permanently brick the device if the procedure is followed incorrectly. Keith Rumjahn
is not responsible for damage to devices, data, or warranty. Everything here was
performed on hardware the author owns, at their own risk, and is published in the
hope that someone else does not have to rediscover the KG Prenormal bypass from
scratch.

Nothing in this kit requires a Google account, a Samsung account, a paid tool, or a
Windows machine — which was the point.

This project is independent and unaffiliated with Samsung, LineageOS, Team Win,
MindTheGapps and LineageOSOS. Third-party projects referenced here are credited in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
