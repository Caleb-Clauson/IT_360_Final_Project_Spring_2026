#!/usr/bin/env bash

# Exit if undefined variables are used
set -u

# ==============================
# HELPER FUNCTIONS
# ==============================

# Log normal activity for this module
log_msg() {
    local msg="$1"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [process_service] $msg" >> "$COLLECTION_LOG"
}

# Log warnings for this module
warn_msg() {
    local msg="$1"
    [[ -n "${WARNINGS_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [process_service] WARNING: $msg" >> "$WARNINGS_FILE"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [process_service] WARNING: $msg" >> "$COLLECTION_LOG"
}

log_msg "Starting process and service collection"

# Make sure RAW_DIR was provided by the main script
if [[ -z "${RAW_DIR:-}" ]]; then
    exit 1
fi

# ==============================
# PROCESS SNAPSHOT
# ==============================

# Capture a detailed process list
if command -v ps >/dev/null 2>&1; then
    ps auxww > "$RAW_DIR/ps_aux.txt" 2>/dev/null || warn_msg "Failed to run ps auxww"
else
    echo "ps command not available" > "$RAW_DIR/ps_aux.txt"
    warn_msg "ps command not available"
fi

# Capture a one-time top snapshot for CPU and memory usage
if command -v top >/dev/null 2>&1; then
    top -b -n 1 > "$RAW_DIR/top_snapshot.txt" 2>/dev/null || warn_msg "Failed to run top -b -n 1"
else
    echo "top command not available" > "$RAW_DIR/top_snapshot.txt"
    warn_msg "top command not available"
fi

# ==============================
# SERVICE SNAPSHOT
# ==============================

# Prefer systemctl for modern Linux systems
if command -v systemctl >/dev/null 2>&1; then
    systemctl list-units --type=service --all > "$RAW_DIR/systemctl_services.txt" 2>/dev/null \
        || warn_msg "Failed to run systemctl list-units"

# Fallback for older systems
elif command -v service >/dev/null 2>&1; then
    service --status-all > "$RAW_DIR/service_status_all.txt" 2>/dev/null \
        || warn_msg "Failed to run service --status-all"

# If neither exists, record it
else
    echo "No supported service listing command found" > "$RAW_DIR/services_missing.txt"
    warn_msg "systemctl and service commands unavailable"
fi

log_msg "Completed process and service collection"
exit 0
