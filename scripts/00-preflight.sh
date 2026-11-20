#!/usr/bin/env bash
#
# 00-preflight.sh - check the host, the tools, the downloads and the device
# before anything is flashed.
#
#   bash 00-preflight.sh [working-dir]
#
# Read-only. It never touches the phone in a way that consumes an Odin session.

set -uo pipefail

WORK="${1:-$HOME/Desktop/j4-flash}"

TWRP="twrp-3.7.0_j4primelte.img"
TWRP_SHA256="7dabdee3b26dd5781593690f61a927630d14e3fd61233c2894666029ee518632"
TWRP_MD5="0be9a3683a81fc8d255953e94bb77ae9"

ok=0
fail=0

pass() { printf '  \033[32mok\033[0m    %s\n' "$1"; ok=$((ok+1)); }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); }

echo
echo "== host =="
case "$(uname -s)" in
  Darwin) pass "macOS $(sw_vers -productVersion) ($(uname -m))" ;;
  Linux)  pass "Linux $(uname -r) ($(uname -m))" ;;
  *)      warn "$(uname -s) is not macOS or Linux - samloader has Windows builds too" ;;
esac

echo
echo "== tools =="

# adb is often only in the Android SDK, not on PATH. Look in the usual places
# before declaring it missing - people get a false failure otherwise.
if ! command -v adb >/dev/null 2>&1; then
  for candidate in \
      "${ANDROID_HOME:-}/platform-tools/adb" \
      "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
      "$HOME/Library/Android/sdk/platform-tools/adb" \
      "$HOME/Android/Sdk/platform-tools/adb"; do
    if [ -x "$candidate" ]; then
      adb_dir="$(dirname "$candidate")"
      export PATH="$adb_dir:$PATH"
      break
    fi
  done
fi

if command -v adb >/dev/null 2>&1; then
  pass "adb: $(command -v adb)"
else
  bad "adb not found - install Android platform-tools, or set ANDROID_HOME"
fi

if command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1; then
  pass "sha256 tool present"
else
  bad "no shasum/sha256sum - cannot verify downloads"
fi

# samloader: accept the name used in this kit or a stock build on PATH.
SAMLOADER=""
for candidate in "$WORK/samloader-longtimeout" "$WORK/samloader" "$(command -v samloader 2>/dev/null)"; do
  [ -n "$candidate" ] && [ -x "$candidate" ] && { SAMLOADER="$candidate"; break; }
done
if [ -n "$SAMLOADER" ]; then
  pass "samloader: $SAMLOADER"
  "$SAMLOADER" --version 2>/dev/null | head -1 | sed 's/^/        /'
  echo "        check the flags your build supports:"
  echo "          $SAMLOADER flash --help"
else
  bad "no samloader binary found (looked for $WORK/samloader-longtimeout and samloader on PATH)"
fi

echo
echo "== downloads =="
echo "  working directory: $WORK"
if [ -d "$WORK" ]; then
  pass "working directory exists"
else
  warn "working directory does not exist - create it and put the files there"
fi

if [ -f "$WORK/$TWRP" ]; then
  actual="$(shasum -a 256 "$WORK/$TWRP" 2>/dev/null | awk '{print $1}')"
  if [ "$actual" = "$TWRP_SHA256" ]; then
    pass "$TWRP sha256 verified"
  else
    bad "$TWRP sha256 MISMATCH"
    echo "        expected $TWRP_SHA256"
    echo "        actual   $actual"
    if [ "$(wc -c < "$WORK/$TWRP" | tr -d ' ')" = "6885" ]; then
      echo "        -> 6885 bytes means you got the download interstitial, not the image"
    fi
  fi
  actual_md5="$(md5 -q "$WORK/$TWRP" 2>/dev/null || md5sum "$WORK/$TWRP" 2>/dev/null | awk '{print $1}')"
  if [ "$actual_md5" = "$TWRP_MD5" ]; then
    pass "$TWRP md5 verified"
  else
    warn "$TWRP md5 does not match the published value"
  fi
else
  warn "$TWRP not found in $WORK"
fi

echo
echo "== device =="
# ioreg never consumes the Odin session, so it is safe to call here.
if [ "$(uname -s)" = "Darwin" ]; then
  if ioreg -p IOUSB -w0 2>/dev/null | grep -qE 'MSM8953'; then
    pass "phone is in download mode (MSM8953)"
    echo "        REMEMBER: one download-mode entry = one protocol session."
    echo "        Make the flash the FIRST device command."
  elif ioreg -p IOUSB -w0 2>/dev/null | grep -qE 'SAMSUNG_Android'; then
    pass "phone is enumerated as SAMSUNG_Android"
  else
    warn "no Samsung USB device found"
  fi
fi

if command -v adb >/dev/null 2>&1; then
  if adb devices | grep -qE '^\S+\s+device$'; then
    pass "adb device authorised"
    adb shell getprop ro.product.device 2>/dev/null | sed 's/^/        device: /'
    adb shell getprop ro.build.version.sdk 2>/dev/null | sed 's/^/        sdk:    /'
    adb shell getprop ro.product.cpu.abi 2>/dev/null | sed 's/^/        abi:    /'
  elif adb devices | grep -q 'unauthorized'; then
    bad "adb device is unauthorised - tick 'Always allow from this computer' on the phone"
  else
    warn "no authorised adb device"
  fi
fi

echo
echo "== reminders =="
cat <<'EOF'
  * Always --no-reboot on samloader commands.
  * The flash must be the FIRST device command of a session.
  * Never pipe a live device session into head or grep - log to a file.
  * This bootloader loads BOOT, not RECOVERY. Flash TWRP to both.
  * Never boot the phone back into stock once TWRP is in BOOT.
EOF

echo
echo "passed: $ok   failed: $fail"
echo
[ "$fail" -eq 0 ] || exit 1
