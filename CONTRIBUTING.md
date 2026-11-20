# Contributing

Thanks for looking at this. Pull requests are welcome.

## What this repo is

A set of notes and helper scripts for replacing **Samsung's stock Android** on a
Samsung Galaxy J4+ (`j4primelte`, SM‑J415F / SM‑J415GN) with **LineageOS 19.1**,
flashed from macOS using
[`samloader`](https://github.com/topjohnwu/samloader-rs) — no Odin, and no Windows PC
required.

It was written by documenting a real 49-hour installation, including every failure.
If you have flashed a similar device and found something this repo gets wrong,
**that is the most valuable contribution you can make.**

## What would help most

In rough order of usefulness:

1. **Corrections to the device facts.** Partition names, USB IDs, key combinations,
   PIT layout. These are the load-bearing facts; if one is wrong for your regional
   variant, people will brick phones.
2. **Reports from other devices.** `SM‑J415F`, `SM‑J415FM` and `SM‑J415DS` may
   differ. Note which variant you used.
3. **A working unattended path.** The biggest remaining gap is the KG Prenormal
   bypass: it still needs a human to tap the update button. If you have automated
   that end to end, please contribute it.
4. **Newer devices.** This repo is specific to `j4primelte`. The *structure* of the
   procedure may carry over; the specifics will not.
5. **Better scripts.** The scripts here are deliberately cautious. They refuse to
   do anything irreversible without a confirmation, and they will not pipe device
   output. Please keep that property.

## Ground rules

- **Never let the phone boot back into stock Android** once TWRP is in `BOOT`.
  A stock boot can restore stock recovery and re-lock the bootloader. If you
  contribute a script that reboots the device, make sure it cannot do that.
- **Never pipe a live device session** into `head` or `grep`. SIGPIPE kills
  samloader mid-handshake and corrupts the session. Log to a file.
- **Always `--no-reboot`** on samloader commands unless the reboot is wanted.
- **One download-mode entry = one protocol session.** Make the flash the first
  device command of a session. Detect with `ioreg`, which cannot consume a
  session.
- **Do not commit credentials.** `config.json`, `*.jks`, `keystore.properties` and
  `*.log` are gitignored. Do not put a NAS password or a token in a script, a
  prompt file, or a doc.

## Style

- Shell scripts: `bash` with `set -uo pipefail`, shellcheck-clean, POSIX-ish where
  practical.
- Python: standard library only, so the scripts run on a fresh machine without a
  pip install.
- Docs: British or American spelling both fine, but be consistent within a file.
  Use the existing heading style — `##` for sections, `###` for subsections.
- Write for someone reading at 2am with a phone that will not boot.

## Running the checks

CI runs `shellcheck`, `bash -n` and a Python compile check on every push. Run them
locally first:

```bash
brew install shellcheck        # macOS
shellcheck scripts/*.sh
bash -n scripts/*.sh
python3 -m py_compile scripts/adb-ui.py
```

## Reporting a bug

Open an issue. Useful things to include:

- Your exact device model and variant (`SM‑J415F`, `SM‑J415GN`, …).
- The serial's last four characters and the bootloader build string.
- Your macOS version and architecture, and the samloader version.
- The **exact** error text — copy and paste it, do not paraphrase it.
- Whether you were in download mode, TWRP, the LineageOS recovery, or stock.

See [SECURITY.md](SECURITY.md) for anything involving credentials.

## Code of conduct

Be decent to each other. Assume good faith, especially when someone posts an error
that turns out to be their own typo. We have all been there.

## License

Contributions are accepted under the [MIT License](LICENSE).
