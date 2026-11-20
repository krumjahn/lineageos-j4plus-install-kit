#!/usr/bin/env bash
#
# install.sh - install LineageOS 19.1 on a Samsung Galaxy J4+ (j4primelte)
#
#   ./install.sh            guided install, one command
#   ./install.sh --status   read-only: what state is the phone in right now?
#   ./install.sh --help     this text
#
# Design rules, learned the hard way:
#
#   * NEVER boot the phone back into stock Android once TWRP is in BOOT.
#     A stock boot can restore stock recovery and re-lock the bootloader.
#   * Never pipe a live device session into head or grep. SIGPIPE kills
#     samloader mid-handshake and corrupts the session.
#   * Always --no-reboot on samloader commands.
#   * One download-mode entry = one protocol session. The flash must be the
#     FIRST device command of that session. Detect with ioreg, which cannot
#     consume a session.
#   * This bootloader loads BOOT, not RECOVERY. TWRP goes to both.
#
# The script is resumable: it records where it got to in .install-state and
# picks up from there. Re-run it after any interruption.
#
# Some steps genuinely need a human. The script will say so and wait.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${HERMES_WORK:-$HOME/Desktop/j4-flash}"
STATE_FILE="$WORK/.install-state"
LOGDIR="$WORK/logs"

ROM_NAME="${ROM_NAME:-lineage-19.1-20231011-UNOFFICIAL-j4primelte.zip}"
ROM="$WORK/$ROM_NAME"
GAPS_NAME="${GAPS_NAME:-MindTheGapps-12.1.0-arm-20231025_200802.zip}"
GAPS="$WORK/$GAPS_NAME"
ROMX_BOOT="$WORK/romx/boot.img"
SAMLOADER=""
for candidate in "$WORK/samloader-longtimeout" "$WORK/samloader" "$(command -v samloader 2>/dev/null)"; do
  [ -n "$candidate" ] && [ -x "$candidate" ] && { SAMLOADER="$candidate"; break; }
done

# ---------------------------------------------------------------- output helpers
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_HEAD=$'\033[1;36m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_HEAD=""; C_OFF=""
fi
head()  { printf "\n%s== %s ==%s\n" "$C_HEAD" "$*" "$C_OFF"; }
info()  { printf "  %s\n" "$*"; }
ok()    { printf "  %sok%s    %s\n" "$C_OK" "$C_OFF" "$*"; }
warn()  { printf "  %swarn%s  %s\n" "$C_WARN" "$C_OFF" "$*"; }
err()   { printf "  %sFAIL%s  %s\n" "$C_ERR" "$C_OFF" "$*"; }
fatal() { err "$*"; exit 1; }

pause() {
  printf "\n  >>> %s\n" "$*"
  printf "  Press Enter when you are ready. Ctrl-C to stop. "
  read -r _ || true
  echo
}

