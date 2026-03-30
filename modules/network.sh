#!/usr/bin/env bash

# Exit if undefined variables are used
set -u

# ==============================
# HELPER FUNCTIONS
# ==============================

# Log normal activity for this module
log_msg() {
    local msg="$1"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [network] $msg" >> "$COLLECTION_LOG"
}

# Log warnings for this module
warn_msg() {
    local msg="$1"
    [[ -n "${WARNINGS_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [network] WARNING: $msg" >> "$WARNINGS_FILE"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [network] WARNING: $msg" >> "$COLLECTION_LOG"
}

log_msg "Starting network collection"

# Make sure RAW_DIR was provided by the main script
if [[ -z "${RAW_DIR:-}" ]]; then
    exit 1
fi

# ==============================
# INTERFACES AND ROUTES
# ==============================

# Collect IP interface information and routing table
if command -v ip >/dev/null 2>&1; then
    ip a > "$RAW_DIR/ip_addr.txt" 2>/dev/null || warn_msg "Failed to run ip a"
    ip r > "$RAW_DIR/ip_route.txt" 2>/dev/null || warn_msg "Failed to run ip r"
else
    echo "ip command not available" > "$RAW_DIR/ip_addr.txt"
    echo "ip command not available" > "$RAW_DIR/ip_route.txt"
    warn_msg "ip command not available"
fi

# ==============================
# LISTENING PORTS
# ==============================

# Prefer ss because it is standard on modern Linux systems
if command -v ss >/dev/null 2>&1; then
    ss -tulpen > "$RAW_DIR/listening_ports.txt" 2>/dev/null \
        || ss -tulpn > "$RAW_DIR/listening_ports.txt" 2>/dev/null \
        || warn_msg "Failed to run ss"

# Fallback to netstat if ss is unavailable
elif command -v netstat >/dev/null 2>&1; then
    netstat -plant > "$RAW_DIR/listening_ports.txt" 2>/dev/null \
        || warn_msg "Failed to run netstat -plant"

# Record absence of both tools
else
    echo "Neither ss nor netstat is available" > "$RAW_DIR/listening_ports.txt"
    warn_msg "No supported listening-port command available"
fi

# ==============================
# ARP / NEIGHBOR TABLE
# ==============================

# Prefer arp if available
if command -v arp >/dev/null 2>&1; then
    arp -a > "$RAW_DIR/arp.txt" 2>/dev/null || warn_msg "Failed to run arp -a"

# Fallback to ip neigh
elif command -v ip >/dev/null 2>&1; then
    ip neigh > "$RAW_DIR/arp.txt" 2>/dev/null || warn_msg "Failed to run ip neigh"

# Record if neither works
else
    echo "No ARP/neigh command available" > "$RAW_DIR/arp.txt"
    warn_msg "arp and ip neigh unavailable"
fi

log_msg "Completed network collection"
exit 0
