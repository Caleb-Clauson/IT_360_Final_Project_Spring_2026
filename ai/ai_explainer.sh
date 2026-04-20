#!/usr/bin/env bash

set -u

# Make sure required environment variables/paths exist
if [[ -z "${RAW_DIR:-}" || -z "${REPORT_DIR:-}" ]]; then
    echo "ERROR: RAW_DIR or REPORT_DIR not set." >&2
    exit 1
fi

if [[ -z "${AI_API_KEY:-}" ]]; then
    echo "ERROR: AI_API_KEY not set. Please configure .env file." >&2
    exit 1
fi

AI_MODEL="${AI_MODEL:-}"

OUTPUT_FILE="$REPORT_DIR/ai_summary.txt"

{
    echo "Generating AI-style summary..."
    echo
    echo "========================================"
    echo "ForensiCollect Analysis Summary"
    echo "========================================"
    echo
} > "$OUTPUT_FILE"

escape_json() {
    local text="$1"
    text="${text//\\/\\\\}"
    text="${text//\"/\\\"}"
    text="${text//$'\n'/\\n}"
    text="${text//$'\r'/}"
    echo "$text"
}

call_api() {
    local prompt="$1"
    local response

    response=$(curl -s -X POST "http://sushi.it.ilstu.edu:8080/" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AI_API_KEY" \
        -d "{
            \"model\": \"$AI_MODEL\",
            \"messages\": [{
                \"role\": \"user\",
                \"content\": \"$prompt\"
            }]
        }")

    echo "$response" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4
}

# Host info
if [[ -f "$RAW_DIR/hostname.txt" ]]; then
    echo "Host: $(head -n 1 "$RAW_DIR/hostname.txt")" >> "$OUTPUT_FILE"
fi

if [[ -f "$RAW_DIR/os-release.txt" ]]; then
    OS=$(grep PRETTY_NAME "$RAW_DIR/os-release.txt" | cut -d= -f2- | tr -d '"')
    echo "Operating System: $OS" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# Authentication
echo "---- Authentication Activity ----" >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/auth.log.txt" ]]; then
    FAILED=$(grep -i "failed" "$RAW_DIR/auth.log.txt" | wc -l)
    echo "Failed login attempts detected: $FAILED" >> "$OUTPUT_FILE"

    if (( FAILED > 5 )); then
        echo "Suspicious activity detected: high number of failed logins." >> "$OUTPUT_FILE"

        auth_sample=$(head -n 20 "$RAW_DIR/auth.log.txt")
        auth_sample=$(escape_json "$auth_sample")
        ai_analysis=$(call_api "Analyze these authentication log entries for suspicious patterns. Be concise:\n\n$auth_sample")

        if [[ -n "$ai_analysis" ]]; then
            echo "AI Analysis: $ai_analysis" >> "$OUTPUT_FILE"
        fi
    fi
elif [[ -f "$RAW_DIR/secure.log.txt" ]]; then
    FAILED=$(grep -i "failed" "$RAW_DIR/secure.log.txt" | wc -l)
    echo "Failed login attempts detected: $FAILED" >> "$OUTPUT_FILE"
else
    echo "No authentication log data available." >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# Network
echo "---- Network Activity ----" >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/listening_ports.txt" ]]; then
    PORT_COUNT=$(grep -E "LISTEN|tcp|udp" "$RAW_DIR/listening_ports.txt" | wc -l)
    echo "Listening ports detected: $PORT_COUNT" >> "$OUTPUT_FILE"
    echo >> "$OUTPUT_FILE"
    echo "Top listening ports:" >> "$OUTPUT_FILE"
    head -n 10 "$RAW_DIR/listening_ports.txt" >> "$OUTPUT_FILE"

    ports_sample=$(head -n 10 "$RAW_DIR/listening_ports.txt")
    ports_sample=$(escape_json "$ports_sample")
    port_analysis=$(call_api "Review these listening ports and flag any that seem unusual or suspicious:\n\n$ports_sample")

    if [[ -n "$port_analysis" ]]; then
        echo >> "$OUTPUT_FILE"
        echo "AI Security Assessment:" >> "$OUTPUT_FILE"
        echo "$port_analysis" >> "$OUTPUT_FILE"
    fi
else
    echo "No listening port data available." >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# Recent changes
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

# PROCESS SNAPSHOT
echo "---- Process Snapshot ----" >> "$OUTPUT_FILE"

# Show the top few lines of the collected process list
if [[ -f "$RAW_DIR/ps_aux.txt" ]]; then
    echo "Top running processes:" >> "$OUTPUT_FILE"
    head -n 10 "$RAW_DIR/ps_aux.txt" >> "$OUTPUT_FILE"

    # Use AI to identify suspicious processes
    if [[ -n "$AI_API_KEY" ]]; then
        process_sample=$(head -n 10 "$RAW_DIR/ps_aux.txt" | escape_json)
        process_analysis=$(call_api "Review these running processes and flag any that appear suspicious or unusual:\n\n$process_sample")

        if [[ -n "$process_analysis" ]]; then
            echo >> "$OUTPUT_FILE"
            echo "AI Process Analysis:" >> "$OUTPUT_FILE"
            echo "$process_analysis" >> "$OUTPUT_FILE"
        fi
    fi
fi

echo >> "$OUTPUT_FILE"
echo "Summary complete." >> "$OUTPUT_FILE"