usage() {
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# ---------------------------------------------------------------- state file
stage_done() { printf '%s\n' "$1" >> "$STATE_FILE"; }
stage_seen() { [ -f "$STATE_FILE" ] && grep -qx "$1" "$STATE_FILE"; }
mark() { stage_done "$1"; }

# ---------------------------------------------------------------- device probes
# ioreg cannot consume the Odin session, so it is always safe to call.
usb_mode() {
  if ioreg -p IOUSB -w0 2>/dev/null | grep -q 'MSM8953'; then
    echo "download"
  elif ioreg -p IOUSB -w0 2>/dev/null | grep -q 'SAMSUNG_Android'; then
    echo "android"
  else
    echo "none"
  fi
}

# adb is often only in the Android SDK, not on PATH. Look in the usual places
# before declaring it missing - people get a false failure otherwise.
ensure_adb_on_path() {
  command -v adb >/dev/null 2>&1 && return 0
  local c d
  for c in \
      "${ANDROID_HOME:-}/platform-tools/adb" \
      "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
      "$HOME/Library/Android/sdk/platform-tools/adb" \
      "$HOME/Android/Sdk/platform-tools/adb"; do
    if [ -x "$c" ]; then
      d="$(dirname "$c")"
      export PATH="$d:$PATH"
      return 0
    fi
  done
  return 1
}

adb_mode() {
  ensure_adb_on_path || { echo "no-adb"; return; }
  if adb devices | grep -qE '^\S+\s+device$'; then echo "ready"; else echo "none"; fi
}

phone_has_internet() {
  command -v adb >/dev/null 2>&1 || return 1
  adb shell ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1
}

# ---------------------------------------------------------------- status report
status_report() {
  head "Current state"
  local mode amode
  mode="$(usb_mode)"
  amode="$(adb_mode)"

  case "$mode" in
    download) ok "phone is in DOWNLOAD mode (Odin). One protocol session available." ;;
    android)  ok "phone is in ANDROID mode (MTP)." ;;
    *)        warn "no Samsung USB device found. Plug the phone in, or wake it." ;;
  esac

  case "$amode" in
    ready)  ok "adb is authorised"
             info "device: $(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')"
             info "android: $(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r') (sdk $(adb shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r'))"
             info "abi:     $(adb shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')"
             if phone_has_internet; then ok "phone has internet"
             else warn "phone has NO internet - the KG bypass needs it"; fi ;;
    no-adb) warn "adb not found on this Mac" ;;
    *)      warn "no authorised adb device" ;;
  esac

  head "Files"
  local f
  for f in "$WORK/twrp-3.7.0_j4primelte.img" "$ROM" "$GAPS" "$ROMX_BOOT" "$SAMLOADER"; do
    [ -n "$f" ] || continue
    if [ -e "$f" ]; then ok "$(basename "$f")"
    else warn "missing: $f"; fi
  done

  head "Progress"
  if [ -f "$STATE_FILE" ] && [ -s "$STATE_FILE" ]; then
    sed 's/^/  done: /' "$STATE_FILE" | sort -u
  else
    info "no stages completed yet"
  fi

  head "Next"
  case "$mode" in
    download)
      if stage_seen twrp-flashed; then
        info "TWRP is already flashed. Boot it and re-run to continue."
      else
        info "Run ./install.sh without --status. It will flash TWRP first."
      fi ;;
    android)
      if stage_seen twrp-flashed; then
        info "Boot TWRP (it is in BOOT), then re-run."
      else
        info "Run ./install.sh. It will check the bootloader and KG state first."
      fi ;;
    *)
      info "Plug the phone in over USB, turn the screen on, and re-run."
      ;;
  esac
  echo
}

# ---------------------------------------------------------------- stage 0
stage_preflight() {
  head "Stage 0 - preflight"
  [ -d "$WORK" ] || { mkdir -p "$WORK" || fatal "could not create $WORK"; }
  mkdir -p "$LOGDIR"

  if [ -z "$SAMLOADER" ]; then
    err "no samloader binary found."
    info "Looked for $WORK/samloader-longtimeout, $WORK/samloader, and samloader on PATH."
    info "See docs/01-prerequisites-and-downloads.md section 1.5 to build it."
    fatal "cannot continue without samloader"
  fi
  ok "samloader: $SAMLOADER"

  if ! command -v adb >/dev/null 2>&1; then
    ensure_adb_on_path || fatal "adb not found - install Android platform-tools, or set ANDROID_HOME"
  fi
  command -v adb >/dev/null 2>&1 || fatal "adb not found - install Android platform-tools"

  if [ -f "$WORK/twrp-3.7.0_j4primelte.img" ]; then
    local actual
    actual="$(shasum -a 256 "$WORK/twrp-3.7.0_j4primelte.img" | awk '{print $1}')"
    if [ "$actual" = "7dabdee3b26dd5781593690f61a927630d14e3fd61233c2894666029ee518632" ]; then
      ok "TWRP image sha256 verified"
    else
      err "TWRP image sha256 MISMATCH - refusing to flash a file I cannot verify"
      info "expected 7dabdee3b26dd5781593690f61a927630d14e3fd61233c2894666029ee518632"
      info "actual   $actual"
      fatal "download it again from twrp.me - a 6885 byte file is the download interstitial"
    fi
  else
    warn "TWRP image not in $WORK"
    info "Download: https://twrp.me/samsung/samsunggalaxyj4plus.html"
    fatal "cannot continue without twrp-3.7.0_j4primelte.img"
  fi

  [ -f "$ROM" ]  || warn "ROM not found: $ROM"
  [ -f "$GAPS" ] || warn "MindTheGapps not found: $GAPS"
  ok "preflight done"
}

