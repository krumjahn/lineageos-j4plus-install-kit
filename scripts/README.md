# Scripts

Helper scripts reconstructed from the original session.

> **Read these before you trust them with a device.**
> The session's originals were deleted along with the working directory. These were
> rewritten from what was actually run, so the logic is faithful, but the code is new.
> Every script is **read-only or explicitly gated** until you approve the
> irreversible step.

## What is here

| Script | Does | Touches the device? |
|---|---|---|
| `00-preflight.sh` | Checks the host, tools, download checksums and USB mode | Read-only (never consumes an Odin session) |
| `01-flash-twrp.sh` | Flashes TWRP to **BOOT and RECOVERY** in one session | **Writes to the phone** |
| `02-kg-bypass.sh` | Probes the TLS floor, then runs the KG Prenormal bypass | Changes the clock, reboots, toggles the radio |
| `03-install-rom-and-gapps.sh` | Formats data, installs the ROM, installs Google apps | **Erases data, writes to the phone** |
| `adb-ui.py` | Drives the phone's screen over ADB; finds UI elements by scoring | Read-only unless you tell it to tap |

## Before you run anything

```bash
cd ~/Desktop/j4-flash          # or wherever you keep the files
cp <this-directory>/*.sh .
cp <this-directory>/adb-ui.py .
chmod +x *.sh adb-ui.py

bash 00-preflight.sh
```

`00-preflight.sh` is read-only and will tell you what is missing. Run it first, every
time.

## The scripts in order

```bash
bash 00-preflight.sh
bash 01-flash-twrp.sh           # after the phone is in download mode
bash 03-install-rom-and-gapps.sh # after TWRP is up
bash 02-kg-bypass.sh            # only if the Odin screen says KG STATUS: Prenormal
```

`02-kg-bypass.sh` is independent of the others. Run it when you need it.

## Rules the scripts enforce

- **No piping.** Device output goes to a log file. `head` and `grep` on a live session
  send SIGPIPE and corrupt it.
- **`--no-reboot` always.** So the session is not burned by a default reboot.
- **The flash is the first device command.** The scripts never run a detection command
  before a flash, because a detection command consumes the session.
- **Irreversible steps ask first.** `03-install-rom-and-gapps.sh` prompts before
  formatting `data`.
- **`ioreg`, not samloader, for detection.** `ioreg` cannot consume an Odin session.

## What the scripts deliberately do not do

- They never reboot the phone into stock. That is the one mistake that can undo
  everything.
- They never delete anything on your machine.
- They never write to a partition other than the one you named.
- They never run a `dd` to a block device. If a step needs that, the script stops and
  asks.

## Overriding paths

All the scripts accept the working directory as their first argument, and the install
script honours environment variables:

```bash
bash 03-install-rom-and-gapps.sh ~/Desktop/j4-flash

ROM=/path/to/lineage.zip \
GAPS=/path/to/MindTheGapps.zip \
MTG_DIR=/path/to/mtg \
bash 03-install-rom-and-gapps.sh ~/Desktop/j4-flash
```

## `adb-ui.py` on its own

Useful for any screen-driven step, not just the KG bypass.

```bash
python3 adb-ui.py texts                       # every visible text element
python3 adb-ui.py find "Check for update"     # scored candidates, best first
python3 adb-ui.py tap-any "Check for update" "Download and install"
python3 adb-ui.py tap 540 1200                # absolute coordinates
python3 adb-ui.py dump                        # raw UI hierarchy XML
```

It scores candidates rather than taking the first match, because the first match is
usually the wrong element:

| Signal | Points |
|---|---|
| Exact text match | +100 |
| Element is clickable | +40 |
| `resource-id` contains "button" or "btn" | +25 |
| Not clickable | −15 |
| Long text | penalty |

That is the whole reason it was rewritten. The original matched a summary line and
reported success while doing nothing.

---

Full detail in [`../docs/`](../docs/).
