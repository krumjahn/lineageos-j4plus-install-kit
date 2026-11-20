#!/usr/bin/env bash
#
# 02-kg-bypass.sh - clear Samsung KG State: Prenormal without a SIM, without a
# Google account, and without a Windows PC.
#
#   The phone stays on Samsung's stock Android for this step - it has to reach
#   Samsung's update server. The COMPUTER you run this from does not have to be
#   Windows, and does not have to run Odin.
#
#   bash 02-kg-bypass.sh [working-dir]
#
# THE METHOD
#   Samsung's update server records "this device checked for updates at time T"
#   against the device's clock. Backdate the clock, check for updates, restore the
#   clock, check again, and the record is more than seven days old - which clears
#   the Prenormal state.
#
# THE TRAP
#   A backdated clock breaks every TLS handshake. The certificate chain's notBefore
#   is the hard floor on how far back you can go. The method wants MORE than seven
#   days; TLS allowed exactly nine when this was last measured. The window closes
#   by one day every day that passes, so it must be measured, not assumed.
#
# THIS SCRIPT
#   1. probes the certificate chain from the Mac and computes the safe backdate
#   2. sets the phone clock (auto_time off, then cmd alarm set-time)
#   3. reboots and toggles the radio
#   4. drives the software update check using scripts/adb-ui.py
#   5. verifies the success marker reads "at HH:MM", not "on <date>"
#
# It stops before anything irreversible. It does not touch partitions.

set -uo pipefail

WORK="${1:-$HOME/Desktop/j4-flash}"
LOGDIR="$WORK/kg"
UI="$WORK/adb-ui.py"
HOST="https://www.google.com"
MIN_DAYS=8          # the method wants more than seven
MAX_DAYS=9          # measured TLS floor when the certificate was checked

# Logs and the UI driver live under WORK. Refuse a relative working directory.
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

mkdir -p "$LOGDIR"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
bad()  { printf '  \033[31m%s\033[0m\n' "$*" >&2; }
die()  { bad "$*"; exit 1; }

# Portable epoch -> local date. macOS uses `date -r`, Linux uses `date -d @`.
epoch_year() {
  if [ "$(uname -s)" = "Darwin" ]; then
    date -r "$1" '+%Y'
  else
    date -d "@$1" '+%Y'
  fi
}

# Bounded wait for adb to come back after a reboot.
wait_for_adb() {
  local tries=0
  until adb devices | grep -qE '^\S+\s+device$'; do
    tries=$((tries + 1))
    [ "$tries" -gt 60 ] && { bad "adb did not come back within 5 minutes"; return 1; }
    sleep 5
  done
  return 0
}

# ---------------------------------------------------------------- 0. preconditions
say "0. preconditions"

command -v adb >/dev/null 2>&1 || die "adb not found"
adb devices | grep -qE '^\S+\s+device$' || die "no authorised adb device"
[ -f "$UI" ] || die "adb-ui.py not found at $UI (copy scripts/adb-ui.py into $WORK)"

info "device: $(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')"

# The phone MUST have internet. After a factory reset the saved Wi-Fi networks are
# gone and Android 9's shell cannot add one - a human has to do it by hand.
if ! adb shell ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1; then
  die "the phone has no internet.
       The KG bypass needs Samsung's update server to be reachable.
       Join Wi-Fi ON THE PHONE (Settings > Wi-Fi), then re-run this script."
fi
info "internet: reachable"

# ---------------------------------------------------------------- 1. TLS floor
say "1. probing the TLS floor"

# The certificate chain, fetched from the Mac, is what limits the backdate.
# We take the EARLIEST notBefore in the chain as the floor.
notbefore="$(echo | openssl s_client -connect "${HOST#https://}:443" -servername "${HOST#https://}" 2>/dev/null \
  | openssl x509 -noout -startdate 2>/dev/null \
  | sed 's/notBefore=//')"

if [ -z "$notbefore" ]; then
  bad "could not read the certificate chain - cannot compute a safe backdate."
  info "Check the phone's internet instead, and pick a backdate of $MIN_DAYS-$MAX_DAYS days."
  die "stopping rather than guessing"
fi

info "certificate notBefore: $notbefore"

# Days between the certificate's notBefore and today.
floor_days="$(python3 - "$notbefore" <<'PY'
import sys, datetime
raw = sys.argv[1].strip()
for fmt in ("%b %d %H:%M:%S %Y %Z", "%b %d %H:%M:%S %Y"):
    try:
        nb = datetime.datetime.strptime(raw, fmt).replace(tzinfo=datetime.timezone.utc)
        break
    except ValueError:
        continue
else:
    print(-1); raise SystemExit
