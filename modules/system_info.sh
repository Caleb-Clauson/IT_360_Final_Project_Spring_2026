#!/usr/bin/env bash

set -u

log_msg() {
    local msg="$1"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [system_info] $msg" >> "$COLLECTION_LOG"
}

warn_msg() {
    local msg="$1"
    [[ -n "${WARNINGS_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [system_info] WARNING: $msg" >> "$WARNINGS_FILE"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [system_info] WARNING: $msg" >> "$COLLECTION_LOG"
}

log_msg "Starting system information collection"

if [[ -z "${RAW_DIR:-}" ]]; then
    exit 1
fi

if [[ -f /etc/os-release ]]; then
    cat /etc/os-release > "$RAW_DIR/os-release.txt" 2>/dev/null || warn_msg "Failed to collect /etc/os-release"
else
    echo "No /etc/os-release file found" > "$RAW_DIR/os-release.txt"
    warn_msg "/etc/os-release not found"
fi

if command -v uname >/dev/null 2>&1; then
    uname -a > "$RAW_DIR/uname.txt" 2>/dev/null || warn_msg "Failed to run uname -a"
else
    echo "uname command not available" > "$RAW_DIR/uname.txt"
    warn_msg "uname command not available"
fi

if command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl > "$RAW_DIR/hostname.txt" 2>/dev/null || warn_msg "Failed to run hostnamectl"
elif command -v hostname >/dev/null 2>&1; then
    hostname > "$RAW_DIR/hostname.txt" 2>/dev/null || warn_msg "Failed to run hostname"
else
    echo "hostname/hostnamectl not available" > "$RAW_DIR/hostname.txt"
    warn_msg "hostname and hostnamectl unavailable"
fi

if command -v date >/dev/null 2>&1; then
    date > "$RAW_DIR/date.txt" 2>/dev/null || warn_msg "Failed to run date"
else
    echo "date command not available" > "$RAW_DIR/date.txt"
    warn_msg "date command not available"
fi

if command -v uptime >/dev/null 2>&1; then
    uptime > "$RAW_DIR/uptime.txt" 2>/dev/null || warn_msg "Failed to run uptime"
else
    echo "uptime command not available" > "$RAW_DIR/uptime.txt"
    warn_msg "uptime command not available"
fi

if command -v df >/dev/null 2>&1; then
    df -h > "$RAW_DIR/df.txt" 2>/dev/null || warn_msg "Failed to run df -h"
else
    echo "df command not available" > "$RAW_DIR/df.txt"
    warn_msg "df command not available"
fi

if command -v lsblk >/dev/null 2>&1; then
    lsblk > "$RAW_DIR/lsblk.txt" 2>/dev/null || warn_msg "Failed to run lsblk"
else
    echo "lsblk command not available" > "$RAW_DIR/lsblk.txt"
    warn_msg "lsblk command not available"
fi

log_msg "Completed system information collection"
exit 0
