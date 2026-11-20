#!/usr/bin/env bash
#
# 03-install-rom-and-gapps.sh - format data, install LineageOS, install Google apps.
#
#   bash 03-install-rom-and-gapps.sh [working-dir]
#
# Run this with TWRP running and ADB authorised.
#
# It asks before anything irreversible.
#
# NOTE ON ORDER: Format data -> ROM -> Google apps. The Google apps installer
# patches /system, so anything installed before the ROM is overwritten by it.

set -uo pipefail

WORK="${1:-$HOME/Desktop/j4-flash}"
LOGDIR="$WORK/install"
ROM="${ROM:-$WORK/lineage-19.1-20231011-UNOFFICIAL-j4primelte.zip}"
GAPS="${GAPS:-$WORK/MindTheGapps-12.1.0-arm-20231025_200802.zip}"
MTG_DIR="${MTG_DIR:-$WORK/mtg}"
GAPS_SHA_SIZE=228186029

mkdir -p "$LOGDIR"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
bad()  { printf '  \033[31m%s\033[0m\n' "$*" >&2; }
die()  { bad "$*"; exit 1; }

confirm() {
  printf '\n  %s [y/N] ' "$1"
  read -r reply
  case "$reply" in [yY]*) return 0 ;; *) die "aborted at: $1" ;; esac
}

# ---------------------------------------------------------------- 0. preconditions
say "0. preconditions"

command -v adb >/dev/null 2>&1 || die "adb not found"
adb devices | grep -qE '^\S+\s+device$' || die "no authorised adb device"

# Confirm we are in TWRP, not the LineageOS recovery. The `twrp` CLI only exists
# in TWRP, and TWRP is the one that can clear the boot request.
if ! adb shell 'command -v twrp' 2>/dev/null | grep -q twrp \
   && ! adb shell 'ls /sbin/twrp /system/bin/twrp 2>/dev/null' | grep -q twrp; then
  die "the twrp CLI is not available.
       Are you in TWRP? The LineageOS recovery has no 'twrp' command.
       Remember: TWRP must be flashed to BOOT, not just RECOVERY."
fi
info "TWRP detected"

[ -f "$ROM" ] || die "ROM not found: $ROM (override with ROM=/path/to.zip)"
[ -f "$GAPS" ] || die "MindTheGapps not found: $GAPS (override with GAPS=/path/to.zip)"

rom_bytes="$(wc -c < "$ROM" | tr -d ' ')"
gaps_bytes="$(wc -c < "$GAPS" | tr -d ' ')"
info "ROM:          $rom_bytes bytes"
info "MindTheGapps: $gaps_bytes bytes"

if [ "$gaps_bytes" != "$GAPS_SHA_SIZE" ]; then
  bad "MindTheGapps size does not match the published release ($GAPS_SHA_SIZE)."
  bad "Do not continue with a package of the wrong size or the wrong architecture."
  confirm "Continue anyway?"
fi

# ---------------------------------------------------------------- 1. format data
say "1. format data"

info "Samsung encryption is not supported by TWRP on this device, so this must be"
info "a FORMAT (not a Wipe). It erases /data completely."

adb shell "df -h /data" 2>/dev/null | sed 's/^/        /'
confirm "Erase /data? This cannot be undone."

adb shell "twrp format data" 2>&1 | tee "$LOGDIR/format-data.log"
info "format finished - check the log above for errors"

# ---------------------------------------------------------------- 2. push the ROM
say "2. push the ROM"

adb shell mkdir -p /sdcard/j4
info "pushing $(basename "$ROM") (about 619 MB, roughly 20-30 seconds)"
adb push "$ROM" /sdcard/j4/ > "$LOGDIR/push-rom.log" 2>&1 || die "push failed - see $LOGDIR/push-rom.log"
info "pushed"

# ---------------------------------------------------------------- 3. install the ROM
say "3. install the ROM"

info "this takes several minutes"
info "watch it with:  adb shell tail -f /tmp/recovery.log"

adb shell "twrp install /sdcard/j4/$(basename "$ROM")" 2>&1 | tee "$LOGDIR/install-rom.log"

