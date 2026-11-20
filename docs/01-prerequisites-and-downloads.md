# 01 — Prerequisites and downloads

Everything you need before you touch the phone. Do not skip the checksum verification —
half the "my flash failed" problems in the original session were caused by a truncated
download that looked fine.

---

## 1.1 Hardware and software checklist

**On the Mac:**

- macOS on Apple Silicon (Intel works, but the notes below are from an M3 Pro)
- `git`, `python3`, and a Rust toolchain — only if you build samloader from source
  (section 1.5). A prebuilt binary is fine if you skip the patches and the device
  handshakes within a second.
- Android platform-tools (`adb`). Install with
  `brew install --cask android-platform-tools`, or from
  <https://developer.android.com/tools/releases/platform-tools>.
- `brew install rust` + `rustup` if building samloader.
- `brew install brotli` — only for the fallback path where you convert
  `system.new.dat.br` on the Mac.

**On the phone:**

- A USB‑A to USB‑C cable that carries data. **Not** a charge‑only cable. This sounds
  obvious; it still wastes people hours.
- Ideally plug into a **USB‑A port directly**, not through a hub. The original session
  used a USB‑A port on the Mac. Hub and dock topology changes USB enumeration timing
  and samloader's handshake is timing‑sensitive.
- A SIM is **not** required. Wi‑Fi only is fine — but see section 1.3, because Wi‑Fi is
  needed for one specific stage and it is not optional there.
- The battery is **not** removable on this unit, and there is no clean power‑off other
  than a long press. Factor that into your risk planning.

**Free disk:** the full set of files is around 6.8 GB (stock firmware dominates).
You can drop the stock firmware to ~200 MB if you are not going to use the
`samloader download` fallback, but keep the 2.7 GB stock package until the phone
definitely boots — it is your only way to get a signed binary accepted while the
bootloader is still locked.

---

## 1.2 The downloads

| File | Size | SHA-256 (verified) | Source |
|---|---|---|---|
| `twrp-3.7.0_9-0-j4primelte.img` | 27,510,784 B | `7dabdee3b26dd5781593690f61a927630d14e3fd61233c2894666029ee518632` | <https://twrp.me/samsung/samsunggalaxyj4plus.html> |
| `MindTheGapps-12.1.0-arm-20231025_200802.zip` | 228,186,029 B | — (match the GitHub release size exactly) | <https://github.com/MindTheGapps/12.1.0-arm/releases/latest> |
| `lineage-19.1-20231011-UNOFFICIAL-j4primelte.zip` | 619,370,620 B | — | **link now dead — see below** |
| `RMM_Bypass_v3_corsicanu.zip` | 6,377 B | md5 `056eeebb2d6c59bc8d975f0ba2349eb2`<br>sha256 `42ec18878d336a7b0927bb87251bb548e020d4faa052679abe2ae0402b643bfc` | <https://sourceforge.net/projects/m30lte-dev/files/RMM%20Lock/> |
| Stock firmware `SM-J415GN_1_20221024162611_v5rle0qo3v_fac.zip` | 2,675,118,600 B | — | `samloader download` |

Also useful:

- `wipe-frp.sh` — LineageOS's official FRP removal script, verbatim from
  <https://github.com/LineageOS/android_vendor_lineage/blob/master/prebuilt/common/bin/wipe-frp.sh>
- `no-verity-opt-encrypt-6.1.zip` — **you do not need this.** See section 5.4.

### ⚠️ The unofficial ROM — and a dead download link

**`j4primelte` has never been an officially supported LineageOS device.** There is no
device page on the LineageOS wiki (it returns 404) and the wiki's own source
repository has **zero commits** for `j4primelte.yml` — so there was never an official
version to remove, and there is no official build date. Every j4primelte ROM is a
community build.

The exact ROM used in the original session was:

