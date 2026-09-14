#!/usr/bin/env bash

set -euo pipefail

if adb devices | awk 'NR > 1 && $2 == "device" { found=1 } END { exit !found }'
then
    exit 0
fi

# --- config: change these to match where you stored the PIN in kwallet ---
WALLET="kdewallet"
FOLDER="Passwords"
ENTRY="android-serial"

serial="$(kwallet-query -r "$ENTRY" -f "$FOLDER" "$WALLET" 2>/dev/null || true)"
if [[ -z "$serial" ]]; then
    fail "could not read '$ENTRY' from $WALLET/$FOLDER (wallet locked, entry missing, or kwallet-query not installed)"
fi

output="$(
    avahi-browse --terminate --resolve _adb-tls-connect._tcp 2>/dev/null
)"

address=""
port=""
match=0

while IFS= read -r line; do
    # Extract address
    if [[ "$line" =~ address\ =\ \[([^]]+)\] ]]; then
        address="${BASH_REMATCH[1]}"
    fi

    # Extract port
    if [[ "$line" =~ port\ =\ \[([^]]+)\] ]]; then
        port="${BASH_REMATCH[1]}"
    fi

    # Extract serial from TXT record
    if [[ "$line" =~ serial=([^\"[:space:]]+) ]]; then
        device_serial="${BASH_REMATCH[1]}"

        if [[ "$device_serial" == "$serial" ]]; then
            match=1

            if [[ -n "$address" && -n "$port" ]]; then
                break
            fi
        fi
    fi
done <<< "$output"

if (( ! match )); then
    echo "Device not found: $serial" >&2
    exit 1
fi

if [[ -z "$address" || -z "$port" ]]; then
    echo "Found $serial, but could not determine address/port" >&2
    exit 1
fi

echo "Connecting to $serial at $address:$port"

adb connect "$address:$port"