if grep -qiE "Updater process ended with ERROR|^E: |failed to (install|apply|mount)" "$LOGDIR/install-rom.log"; then
  bad "the install log reports an error - read it before doing anything else."
  info "if it died during the system write, /tmp may have been too small:"
  info "  TWRP /tmp is tmpfs with roughly 899 MB, and the system partition is 2.39 GB."
  info "  The fallback is to convert system.new.dat.br on the Mac and write the"
  info "  raw image - see docs/05-install-lineageos-and-gapps.md."
  info "  NOTE: a raw write over /system erases the Google apps, so do that first."
  die "stopping here"
fi

info "verifying the install"
adb shell 'cat /system/build.prop' 2>/dev/null | grep -E "ro.build.version.sdk|ro.product.cpu.abi|ro.build.type|lineage_j4primelte" | sed 's/^/        /'

sdk="$(adb shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')"
abi="$(adb shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')"
info "sdk=$sdk  abi=$abi"

case "$abi" in
  *arm64*) bad "the ROM reports arm64. This kit is for a 32-bit ARM device." ;;
  armeabi-v7a) info "32-bit ARM - correct for this device" ;;
  *) warn "unexpected ABI: $abi" ;;
esac

# ---------------------------------------------------------------- 4. space check
say "4. free space in /system"

free_kb="$(adb shell 'df -k /system' 2>/dev/null | tail -1 | awk '{print $4}')"
if [ -n "$free_kb" ] && [ "$free_kb" -lt 500000 ]; then
  bad "only $((free_kb / 1024)) MB free in /system."
  bad "MindTheGapps will silently strip the Play Store if there is not enough room."
  info "Free some space, or skip the Google apps and install them later."
  confirm "Continue with the Google apps anyway?"
fi
info "space looks fine"

# ---------------------------------------------------------------- 5. Google apps
say "5. install Google apps"

info "extracting MindTheGapps' update-binary"
rm -rf "$MTG_DIR"
mkdir -p "$MTG_DIR"
unzip -o -j "$GAPS" '*update-binary*' -d "$MTG_DIR" >/dev/null 2>&1 \
  || die "could not extract update-binary from $GAPS"

UPDATE_BINARY="$(find "$MTG_DIR" -name 'update-binary' -type f | head -1)"
[ -n "$UPDATE_BINARY" ] || die "update-binary not found inside $GAPS"
info "found: $UPDATE_BINARY"

info "pushing to the device"
adb push "$UPDATE_BINARY" /data/update-binary >/dev/null 2>&1 || die "push failed"
adb push "$GAPS" /data/mtg.zip >/dev/null 2>&1 || die "push failed"

info "running the installer (several minutes)"
adb shell "sh /data/update-binary /data 1 /data/mtg.zip" 2>&1 | tee "$LOGDIR/gapps.log"

say "6. verify"

for path in \
  /system/product/priv-app/Velvet/Velvet.apk \
  /system/product/priv-app/GmsCore/GmsCore.apk \
  /system/product/etc/permissions/privapp-permissions-google-product.xml \
  /system/system_ext/etc/permissions/privapp-permissions-google-system-ext.xml \
  /system/addon.d/30-gapps.sh ; do
  if adb shell "test -e $path" 2>/dev/null; then
    info "ok   $path"
  else
    bad "MISSING $path"
  fi
done

if adb shell 'test -e /system/product/priv-app/Velvet/Velvet.apk' 2>/dev/null; then
  info "the Play Store is present"
else
  bad "the Play Store is missing."
  bad "The usual cause is not enough free space in /system - the installer strips"
  bad "Velvet when there is not enough room. Check step 4's output."
fi

say "7. before you reboot"
info "BOOT currently holds TWRP. The system needs the ROM's boot.img in BOOT."
info "Stage the fallbacks on the SD card now, while you still have a recovery:"
info "    adb push $WORK/romx/boot.img /sdcard/lineage-boot.img"
info "    adb push $WORK/twrp-3.7.0_j4primelte.img /sdcard/"
info "Then either:"
info "  a) adb reboot bootloader, and flash --partition BOOT romx/boot.img"
info "  b) boot TWRP and use Reboot > System"
info "NEVER let the phone boot stock Android."
info "logs: $LOGDIR"
