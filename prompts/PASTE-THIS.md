# PASTE THIS

> **One prompt. Copy everything below it into your coding agent and let it drive.**
>
> It assumes you have cloned this repo and have a Galaxy J4+ connected over USB.
> It will stop and ask you at every point where a human is genuinely required —
> reading the Odin screen, joining Wi‑Fi, confirming the wipe.

---

You are helping me install **LineageOS 19.1** on a **Samsung Galaxy J4+**
(`SM‑J415GN`, codename `j4primelte`, Snapdragon 425, 32‑bit ARM) from **macOS on
Apple Silicon**, using **`samloader`**. No Odin, no Windows.

The kit you are working from is this repository. Read these files before you act:

- `prompts/agent-brief.md` — the device facts, the protocol rules, the safety rules
- `docs/07-troubleshooting.md` — the failure catalogue, if something goes wrong
- `docs/09-device-reference.md` — partitions, USB IDs, key combinations

Work from `install.sh` where you can: `./install.sh` drives the whole procedure and
`./install.sh --status` tells you the current state read-only.

## Rules you must not break

1. **Never let the phone boot back into stock Android** once TWRP is in `BOOT`.
   A stock boot can restore stock recovery and re-lock the bootloader, and undo
   the entire procedure.
2. **Before any irreversible action** — formatting `data`, unlocking the
   bootloader, flashing a partition — **tell me exactly what you are about to do
   and wait for my explicit go-ahead**. Do not bundle it with other steps.
3. **Always `--no-reboot`** on samloader commands, unless I asked for the reboot.
4. **The flash must be the first device command of a download-mode session.**
   Samsung grants one session per entry into download mode. Detect the phone with
   `ioreg`, which cannot consume a session. Never use `samloader detect` to check.
5. **Never pipe a live device session into `head` or `grep`.** SIGPIPE kills
   samloader mid-handshake. Redirect to a log file and read the file.
6. **Never edit a script while it is running.** Write a new file and restart.
7. **Do not delete anything on my machine**, and do not write outside the working
   directory, without telling me first.

## Facts that are load-bearing — do not "correct" them

- **This bootloader loads `BOOT`, not `RECOVERY`.** The `RECOVERY` partition is
  inert. TWRP must go to **both**, in one session. Flashing `RECOVERY` alone
  reports success and does nothing.
- **There is no physical Home button.** The home key is capacitive and cannot be
  held. Every "Volume Down + Home + Power" guide is wrong for this device. Use
  **Volume Up + Volume Down + Power**.
- **The ROM is 32-bit ARM** (`ro.product.cpu.abi=armeabi-v7a`,
  `ro.zygote=zygote32`). The `msm8953_64` string in `fstab.qcom` is a device-tree
  copy-paste artifact and does not describe the architecture. Google apps must be
  **MindTheGapps 12.1.0 ARM** — not 13.0.0, not arm64.
- **There is no `vbmeta` partition.** `no-verity-opt-encrypt` is unnecessary here
  and fails anyway.
- **`adb sideload` does not work** on this device's recoveries. Use `adb push`
  plus `twrp install`, or run MindTheGapps' `update-binary` directly.
- **The LineageOS recovery cannot clear the boot request.** It creates only
  `/dev/block/platform/soc/7824900.sdhci/by-name/`, but the bootloader writes to
  `/dev/block/bootdevice/by-name/misc`. If the phone loops into recovery, that is
  the cause — restore the ROM's `boot.img` into `BOOT`, or boot the system from
  TWRP. **Check pstore before blaming the ROM:**
  `adb pull /sys/fs/pstore/console-ramoops pstore-console.log` and grep for
  `zygote|system_server|boot_completed|apexd`. Zero hits means the system never
  tried to boot.

## The order of operations

1. **Preflight** — tools, files, checksums.
2. **Read the Odin screen.** Photograph or transcribe these three lines:
   `OEM LOCK:`, `KG STATUS:` (or its absence), `FRP LOCK:`. One photograph
   answers whether the bootloader is locked, whether KG Prenormal is active, and
   whether FRP is locked.
3. **If `KG STATUS: Prenormal`** — the phone must be on stock Android with a
   working internet connection. Backdate the clock **9 days and no further**
   (the method wants more than 7; TLS allowed exactly 9 on the certificate chain
   that was valid at the time — probe, do not assume), check for software
   updates, restore the clock, check again. The success marker must read
   `Last successful check for update at HH:MM`. A line reading `on <date>` is a
   stale check and does not count.
4. **Flash TWRP to BOOT and RECOVERY**, one session, `--no-reboot`.
5. **Boot TWRP.** Format `data`. Install the ROM. Install MindTheGapps 12.1.0 ARM
   into the system partition.
6. **Restore the ROM's `boot.img` into `BOOT`** so the system can boot.
7. **Boot, verify, and report.**

## Reporting

At every stage, tell me what you did, quote the **actual** output — the handshake
line, the partition id, the bytes written, the install result code — and say
plainly whether it worked. Do not summarise a log as "it worked" unless the log
says so. If something fails, stop, show me the output, and check
`docs/07-troubleshooting.md` before trying a workaround. If it is not in there,
say so and tell me what you would check next.

Ask me for a photo or a description whenever the next step depends on what is
displayed on the phone. You cannot see it.
