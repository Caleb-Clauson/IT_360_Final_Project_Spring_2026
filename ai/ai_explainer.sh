#!/usr/bin/env bash

# Exit if undefined variables are used
set -u

# ==============================
# OUTPUT FILE SETUP
# ==============================

# AI summary is written into the report/ folder created by the main script
OUTPUT_FILE="$REPORT_DIR/ai_summary.txt"

# Start a fresh output file each run
echo "Generating AI-style summary..." > "$OUTPUT_FILE"
echo >> "$OUTPUT_FILE"

echo "========================================" >> "$OUTPUT_FILE"
echo "ForensiCollect Analysis Summary" >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"
echo >> "$OUTPUT_FILE"

# ==============================
# HOST INFORMATION
# ==============================

# Pull hostname from collected evidence
if [[ -f "$RAW_DIR/hostname.txt" ]]; then
    echo "Host: $(head -n 1 "$RAW_DIR/hostname.txt")" >> "$OUTPUT_FILE"
fi

# Pull human-readable OS name from os-release file
if [[ -f "$RAW_DIR/os-release.txt" ]]; then
    OS=$(grep PRETTY_NAME "$RAW_DIR/os-release.txt" | cut -d= -f2- | tr -d '"')
    echo "Operating System: $OS" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# ==============================
# AUTHENTICATION ACTIVITY
# ==============================

echo "---- Authentication Activity ----" >> "$OUTPUT_FILE"

# Count failed login attempts if auth.log exists
if [[ -f "$RAW_DIR/auth.log.txt" ]]; then
    FAILED=$(grep -i "failed" "$RAW_DIR/auth.log.txt" | wc -l)
    echo "Failed login attempts detected: $FAILED" >> "$OUTPUT_FILE"

    # Flag suspicious failed logins if above threshold
    if (( FAILED > 5 )); then
        echo "Suspicious activity detected: high number of failed logins." >> "$OUTPUT_FILE"
    fi

# Same logic if secure.log exists instead
elif [[ -f "$RAW_DIR/secure.log.txt" ]]; then
    FAILED=$(grep -i "failed" "$RAW_DIR/secure.log.txt" | wc -l)
    echo "Failed login attempts detected: $FAILED" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# ==============================
# NETWORK ACTIVITY
# ==============================

echo "---- Network Activity ----" >> "$OUTPUT_FILE"

# Summarize listening ports
if [[ -f "$RAW_DIR/listening_ports.txt" ]]; then
    PORT_COUNT=$(grep -E "LISTEN|tcp|udp" "$RAW_DIR/listening_ports.txt" | wc -l)
    echo "Listening ports detected: $PORT_COUNT" >> "$OUTPUT_FILE"
    echo >> "$OUTPUT_FILE"
    echo "Top listening ports:" >> "$OUTPUT_FILE"
    head -n 10 "$RAW_DIR/listening_ports.txt" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# ==============================
# RECENT SYSTEM CHANGES
# ==============================

echo "---- Recent System Changes ----" >> "$OUTPUT_FILE"

# Show a few recent changes in /etc
if [[ -f "$RAW_DIR/etc_recent_changes.txt" ]]; then
    echo "Recent changes in /etc:" >> "$OUTPUT_FILE"
    head -n 5 "$RAW_DIR/etc_recent_changes.txt" >> "$OUTPUT_FILE"
fi

# Show a few recent changes in /var/log
if [[ -f "$RAW_DIR/varlog_recent_changes.txt" ]]; then
    echo "Recent changes in /var/log:" >> "$OUTPUT_FILE"
    head -n 5 "$RAW_DIR/varlog_recent_changes.txt" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# ==============================
# PROCESS SNAPSHOT
# ==============================

echo "---- Process Snapshot ----" >> "$OUTPUT_FILE"

# Show the top few lines of the collected process list
if [[ -f "$RAW_DIR/ps_aux.txt" ]]; then
    echo "Top running processes:" >> "$OUTPUT_FILE"
    head -n 10 "$RAW_DIR/ps_aux.txt" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"
echo "Summary complete." >> "$OUTPUT_FILE"
