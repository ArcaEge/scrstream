#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"$script_dir/adb-connect.sh"

"$script_dir/unlock-phone.sh" &
unlock_pid=$!

cache="${XDG_CACHE_HOME:-$HOME/.cache}/scrcpy-apps"
mkdir -p "$(dirname "$cache")"

# Refresh the cache in the background.
(
    tmp="${cache}.tmp"

    scrcpy --list-apps 2>/dev/null |
        grep -E '^[[:space:]]*[*-][[:space:]]*' |
        sort -f -k2 |
        sed 's/^[[:space:]]*[*-][[:space:]]*//' > "$tmp" &&
        mv "$tmp" "$cache"
) &

# On the first run, wait for the cache to be populated.
if [[ ! -s "$cache" ]]; then
    wait
fi

selection="$(
    {
        printf '%s\n' '▶ Screen'
        cat "$cache"
    } |
        rofi -dmenu -i -p "Android app"
)"

if [[ -z "$selection" ]]; then
    wait "$unlock_pid"
    sleep 0.1

    if ! pgrep -x scrcpy >/dev/null; then
        if adb shell dumpsys window | grep -q 'mDreamingLockscreen=false'; then
            adb shell input keyevent KEYCODE_SLEEP
        fi
    fi
    exit 0
fi

wait "$unlock_pid"

pkg="${selection##* }"

if [[ "$selection" == "▶ Screen" ]]; then
    exec scrcpy --video-codec=av1 -b16M --power-off-on-close
else
    exec scrcpy \
        --new-display=1920x1080/200 \
        --flex-display \
        --video-codec=av1 \
        -b16M \
        --start-app="$pkg" \
        --no-vd-system-decorations --power-off-on-close
fi

sleep 0.1
adb shell input keyevent KEYCODE_SLEEP

# if ! pgrep -x scrcpy >/dev/null; then
    # if adb shell dumpsys window | grep -q 'mDreamingLockscreen=false'; then
    #     adb shell input keyevent KEYCODE_SLEEP
    # fi
# fi
