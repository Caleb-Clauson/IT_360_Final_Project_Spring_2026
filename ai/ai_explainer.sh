#!/usr/bin/env bash

set -u

OUTPUT_FILE="$REPORT_DIR/ai_summary.txt"

echo "Generating AI-style summary..." > "$OUTPUT_FILE"

echo "========================================" >> "$OUTPUT_FILE"
echo "ForensiCollect Analysis Summary" >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"
echo >> "$OUTPUT_FILE"

# Host Info
if [[ -f "$RAW_DIR/hostname.txt" ]]; then
    echo "Host: $(head -n 1 "$RAW_DIR/hostname.txt")" >> "$OUTPUT_FILE"
fi

if [[ -f "$RAW_DIR/os-release.txt" ]]; then
    OS=$(grep PRETTY_NAME "$RAW_DIR/os-release.txt" | cut -d= -f2- | tr -d '"')
    echo "Operating System: $OS" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# Failed login attempts
echo "---- Authentication Activity ----" >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/auth.log.txt" ]]; then
    FAILED=$(grep -i "failed" "$RAW_DIR/auth.log.txt" | wc -l)
    echo "Failed login attempts detected: $FAILED" >> "$OUTPUT_FILE"

    if (( FAILED > 5 )); then
        echo "⚠️ Suspicious activity: High number of failed logins." >> "$OUTPUT_FILE"
    fi
elif [[ -f "$RAW_DIR/secure.log.txt" ]]; then
    FAILED=$(grep -i "failed" "$RAW_DIR/secure.log.txt" | wc -l)
    echo "Failed login attempts detected: $FAILED" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# Listening ports
echo "---- Network Activity ----" >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/listening_ports.txt" ]]; then
    PORT_COUNT=$(grep -E "LISTEN|tcp" "$RAW_DIR/listening_ports.txt" | wc -l)
    echo "Listening ports detected: $PORT_COUNT" >> "$OUTPUT_FILE"

    echo "Top listening ports:" >> "$OUTPUT_FILE"
    head -n 10 "$RAW_DIR/listening_ports.txt" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# Recent file changes
echo "---- Recent System Changes ----" >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/etc_recent_changes.txt" ]]; then
    echo "Recent changes in /etc:" >> "$OUTPUT_FILE"
    head -n 5 "$RAW_DIR/etc_recent_changes.txt" >> "$OUTPUT_FILE"
fi

if [[ -f "$RAW_DIR/varlog_recent_changes.txt" ]]; then
    echo "Recent changes in /var/log:" >> "$OUTPUT_FILE"
    head -n 5 "$RAW_DIR/varlog_recent_changes.txt" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

echo "---- Process Snapshot ----" >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/ps_aux.txt" ]]; then
    echo "Top running processes:" >> "$OUTPUT_FILE"
    head -n 10 "$RAW_DIR/ps_aux.txt" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"
echo "Summary complete." >> "$OUTPUT_FILE"
