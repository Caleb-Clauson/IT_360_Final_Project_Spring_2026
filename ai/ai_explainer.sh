#!/usr/bin/env bash

set -u

# Validate inputs
if [[ -z "${RAW_DIR:-}" || -z "${REPORT_DIR:-}" ]]; then
    echo "ERROR: RAW_DIR or REPORT_DIR not set." >&2
    exit 1
fi

if [[ -z "${AI_API_KEY:-}" ]]; then
    echo "ERROR: AI_API_KEY not set." >&2
    exit 1
fi

AI_MODEL="${AI_MODEL:-test}"

OUTPUT_FILE="$REPORT_DIR/ai_summary.txt"

# Start report
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
[[ -f "$RAW_DIR/hostname.txt" ]] && echo "Host: $(head -n 1 "$RAW_DIR/hostname.txt")" >> "$OUTPUT_FILE"
[[ -f "$RAW_DIR/os-release.txt" ]] && echo "Operating System: $(grep PRETTY_NAME "$RAW_DIR/os-release.txt" | cut -d= -f2- | tr -d '"')" >> "$OUTPUT_FILE"

echo >> "$OUTPUT_FILE"

# Auth section
echo "---- Authentication Activity ----" >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/auth.log.txt" ]]; then
    FAILED=$(grep -i "failed" "$RAW_DIR/auth.log.txt" | wc -l)
    echo "Failed login attempts detected: $FAILED" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# Network
echo "---- Network Activity ----" >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/listening_ports.txt" ]]; then
    head -n 10 "$RAW_DIR/listening_ports.txt" >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"

# Process Snapshot
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
