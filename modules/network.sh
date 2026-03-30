#!/usr/bin/env bash

set -u

log_msg() {
    local msg="$1"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [network] $msg" >> "$COLLECTION_LOG"
}

warn_msg() {
    local msg="$1"
    [[ -n "${WARNINGS_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [network] WARNING: $msg" >> "$WARNINGS_FILE"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [network] WARNING: $msg" >> "$COLLECTION_LOG"
}

log_msg "Starting network collection"

if [[ -z "${RAW_DIR:-}" ]]; then
    exit 1
fi

if command -v ip >/dev/null 2>&1; then
    ip a > "$RAW_DIR/ip_addr.txt" 2>/dev/null || warn_msg "Failed to run ip a"
    ip r > "$RAW_DIR/ip_route.txt" 2>/dev/null || warn_msg "Failed to run ip r"
else
    echo "ip command not available" > "$RAW_DIR/ip_addr.txt"
    echo "ip command not available" > "$RAW_DIR/ip_route.txt"
    warn_msg "ip command not available"
fi

if command -v ss >/dev/null 2>&1; then
    ss -tulpen > "$RAW_DIR/listening_ports.txt" 2>/dev/null || ss -tulpn > "$RAW_DIR/listening_ports.txt" 2>/dev/null || warn_msg "Failed to run ss"
elif command -v netstat >/dev/null 2>&1; then
    netstat -plant > "$RAW_DIR/listening_ports.txt" 2>/dev/null || warn_msg "Failed to run netstat -plant"
else
    echo "Neither ss nor netstat is available" > "$RAW_DIR/listening_ports.txt"
    warn_msg "No supported listening-port command available"
fi

if command -v arp >/dev/null 2>&1; then
    arp -a > "$RAW_DIR/arp.txt" 2>/dev/null || warn_msg "Failed to run arp -a"
elif command -v ip >/dev/null 2>&1; then
    ip neigh > "$RAW_DIR/arp.txt" 2>/dev/null || warn_msg "Failed to run ip neigh"
else
    echo "No ARP/neigh command available" > "$RAW_DIR/arp.txt"
    warn_msg "arp and ip neigh unavailable"
fi

log_msg "Completed network collection"
exit 0