```
lineage-19.1-20231011-UNOFFICIAL-j4primelte.zip      619,370,620 bytes
build: samsung/j4primeltedx/j4primelte:9/PPR1.180610.011/J415FXXU2BSDM
post-build: eng.gabrie.20231011.223248
```

**Its download link is dead.** The XDA thread
[“Unofficial 12.1 LineageOS 19.1 for Galaxy J4 (j4primelte)”](https://xdaforums.com/t/unofficial-12-1-lineageos-19-1-for-galaxy-j4-j4primelte.4517067/)
(now titled “CLOSED”) pointed at a Google Drive file that now returns *“Sorry, the file
you have requested does not exist.”* The thread was closed by a moderator on
26 Aug 2026 because of the broken link. No GitHub or SourceForge mirror of that
specific zip was found, and **no SHA-256 for it is published anywhere**.

**What to do instead:** use the currently maintained build line for this device.

| | |
|---|---|
| Thread | [“REVIVE OS ‖ J4 PLUS ‖ UNOFFICIAL ‖ NOV, 2026”](https://xdaforums.com/t/revive-os-j4-plus-unofficial-nov-2026.4766304/) |
| ROM | `ReviveOS_FinalBuild.zip` (~790 MB) — <https://drive.google.com/file/d/1XT7wSyXTs7ncYr7GkyJxMrpT-rW69Rqi/view?usp=drivesdk> |
| GApps | <https://drive.google.com/file/d/1hCLN5pkYFxm_XN10EMMoo75l7fJP4eMM/view?usp=drivesdk> |

That thread reports a LineageOS‑19.1‑based, 32‑bit ARM build with the same
`J415-dev/android_device_samsung_msm8917-common` device tree lineage.

> **Check the thread before you download.** Confirm three things, because they decide
> every later step in this kit:
> 1. The **Android / LineageOS version** — this determines your GApps package.
> 2. The **architecture** — it must be **ARM (armeabi‑v7a)**, 32‑bit.
> 3. The **recovery requirement** — the thread states *"It is recommended to flash with
>    latest twrp v3.7.0"*, which matches the procedure in this kit.
>
> The rest of this document assumes **LineageOS 19.1 / Android 12L / 32‑bit ARM**.
> If your build is a different version, adjust the MindTheGapps version and re‑read
> the MindTheGapps table on the LineageOS wiki: <https://wiki.lineageos.org/gapps/>

#### What to expect from an unofficial build

This is a community build on a 2018 device. Known limitations reported in the
community threads:

- **SELinux is permissive**, and the build is `userdebug` with `test-keys` signing.
- **Security patch level is old** — 2023‑10 for the ROM used here.
- VoLTE and Samsung‑proprietary bits do not work.
- **Mobile data / Wi‑Fi traffic statistics are broken** (kernel eBPF).
- FM radio is partial; the device runs warm.
- **Face unlock is not included**; Gcam Go has to be installed manually.

Fine for a shelf device, a test phone, a dedicated media player, or a work phone
behind a VPN. Not fine to put banking apps on and assume a maintained commercial
device's security model.

### Downloading TWRP (the interstitial)

A plain `curl` of the `.img` from `dl.twrp.me` returns a 6,885‑byte HTML interstitial
instead of the image. The working flow is two requests with a shared cookie jar:

```bash
cd ~/Desktop/j4-flash
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
REF='https://twrp.me/samsung/samsunggalaxyj4plus.html'
BASE='https://dl.twrp.me/j4primelte'

curl -fsSL -c cookies.txt -A "$UA" -e "$REF" "$BASE/twrp-3.7.0_9-0-j4primelte.img.html" -o page.html
curl -fsSL -b cookies.txt -c cookies.txt -A "$UA" -e "$REF" \
     "$BASE/twrp-3.7.0_9-0-j4primelte.img" -o twrp-3.7.0_j4primelte.img
```

> **If `dl.twrp.me` is unreachable, use the Europe mirror: `https://eu.dl.twrp.me/j4primelte/`.**
> The Americas mirror is intermittent. Team Win publishes the checksum sidecars on
> both mirrors:
> `https://eu.dl.twrp.me/j4primelte/twrp-3.7.0_9-0-j4primelte.img.sha256` and
> `…img.md5`.

Then **always** verify:

```bash
shasum -a 256 twrp-3.7.0_j4primelte.img
# expect 7dabdee3b26dd5781593690f61a927630d14e3fd61233c2894666029ee518632
md5 twrp-3.7.0_j4primelte.img
# expect 0be9a3683a81fc8d255953e94bb77ae9
```

If the file is 6,885 bytes, you got the interstitial, not the image.

### SourceForge and AndroidFileHost

`sourceforge.net` serves a Cloudflare JS challenge to plain downloaders, and
AndroidFileHost uses a JS mirror picker. Two approaches that work:

1. Use the direct mirror URL:
   `https://master.dl.sourceforge.net/project/m30lte-dev/RMM%20Lock/RMM_Bypass_v3_corsicanu.zip`
2. Or download in a real browser and move the file.

Do **not** waste time trying to script around the challenge with header spoofing; the
direct mirror URL is the answer.

---

## 1.3 The one thing you cannot skip: internet on the phone

The KG Prenormal bypass (stage 3) requires the phone to reach Samsung's update
server. That means:

- The phone must be on stock Android with a **working internet connection**.
- After a factory reset, the saved Wi‑Fi networks are **gone**. Android 9's shell
  cannot add a Wi‑Fi network — `cmd wifi` needs root and `cmd netpolicy` has no
  add-network operation. **A human has to join the network once, on the phone.**

This was the single most disruptive physical step in the original session: the
automation was ready, the phone was not, and nothing could proceed until the phone
was on Wi‑Fi.

---

## 1.4 The `j4primelte` partition map

Dump it from your own device rather than trusting a table on the internet — different
regional variants can differ:

```bash
# with the phone in download mode
./samloader-longtimeout dump-pit --no-reboot --output device.pit
./samloader-longtimeout print-pit --file device.pit
```

Verified on this device (project `COM_TAR2`, cpu tag `MSM8937`, 57 entries, 8192 bytes,
512‑byte blocks):

| Partition | ID | Size | Notes |
|---|---|---|---|
| `BOOT` | 23 (`0x17`) | 32 MB | **the bootloader loads this one** |
| `RECOVERY` | 24 (`0x18`) | 32 MB | inert for booting on this device |
| `SYSTEM` | 47 (`0x47`) | 2.39 GB | |
| `VENDOR` | 48 | — | unused by this ROM — vendor lives inside system |
| `ODM` | 49 | — | |
| `CACHE` | 50 | — | |
| `USERDATA` | 53 | — | this is `data` |
| `PERSIST` | 31 | — | FRP lives here |
| `BOTA` | 26 | 7 MB | Samsung bootloader state strings |
| `MISC` | 33 | 1 MB | boot request |
| — | — | — | **there is no `vbmeta` partition** |

Two facts in that table drive the whole procedure:

- **`BOOT` is what boots.** Writing TWRP to `RECOVERY` alone changes nothing.
- **There is no `vbmeta`.** That is why `no-verity-opt-encrypt` is unnecessary, and
  why `vendor` being empty is not a problem.

---

## 1.5 Building samloader (optional but recommended)

`heimsamloader` is the usual answer for macOS, but the Odin protocol it implements is
not what Samsung's bootloader speaks on this device. **`samloader` (samloader‑rs) does**,
because it implements Samsung's Loke/Odin protocol directly.

It is also available as a **prebuilt binary for macOS, Linux and Windows** on the
[releases page](https://github.com/topjohnwu/samloader-rs/releases) — and on Windows the
default USB backend is VCOM, so **no Odin and no Zadig driver swap are needed on any
operating system**. If you only need the flasher, the prebuilt binary is the fast path.

```bash
git clone https://github.com/topjohnwu/samloader-rs
cd samloader-rs
cargo build --release --features nusb,rusb
```

**Version note:** the latest *tagged release* is **2.2.0** (25 Sep 2026), while the
`main` branch source is ahead of it — the session's build came from a `3.0.0` source
tree. **Check what you actually have:**

```bash
./samloader --version
./samloader flash --help
```

### Flags that actually exist

Confirmed in samloader 2.2.0:

| Flag | Exists | Notes |
|---|---|---|
| `--no-reboot` | ✅ | *"Disables automatic reboot after flashing"* — use it always |
| `-p`, `--partition PARTITION FILE` | ✅ | Repeatable; used to write BOOT and RECOVERY in one session |
| `--pit FILE` | ✅ | PIT file to use for flashing/repartitioning |
| `--csc-code CODE` | ✅ | Sets the persistent sales code via opcode `0x64` |
| `--BL` / `--AP` / `--CP` / `--CSC` / `--USERDATA` | ✅ | For official package files |
| `--skip-size-check`, `--skip-md5` | ✅ | |
| `-f`, `--file FILE` | ✅ | On `flash`, `-f` means **`--file`**, not `--force` |
| `--force` | ⚠️ | Documented on **`download`** ("restart from scratch"), not on `flash` |
| `--disable-verity` | ❌ | **Not a samloader flag.** It belongs to fastboot and Magisk |

> Run `samloader flash --help` against your own binary before publishing any command
> line you find online. `--repartition` was **removed** in 2.2.0 — PIT files are now
> auto‑committed whenever available.

### Two patches that were needed

Check whether upstream has landed these before patching:

**1 — Handshake timeout.** `odin/src/session.rs`, `HANDSHAKE_TIMEOUT`: `1` second →
`15` seconds. Stock samloader times out on the handshake and reports a dead cable.

**2 — `nusb` backend.** In `Cargo.toml`:
```toml
nusb = { version = "0.2.7", features = ["smol"] }
```
Without the `smol` feature the `nusb` crate panics with
`Awaiting blocking syscall without an async runtime`.

Build:
```bash
cargo build --release --features nusb,rusb
```

Notes:
- There is no `--features verbose`. Verbose output is a normal flag, `--verbose`.
- A default-feature build panics as above; you need `nusb,rusb`.
- The binary is `target/release/samloader`. Rename it to something memorable
  (`samloader-longtimeout`) so you never confuse it with a stock build.

---

## 1.6 Tooling rules that are not optional

These came from real failures. They are repeated in
[`docs/07-troubleshooting.md`](07-troubleshooting.md) with the symptoms they cause.

1. **Always `--no-reboot`** on samloader commands, unless you *want* the reboot.
   A default reboot yanks the phone out of download mode and burns the session.
2. **The flash must be the FIRST device command** in a fresh download‑mode session.
3. **Never pipe a live device session into `head` or `grep`.** SIGPIPE kills samloader
   mid‑handshake. Log to a file, then read the file.
4. **One download‑mode entry = one session.** Samsung's Loke daemon grants one protocol
   session per entry. A second command fails the handshake.
5. **Never edit a script while it is running.** Rewriting a running bash script corrupts
   it by byte offset — the runner crashes and you lose the session.
6. **Do not run `samloader print-pit` without `--file`.** It tries to use the device and
   burns the session.
7. **Detect the phone with `ioreg`, not with a device command.** `ioreg` cannot consume
   a session.

```bash
# non-invasive mode detection - never consumes the Odin session
ioreg -p IOUSB -w0 2>/dev/null | grep -oE "(MSM8953|SAMSUNG_Android)@[0-9a-f]+[[:space:]]+<class IOUSBHostDevice, id 0x[0-9a-f]+" | head -1
```

---

Next: [`02-diagnose-the-blockers.md`](02-diagnose-the-blockers.md)
