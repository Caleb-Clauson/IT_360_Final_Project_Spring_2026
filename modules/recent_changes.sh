#!/usr/bin/env bash

set -u

log_msg() {
    local msg="$1"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [recent_changes] $msg" >> "$COLLECTION_LOG"
}

warn_msg() {
    local msg="$1"
    [[ -n "${WARNINGS_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [recent_changes] WARNING: $msg" >> "$WARNINGS_FILE"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [recent_changes] WARNING: $msg" >> "$COLLECTION_LOG"
}

log_msg "Starting recent file changes collection"

if [[ -z "${RAW_DIR:-}" ]]; then
    exit 1
fi

RECENT_DAYS_VALUE="${RECENT_DAYS:-2}"

if command -v find >/dev/null 2>&1; then
    find /etc -type f -mtime "-$RECENT_DAYS_VALUE" -printf "%TY-%Tm-%Td %TH:%TM:%TS %p\n" 2>/dev/null | sort -r > "$RAW_DIR/etc_recent_changes.txt" \
        || warn_msg "Failed to collect recent changes from /etc"

    find /var/log -type f -mtime "-$RECENT_DAYS_VALUE" -printf "%TY-%Tm-%Td %TH:%TM:%TS %p\n" 2>/dev/null | sort -r > "$RAW_DIR/varlog_recent_changes.txt" \
        || warn_msg "Failed to collect recent changes from /var/log"
else
    echo "find command not available" > "$RAW_DIR/etc_recent_changes.txt"
    echo "find command not available" > "$RAW_DIR/varlog_recent_changes.txt"
    warn_msg "find command not available"
fi

log_msg "Completed recent file changes collection"
exit 0
