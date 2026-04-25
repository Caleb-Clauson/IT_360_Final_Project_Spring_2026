#!/usr/bin/env bash

set -u

if [[ -z "${RAW_DIR:-}" || -z "${REPORT_DIR:-}" ]]; then
    echo "ERROR: RAW_DIR or REPORT_DIR not set." >&2
    exit 1
fi

if [[ -z "${AI_API_KEY:-}" ]]; then
    echo "ERROR: AI_API_KEY not set." >&2
    exit 1
fi

if [[ -z "${AI_MODEL:-}" ]]; then
    echo "ERROR: AI_MODEL not set." >&2
    exit 1
fi

OUTPUT_FILE="$REPORT_DIR/ai_summary.txt"
DEBUG_FILE="$REPORT_DIR/ai_debug.txt"

: > "$OUTPUT_FILE"
: > "$DEBUG_FILE"

{
    echo "Generating AI-style summary..."
    echo
    echo "========================================"
    echo "ForensiCollect Analysis Summary"
    echo "========================================"
    echo
} >> "$OUTPUT_FILE"

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
    local escaped_prompt
    local response

    escaped_prompt=$(escape_json "$prompt")

    response=$(curl -s -X POST "http://sushi.it.ilstu.edu:8080/api/chat/completions" \
        -H "Authorization: Bearer $AI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$AI_MODEL\",
            \"messages\": [
                {
                    \"role\": \"user\",
                    \"content\": \"$escaped_prompt\"
                }
            ]
        }")

    {
        echo "================ API RESPONSE ================"
        echo "$response"
        echo
    } >> "$DEBUG_FILE"

    echo "$response" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4
}

# HOST INFO
if [[ -f "$RAW_DIR/hostname.txt" ]]; then
    echo "Host: $(head -n 1 "$RAW_DIR/hostname.txt")" >> "$OUTPUT_FILE"
fi

if [[ -f "$RAW_DIR/os-release.txt" ]]; then
    echo "Operating System: $(grep PRETTY_NAME "$RAW_DIR/os-release.txt" | cut -d= -f2- | tr -d '"')" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# AUTHENTICATION ACTIVITY
echo "---- Authentication Activity ----" >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/auth.log.txt" ]]; then
    FAILED=$(grep -i "failed" "$RAW_DIR/auth.log.txt" | wc -l)
    echo "Failed login attempts detected: $FAILED" >> "$OUTPUT_FILE"

    auth_sample=$(head -n 20 "$RAW_DIR/auth.log.txt")
    auth_analysis=$(call_api "Analyze these Linux authentication log entries for suspicious activity. Be concise and practical: $auth_sample" || true)

    echo "AI Authentication Analysis:" >> "$OUTPUT_FILE"
    [[ -n "$auth_analysis" ]] && echo "$auth_analysis" >> "$OUTPUT_FILE" || echo "No AI response returned." >> "$OUTPUT_FILE"
else
    echo "No authentication log data available." >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# NETWORK ACTIVITY
echo "---- Network Activity ----" >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/listening_ports.txt" ]]; then
    PORT_COUNT=$(grep -E "LISTEN|tcp|udp" "$RAW_DIR/listening_ports.txt" | wc -l)
    echo "Listening ports detected: $PORT_COUNT" >> "$OUTPUT_FILE"
    echo >> "$OUTPUT_FILE"
    echo "Top listening ports:" >> "$OUTPUT_FILE"
    head -n 10 "$RAW_DIR/listening_ports.txt" >> "$OUTPUT_FILE"

    ports_sample=$(head -n 10 "$RAW_DIR/listening_ports.txt")
    port_analysis=$(call_api "Review these Linux listening ports. Flag anything unusual or suspicious, especially ports like 4444. Be concise: $ports_sample" || true)

    echo >> "$OUTPUT_FILE"
    echo "AI Security Assessment:" >> "$OUTPUT_FILE"
    [[ -n "$port_analysis" ]] && echo "$port_analysis" >> "$OUTPUT_FILE" || echo "No AI response returned." >> "$OUTPUT_FILE"
else
    echo "No listening port data available." >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# RECENT SYSTEM CHANGES
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

if [[ -f "$RAW_DIR/ps_aux.txt" ]]; then
    echo "Top running processes:" >> "$OUTPUT_FILE"
    head -n 10 "$RAW_DIR/ps_aux.txt" >> "$OUTPUT_FILE"

    process_sample=$(head -n 10 "$RAW_DIR/ps_aux.txt")
    process_analysis=$(call_api "Review these Linux running processes. Flag anything suspicious or unusual. Be concise: $process_sample" || true)

    echo >> "$OUTPUT_FILE"
    echo "AI Process Analysis:" >> "$OUTPUT_FILE"
    [[ -n "$process_analysis" ]] && echo "$process_analysis" >> "$OUTPUT_FILE" || echo "No AI response returned." >> "$OUTPUT_FILE"
else
    echo "No process snapshot data available." >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"
echo "Summary complete." >> "$OUTPUT_FILE"