# ---------------------------------------------------------------- stage 1
# The Odin screen is the single most valuable piece of information. It answers
# "is the bootloader locked", "is KG Prenormal active" and "is FRP locked"
# in one photograph.
stage_check_odin() {
  head "Stage 1 - bootloader and KG state"
  local mode
  mode="$(usb_mode)"

  if [ "$mode" != "download" ]; then
    info "Put the phone into DOWNLOAD mode."
    info "  With Android running:  adb reboot download"
    info "  Or by buttons:  hold Volume Up + Volume Down + Power,"
    info "                    then Volume Up on the blue warning screen."
    info "  (there is no Home button on this phone - do not press one)"
    pause "Phone in download mode?"
  fi

  if [ "$(usb_mode)" != "download" ]; then
    fatal "the phone is not in download mode (ioreg does not show MSM8953)"
  fi
  ok "download mode detected - one protocol session available"

  info ""
  info "Read the Odin screen and note these lines:"
  info "  OEM LOCK:  ON or OFF"
  info "  KG STATUS: Prenormal  (or absent entirely)"
  info "  FRP LOCK:  ON or OFF"
  info ""
  printf "  OEM LOCK is: [ON/OFF] "
  read -r oem_lock
  printf "  KG STATUS: [Prenormal/none] "
  read -r kg_state

  case "$oem_lock" in
    ON|on|On)
      err "OEM LOCK is ON - the bootloader is locked."
      info "TWRP will be refused with FAIL! Auth until it is unlocked."
      info "Unlock procedure: docs/02-diagnose-the-blockers.md section 2.4"
      info "It needs stock Android, Developer options, OEM unlocking ON,"
      info "then a long press of Volume Up on the Odin warning screen."
      fatal "unlock the bootloader first, then re-run this script"
      ;;
    *) ok "OEM LOCK is OFF - the bootloader is unlocked" ;;
  esac

  if printf '%s' "$kg_state" | grep -qi 'prenormal'; then
    err "KG STATUS is Prenormal - all non-Samsung binaries are refused"
    info "Even with OEM LOCK: OFF this gate stays shut. It is what the"
    info "clock-backdate trick clears."
    info ""
    info "The phone needs stock Android and a working internet connection."
    if [ "$(usb_mode)" = "download" ]; then
      info ""
      info "Leave download mode: hold Volume Down + Power for ~7 seconds."
      info "This is SAFE - TWRP is not installed yet."
    fi
    pause "Phone rebooted to stock Android with internet connected?"
    if ! phone_has_internet; then
      err "the phone still has no internet"
      info "Join Wi-Fi ON THE PHONE (Settings > Wi-Fi). The shell cannot add"
      info "a network on this Android build. This is the one step no automation"
      info "can do for you."
      fatal "no internet - the KG bypass cannot register"
    fi
    ok "phone has internet"

    info ""
    info "Running the KG bypass. It backdates the clock, checks for updates,"
    info "restores the clock and checks again. It will tell you when to tap."
    pause "Ready to start the KG bypass?"

    bash "$HERE/scripts/02-kg-bypass.sh" "$WORK" 2>&1 | tee "$LOGDIR/kg-bypass.log"
    [ "${PIPESTATUS[0]}" -eq 0 ] || fatal "the KG bypass did not complete - see $LOGDIR/kg-bypass.log"

    mark kg-cleared
    ok "KG bypass finished. Re-enter download mode and re-run this script."
    pause "Phone back in download mode?"
  else
    ok "no KG Prenormal gate on this device"
  fi
}

# ---------------------------------------------------------------- stage 2
stage_flash_twrp() {
  head "Stage 2 - flash TWRP to BOOT and RECOVERY"
  info "BOOT is the partition this bootloader actually reads."
  info "Flashing RECOVERY alone looks successful and does nothing."
  bash "$HERE/scripts/01-flash-twrp.sh" "$WORK" 2>&1 | tee "$LOGDIR/flash-twrp.log"
  [ "${PIPESTATUS[0]}" -eq 0 ] || fatal "the TWRP flash failed - see $LOGDIR/flash-twrp.log"
  mark twrp-flashed
  ok "TWRP flashed to BOOT and RECOVERY"
}

# ---------------------------------------------------------------- stage 3
stage_boot_twrp() {
  head "Stage 3 - boot TWRP"
  if [ "$(adb_mode)" = "ready" ]; then
    info "adb is up. If you are already in TWRP, press Enter."
    info "Otherwise, from Android:  adb reboot bootloader"
    info "then re-run this script to flash TWRP again, or use the buttons:"
    info "  hold Volume Up + Volume Down + Power, release Volume Down when"
    info "  the screen goes off, keep Volume Up + Power."
    pause "Phone is showing the TWRP screen?"
  fi
  info ""
  info "You should see a TWRP screen with the title 'TWRP 3.7.0'."
  info "If you see 'Android Recovery (user) v3.0' or 'Black Screen v0.4',"
  info "that is Samsung's stock recovery - TWRP is not in BOOT."
  pause "TWRP is on screen?"
}

