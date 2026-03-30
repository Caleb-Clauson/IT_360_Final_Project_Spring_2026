#!/usr/bin/env bash

set -u

log_msg() {
    local msg="$1"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [process_service] $msg" >> "$COLLECTION_LOG"
}

warn_msg() {
    local msg="$1"
    [[ -n "${WARNINGS_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [process_service] WARNING: $msg" >> "$WARNINGS_FILE"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [process_service] WARNING: $msg" >> "$COLLECTION_LOG"
}

log_msg "Starting process and service collection"

if [[ -z "${RAW_DIR:-}" ]]; then
    exit 1
fi

if command -v ps >/dev/null 2>&1; then
    ps auxww > "$RAW_DIR/ps_aux.txt" 2>/dev/null || warn_msg "Failed to run ps auxww"
else
    echo "ps command not available" > "$RAW_DIR/ps_aux.txt"
    warn_msg "ps command not available"
fi

if command -v top >/dev/null 2>&1; then
    top -b -n 1 > "$RAW_DIR/top_snapshot.txt" 2>/dev/null || warn_msg "Failed to run top -b -n 1"
else
    echo "top command not available" > "$RAW_DIR/top_snapshot.txt"
    warn_msg "top command not available"
fi

if command -v systemctl >/dev/null 2>&1; then
    systemctl list-units --type=service --all > "$RAW_DIR/systemctl_services.txt" 2>/dev/null || warn_msg "Failed to run systemctl list-units"
elif command -v service >/dev/null 2>&1; then
    service --status-all > "$RAW_DIR/service_status_all.txt" 2>/dev/null || warn_msg "Failed to run service --status-all"
else
    echo "No supported service listing command found" > "$RAW_DIR/services_missing.txt"
    warn_msg "systemctl and service commands unavailable"
fi

log_msg "Completed process and service collection"
exit 0
