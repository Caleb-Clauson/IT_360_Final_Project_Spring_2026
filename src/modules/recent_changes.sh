#!/usr/bin/env bash

# Exit if undefined variables are used
set -u

# ==============================
# HELPER FUNCTIONS
# ==============================

# Log normal activity for this module
log_msg() {
    local msg="$1"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [recent_changes] $msg" >> "$COLLECTION_LOG"
}

# Log warnings for this module
warn_msg() {
    local msg="$1"
    [[ -n "${WARNINGS_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [recent_changes] WARNING: $msg" >> "$WARNINGS_FILE"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [recent_changes] WARNING: $msg" >> "$COLLECTION_LOG"
}

log_msg "Starting recent file changes collection"

# Make sure RAW_DIR was provided by the main script
if [[ -z "${RAW_DIR:-}" ]]; then
    exit 1
fi

# Use RECENT_DAYS from the main script, defaulting to 2 if missing
RECENT_DAYS_VALUE="${RECENT_DAYS:-2}"

# ==============================
# RECENT CHANGES IN /etc
# ==============================

# Find files modified within the chosen time window and sort newest first
if command -v find >/dev/null 2>&1; then
    find /etc -type f -mtime "-$RECENT_DAYS_VALUE" -printf "%TY-%Tm-%Td %TH:%TM:%TS %p\n" 2>/dev/null \
        | sort -r > "$RAW_DIR/etc_recent_changes.txt" \
        || warn_msg "Failed to collect recent changes from /etc"

    # ==============================
    # RECENT CHANGES IN /var/log
    # ==============================

    find /var/log -type f -mtime "-$RECENT_DAYS_VALUE" -printf "%TY-%Tm-%Td %TH:%TM:%TS %p\n" 2>/dev/null \
        | sort -r > "$RAW_DIR/varlog_recent_changes.txt" \
        || warn_msg "Failed to collect recent changes from /var/log"
else
    echo "find command not available" > "$RAW_DIR/etc_recent_changes.txt"
    echo "find command not available" > "$RAW_DIR/varlog_recent_changes.txt"
    warn_msg "find command not available"
fi

log_msg "Completed recent file changes collection"
exit 0