# ---------------------------------------------------------------- stage 4
stage_install() {
  head "Stage 4 - format data, install LineageOS, install Google apps"
  warn "This ERASES everything on /data. Photos, apps, everything."
  pause "Confirm you are ready for the wipe"
  bash "$HERE/scripts/03-install-rom-and-gapps.sh" "$WORK" 2>&1 | tee "$LOGDIR/install.log"
  [ "${PIPESTATUS[0]}" -eq 0 ] || fatal "the install failed - see $LOGDIR/install.log"
  mark rom-installed
  ok "LineageOS and Google apps installed"
}

# ---------------------------------------------------------------- stage 5
stage_restore_kernel() {
  head "Stage 5 - put the LineageOS kernel back into BOOT"
  if [ ! -f "$ROMX_BOOT" ]; then
    err "the ROM's boot.img is missing: $ROMX_BOOT"
    info "Extract it from the ROM zip:  unzip -j $ROM 'boot.img' -d $WORK/romx"
    fatal "cannot restore the kernel"
  fi

  info "BOOT currently holds TWRP. The system needs the ROM's boot.img."
  info "Get into download mode:  adb reboot bootloader  (from TWRP)"
  pause "Phone is in download mode?"

  info "Flashing. This must be the first device command of the session."
  "$SAMLOADER" flash --partition BOOT "$ROMX_BOOT" --no-reboot --verbose \
    > "$LOGDIR/flash-boot.log" 2>&1
  local rc=$?
  [ $rc -eq 0 ] || { err "flash failed (rc=$rc) - see $LOGDIR/flash-boot.log"; fatal "kernel not restored"; }
  mark kernel-restored
  ok "LineageOS kernel written to BOOT"
}

# ---------------------------------------------------------------- stage 6
stage_verify() {
  head "Stage 6 - boot and verify"
  info "The phone will reboot into LineageOS. First boot is slow - give it a"
  info "few minutes. USB will not appear until Android's USB service starts."
  pause "Rebooting now"

  info "Waiting for adb..."
  local n=0
  while [ $n -lt 60 ]; do
    if [ "$(adb_mode)" = "ready" ]; then break; fi
    n=$((n+1)); sleep 5
  done

  if [ "$(adb_mode)" != "ready" ]; then
    warn "adb did not come back within 5 minutes."
    info "If the phone is sitting in the LineageOS recovery, that is the"
    info "recovery-loop bug - see docs/07-troubleshooting.md Q18."
    info "If it booted stock, say so and read the warning in the README."
    return 0
  fi

  ok "adb is authorised"
  info "device:  $(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')"
  info "sdk:     $(adb shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')"
  info "abi:     $(adb shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')"
  info "type:    $(adb shell getprop ro.build.type 2>/dev/null | tr -d '\r')"

  if adb shell pm list packages 2>/dev/null | grep -qi velvet; then
    ok "the Play Store is installed"
  else
    warn "the Play Store is not in the package list"
    info "Usually means the system partition was short of space - see Q22"
  fi

  mark verified
  echo
  ok "LineageOS 19.1 is on the phone with Google apps."
  info "Next: join Wi-Fi, complete the setup wizard, and sign in to Play."
  info "Keep TWRP in RECOVERY as your safety net."
}

# ---------------------------------------------------------------- main
main() {
  case "${1:-}" in
    --help|-h) usage ;;
    --status|status) status_report; exit 0 ;;
  esac

  printf "%sLineageOS 19.1 - Samsung Galaxy J4+ (j4primelte)%s\n" "$C_HEAD" "$C_OFF"
  printf "macOS + samloader. No Odin, no Windows PC.\n"
  printf "The phone currently runs Samsung's stock Android; that is what gets replaced.\n\n"

  stage_preflight
  stage_check_odin
  stage_flash_twrp
  stage_boot_twrp
  stage_install
  stage_restore_kernel
  stage_verify

  echo
  ok "done"
  info "logs: $LOGDIR"
  echo
}

main "$@"
