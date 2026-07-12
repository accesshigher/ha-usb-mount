#!/bin/sh
set -e

echo "=== USB Mount Add-on Starting ==="
sleep 10

MOUNTS_JSON=$(cat /data/options.json)

echo "$MOUNTS_JSON" | jq -r '.mounts[] | "$$.label) $$.target)"' | while read label target; do
    HOST_PATH="/mnt/data/supervisor/media/$target"
    echo ""
    echo "--- Processing: $label -> $target ---"

    device=""
    for i in $(seq 1 30); do
        device=$(blkid -L "$label" 2>/dev/null || true)
        if [ -n "$device" ] && [ -b "$device" ]; then
            echo "Found device: $device (label: $label)"
            break
        fi
        echo "Waiting for label '$label'... ($i/30)"
        sleep 2
    done

    if [ -z "$device" ] || [ ! -b "$device" ]; then
        echo "ERROR: No device found for label '$label' after 60 seconds"
        echo "Available block devices:"
        lsblk 2>/dev/null || true
        echo "All blkid results:"
        blkid 2>/dev/null || true
        continue
    fi

    fstype=$(blkid "$device" -o value -s TYPE 2>/dev/null || echo "ext4")
    echo "Filesystem: $fstype"

    echo "Creating mount point: $HOST_PATH"
    nsenter -t 1 -m -- mkdir -p "$HOST_PATH"

    if nsenter -t 1 -m -- mountpoint -q "$HOST_PATH" 2>/dev/null; then
        echo "Already mounted: $target (skipping)"
        continue
    fi

    echo "Mounting $device to $HOST_PATH..."
    if nsenter -t 1 -m -- mount "$device" "$HOST_PATH" -t "$fstype" -o rw,relatime; then
        echo "Mount command succeeded"
    else
        echo "ERROR: Mount command failed for $device"
        continue
    fi

    if nsenter -t 1 -m -- mountpoint -q "$HOST_PATH"; then
        echo "SUCCESS: $target is mounted and verified"
        nsenter -t 1 -m -- df -h "$HOST_PATH" 2>/dev/null || true
    else
        echo "FAILED: $target mount verification failed"
    fi
done

echo ""
echo "=== All mounts processed. Add-on staying alive. ==="
tail -f /dev/null