now = datetime.datetime.now(datetime.timezone.utc)
print(max(0, (now - nb).days))
PY
)"

if [ "$floor_days" -lt 0 ]; then
  bad "could not parse the certificate date"
  die "stopping rather than guessing"
fi

info "certificate has been valid for $floor_days days"
info "the method needs more than $MIN_DAYS days; TLS allows at most $floor_days"

if [ "$floor_days" -lt "$MIN_DAYS" ]; then
  die "the TLS window has closed: we can only go back $floor_days days but the
       method needs more than $((MIN_DAYS - 1)). Every day that passes makes this
       worse, not better. Options: the 7-day online lockout window, or a paid
       Windows tool. See docs/03-kg-prenormal-bypass.md."
fi

DAYS="$MAX_DAYS"
[ "$floor_days" -lt "$DAYS" ] && DAYS="$floor_days"
info "using a backdate of $DAYS days"

# ---------------------------------------------------------------- 2. set the clock
say "2. setting the phone clock"

REAL_EPOCH="$(date +%s)"
FAKE_EPOCH=$((REAL_EPOCH - DAYS * 86400))

adb shell settings put global auto_time 0
adb shell cmd alarm set-time $((FAKE_EPOCH * 1000))
sleep 1

device_date="$(adb shell date 2>/dev/null | tr -d '\r')"
info "phone now says: $device_date"

case "$device_date" in
  *"$(epoch_year "$FAKE_EPOCH")"*) info "clock set - year matches the target" ;;
  *) die "the clock did not take. Check 'cmd alarm set-time' works on this build." ;;
esac

say "2b. rebooting so the fake date persists"
adb reboot
sleep 20
wait_for_adb || die "adb never came back after the reboot"

device_date="$(adb shell date 2>/dev/null | tr -d '\r')"
info "after reboot: $device_date"
case "$device_date" in
  *"$(epoch_year "$FAKE_EPOCH")"*) info "the fake date survived the reboot" ;;
  *) die "the fake date did NOT survive the reboot - the check would register
       against the real date and silently do nothing." ;;
esac

# ---------------------------------------------------------------- 3. the check
say "3. software update check (backdated)"

adb shell settings put system screen_off_timeout 1800000
adb shell svc power stayon true
adb shell input keyevent 224
adb shell wm dismiss-keyguard

adb shell svc wifi enable
adb shell am start -a android.settings.SYSTEM_UPDATE_SETTINGS
sleep 6

info "visible text before the check:"
python3 "$UI" texts | tee "$LOGDIR/text-before.txt"

info "tapping the update button..."
python3 "$UI" tap-any "Check for update" "Download and install" "Check" \
  | tee "$LOGDIR/tap.txt"

say "waiting for the check to complete (60s)"
sleep 60

python3 "$UI" texts | tee "$LOGDIR/text-after.txt"

# The marker is the ONLY reliable success signal.
#   "... at HH:MM"  -> stored date equals today's date (good)
#   "... on Nov 13" -> stored date is older (a stale check, not ours)
if grep -qE "successful check.*at [0-9]{2}:[0-9]{2}" "$LOGDIR/text-after.txt"; then
  info "SUCCESS marker found: the backdated check registered"
else
  bad "no 'at HH:MM' marker found."
  info "Look at $LOGDIR/text-after.txt."
  info "If it says 'on <date>', that is a STALE check from the real date - the"
  info "backdated check did not register and the procedure has not worked."
  info "Also verify the phone has internet and the clock is still backdated."
  exit 2
fi

# ---------------------------------------------------------------- 4. restore
say "4. restoring the clock and doing the second check"

adb shell svc wifi disable
adb reboot
sleep 20
wait_for_adb || die "adb never came back after the reboot"

adb shell settings put global auto_time 1
sleep 2
info "clock restored to: $(adb shell date 2>/dev/null | tr -d '\r')"

adb shell svc wifi enable
adb shell am start -a android.settings.SYSTEM_UPDATE_SETTINGS
sleep 6
python3 "$UI" tap-any "Check for update" "Download and install" "Check"
sleep 60
python3 "$UI" texts | tee "$LOGDIR/text-after2.txt"

if grep -qE "successful check.*at [0-9]{2}:[0-9]{2}" "$LOGDIR/text-after2.txt"; then
  info "SUCCESS marker found for the second check"
else
  warn "the second check marker was not found - check $LOGDIR/text-after2.txt"
fi

say "5. confirm"
info "1. Developer options should now say 'OEM unlocking: Bootloader already unlocked'"
info "2. The Odin screen should show 'KG STATUS: Checking' or no KG line"
info "3. Then flash TWRP:  bash 01-flash-twrp.sh"
echo
info "logs: $LOGDIR"
