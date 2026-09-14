#!/usr/bin/env bash
#
# unlock-phone.sh
# Checks if a connected android device is locked, and if so, unlocks it
# using a numeric PIN pulled from KWallet.
#
# Requirements:
#   - adb (with the device authorized / USB debugging on)
#   - kwallet-query (usually ships with kwallet-pam or kwalletmanager)
#   - your PIN saved in kwallet under WALLET/FOLDER/ENTRY (see config below)
#
# Only works for a numeric PIN lockscreen, not pattern or biometric.
# Some OEM skins block synthetic input on the keyguard entirely, in which
# case this will just silently fail to unlock, that's a device restriction,
# not a bug in the script.

set -euo pipefail

# --- config: change these to match where you stored the PIN in kwallet ---
WALLET="kdewallet"
FOLDER="Passwords"
ENTRY="android-pin"
# ---------------------------------------------------------------------

fail() {
    echo "error: $1" >&2
    exit 1
}

# make sure a device is actually connected
device_state="$(adb get-state 2>/dev/null || true)"
if [[ "$device_state" != "device" ]]; then
    fail "no authorized adb device found (state: '${device_state:-none}')"
fi

# pull the pin out of kwallet
pin="$(kwallet-query -r "$ENTRY" -f "$FOLDER" "$WALLET" 2>/dev/null || true)"
if [[ -z "$pin" ]]; then
    fail "could not read '$ENTRY' from $WALLET/$FOLDER (wallet locked, entry missing, or kwallet-query not installed)"
fi
if ! [[ "$pin" =~ ^[0-9]+$ ]]; then
    fail "entry '$ENTRY' doesn't look like a numeric PIN, refusing to send it"
fi

# check lock state. this varies across android versions/OEMs so we try a
# few known patterns. if none of these match on your device, run this
# script with --debug to dump the raw output and find the right string
# yourself, then add it to the grep below.
is_locked() {
    adb shell dumpsys window policy 2>/dev/null | grep -qiE \
        "mShowingLockscreen=true|isStatusBarKeyguard=true|mKeyguardDelegate\.showing=true|showing=true"
}

if [[ "${1:-}" == "--debug" ]]; then
    echo "--- raw dumpsys window policy output ---"
    adb shell dumpsys window policy 2>/dev/null
    echo "--- end ---"
    echo
    echo "look for whatever line flips between locked/unlocked states"
    echo "(lock the phone, run this, unlock it, run again, diff the two)"
    echo "then add the matching key=value pattern to the grep in is_locked()"
    exit 0
fi

if ! is_locked; then
    echo "phone is already unlocked, nothing to do"
    exit 0
fi

echo "phone is locked, attempting unlock..."

# wake the screen first in case it's asleep (not just locked)
adb shell input keyevent 82 >/dev/null   # KEYCODE_WAKEUP
adb shell input keyevent 66 >/dev/null   # KEYCODE_ENTER
sleep 1.0

# send the pin
adb shell input text "$pin" >/dev/null

# confirm (most pin screens auto-submit once enough digits are entered,
# but send enter too in case it doesn't)
adb shell input keyevent 66 >/dev/null    # KEYCODE_ENTER
sleep 0.5
