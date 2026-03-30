#!/usr/bin/env bash

set -u

log_msg() {
    local msg="$1"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [user_activity] $msg" >> "$COLLECTION_LOG"
}

warn_msg() {
    local msg="$1"
    [[ -n "${WARNINGS_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [user_activity] WARNING: $msg" >> "$WARNINGS_FILE"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [user_activity] WARNING: $msg" >> "$COLLECTION_LOG"
}

log_msg "Starting user activity collection"

if [[ -z "${RAW_DIR:-}" ]]; then
    exit 1
fi

if command -v who >/dev/null 2>&1; then
    who > "$RAW_DIR/who.txt" 2>/dev/null || warn_msg "Failed to run who"
else
    echo "who command not available" > "$RAW_DIR/who.txt"
    warn_msg "who command not available"
fi

if command -v last >/dev/null 2>&1; then
    last -a | head -n 50 > "$RAW_DIR/last_50.txt" 2>/dev/null || warn_msg "Failed to run last -a"
else
    echo "last command not available" > "$RAW_DIR/last_50.txt"
    warn_msg "last command not available"
fi

if [[ -f /var/log/auth.log ]]; then
    cp /var/log/auth.log "$RAW_DIR/auth.log.txt" 2>/dev/null || tail -n 300 /var/log/auth.log > "$RAW_DIR/auth.log.txt" 2>/dev/null || warn_msg "Failed to collect /var/log/auth.log"
elif [[ -f /var/log/secure ]]; then
    cp /var/log/secure "$RAW_DIR/secure.log.txt" 2>/dev/null || tail -n 300 /var/log/secure > "$RAW_DIR/secure.log.txt" 2>/dev/null || warn_msg "Failed to collect /var/log/secure"
elif command -v journalctl >/dev/null 2>&1; then
    journalctl -n 300 --no-pager > "$RAW_DIR/journalctl_auth_fallback.txt" 2>/dev/null || warn_msg "Failed to collect journalctl fallback logs"
else
    echo "No auth log source found" > "$RAW_DIR/auth_logs_missing.txt"
    warn_msg "No auth.log, secure log, or usable journalctl source found"
fi

if [[ -f /etc/passwd ]]; then
    cp /etc/passwd "$RAW_DIR/passwd.txt" 2>/dev/null || warn_msg "Failed to collect /etc/passwd"
fi

log_msg "Completed user activity collection"
exit 0
