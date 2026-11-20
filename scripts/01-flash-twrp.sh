#!/usr/bin/env bash
#
# 01-flash-twrp.sh - flash TWRP to BOOT and RECOVERY in one Odin session.
#
#   bash 01-flash-twrp.sh [working-dir]
#
# WHY BOOT *AND* RECOVERY:
#   On this device the bootloader loads BOOT. The RECOVERY partition is inert for
#   booting. Flashing TWRP to RECOVERY alone produces a perfectly successful flash
#   and a phone that still boots Samsung's stock recovery. Flash both.
#
# RULES BUILT IN:
#   * the flash is the first device command of the session - nothing runs before it
#   * --no-reboot always, so the session is not burned by a default reboot
#   * output goes to a log file, never through a pipe
#
# This script does NOT detect the phone with samloader (that would consume the
# session). It uses ioreg, which cannot.

set -uo pipefail

WORK="${1:-$HOME/Desktop/j4-flash}"
TWRP="$WORK/twrp-3.7.0_j4primelte.img"
TWRP_SHA256="7dabdee3b26dd5781593690f61a927630d14e3fd61233c2894666029ee518632"
LOG="$WORK/twrp-flash.log"

# The log is written under WORK. Refuse a relative working directory so the
# script cannot drop a file somewhere unexpected.
# (Self-contained: it must run before the helper functions are defined.)
case "$WORK" in
  /*) ;;
  *)
    printf '\033[31mworking directory must be an absolute path: %s\033[0m\n' "$WORK" >&2
    exit 1
    ;;
esac
if [ "$WORK" = "/" ]; then
  printf '\033[31mrefusing to use / as the working directory\033[0m\n' >&2
  exit 1
fi

SAMLOADER=""
for candidate in "$WORK/samloader-longtimeout" "$WORK/samloader"; do
  [ -x "$candidate" ] && { SAMLOADER="$candidate"; break; }
done

die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

[ -n "$SAMLOADER" ] || die "no samloader binary in $WORK (expected samloader-longtimeout)"
[ -f "$TWRP" ] || die "TWRP image not found: $TWRP"

echo "== verifying the TWRP image =="
actual="$(shasum -a 256 "$TWRP" | awk '{print $1}')"
[ "$actual" = "$TWRP_SHA256" ] || die "sha256 mismatch
  expected $TWRP_SHA256
  actual   $actual
  (a 6885-byte file is the download interstitial, not the image)"
echo "  ok  sha256 verified"

echo
echo "== checking USB mode (ioreg cannot consume the Odin session) =="
if ioreg -p IOUSB -w0 2>/dev/null | grep -qE 'MSM8953'; then
  echo "  ok  download mode detected"
else
  echo "  !!  the phone does not look like it is in download mode."
  echo "      Put it in download mode now:  adb reboot download"
  echo "      or  Volume Up + Volume Down + Power, then Volume Up."
  printf "Continue anyway? [y/N] "
  read -r reply
  case "$reply" in [yY]*) ;; *) die "aborted" ;; esac
fi

echo
echo "== flashing TWRP to BOOT and RECOVERY =="
echo "  this is the FIRST device command of this session - do not interrupt"
echo "  log: $LOG"

# Log to a file. Never pipe a live device session through head or grep:
# SIGPIPE kills samloader mid-handshake and corrupts the session.
"$SAMLOADER" flash \
    --partition BOOT     "$TWRP" \
    --partition RECOVERY "$TWRP" \
    --no-reboot --verbose > "$LOG" 2>&1
rc=$?

echo
echo "== result (exit code $rc) =="
if [ "$rc" -ne 0 ]; then
  echo "  the command failed - the last 30 lines of the log:"
  tail -30 "$LOG"
  echo
  echo "  If it says 'FAIL! Auth', the transfer worked and the bootloader"
  echo "  refused the image. That is the bootloader lock or KG Prenormal,"
  echo "  not a transport problem. Read docs/07-troubleshooting.md."
  exit "$rc"
fi

grep -E "handshake|session|PIT|partition|written|Auth|FAIL|ERROR|closed" "$LOG" | tail -25

if grep -q "FAIL! Auth" "$LOG"; then
  echo
  echo "  !!  FAIL! Auth - bootloader lock or KG Prenormal."
  echo "      The transfer itself succeeded. See docs/02-diagnose-the-blockers.md."
  exit 2
fi

echo
echo "  ok  flash completed"
echo
echo "  NEXT: boot into TWRP and check the banner says 'TWRP 3.7.0_9-kycii91'."
echo "  If it says 'Android Recovery (user) v3.0' or 'Black Screen v0.4',"
echo "  TWRP is not in BOOT - re-run this script with a FRESH download-mode entry."
