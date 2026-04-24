#!/usr/bin/env bash

set -u

# VALIDATION
# Ensure required directories were passed from the main script
if [[ -z "${RAW_DIR:-}" || -z "${REPORT_DIR:-}" ]]; then
    echo "ERROR: RAW_DIR or REPORT_DIR not set." >&2
    exit 1
fi

# Ensure API credentials are available
if [[ -z "${AI_API_KEY:-}" ]]; then
    echo "ERROR: AI_API_KEY not set." >&2
    exit 1
fi

if [[ -z "${AI_MODEL:-}" ]]; then
    echo "ERROR: AI_MODEL not set." >&2
    exit 1
fi

if [[ -z "${prompt:-}" ]]; then
    echo "ERROR: prompt not set. Please set the 'prompt' variable in your .env file or environment." >&2
    exit 1
fi

OUTPUT_FILE="$REPORT_DIR/ai_summary.txt"
DEBUG_FILE="$REPORT_DIR/ai_debug.txt"

# REPORT SETUP
# Start fresh output files each run
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

# HELPER FUNCTIONS
# Escape special characters for safe JSON embedding
escape_json() {
    local text="$1"
    text="${text//\\/\\\\}"
    text="${text//\"/\\\"}"
    text="${text//$'\n'/\\n}"
    text="${text//$'\r'/}"
    echo "$text"
}

# Send a prompt to the AI API and return extracted content
call_api() {
    local prompt="$1"
    local response
    local escaped_prompt
    local http_code

    # Properly escape the prompt for JSON
    escaped_prompt=$(escape_json "$prompt")

    # Make API call and capture HTTP status code
    response=$(curl -s -w "\n%{http_code}" -X POST "http://sushi.it.ilstu.edu:8080/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AI_API_KEY" \
        -d "{
            \"model\": \"$AI_MODEL\",
            \"messages\": [{
                \"role\": \"user\",
                \"content\": \"$escaped_prompt\"
            }]
        }")

    # Extract HTTP status code (last line)
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | head -n-1)

    # Save raw response for debugging
    {
        echo "================ API REQUEST ================"
        echo "Endpoint: http://sushi.it.ilstu.edu:8080/v1/chat/completions"
        echo "Method: POST"
        echo "Model: $AI_MODEL"
        echo "Prompt length: ${#prompt}"
        echo "HTTP Status: $http_code"
        echo "================ API RESPONSE ================"
        echo "$response"
        echo
    } >> "$DEBUG_FILE"

    # If response is empty, return error
    if [[ -z "$response" ]]; then
        echo "ERROR: Empty response from API (HTTP $http_code)" >> "$DEBUG_FILE"
        return 1
    fi

    # Check for HTTP errors
    if [[ "$http_code" != "200" ]]; then
        echo "HTTP Error: $http_code" >> "$DEBUG_FILE"
        return 1
    fi

    # Check for API errors in response
    if echo "$response" | grep -q "error"; then
        echo "API Error detected:" >> "$DEBUG_FILE"
        echo "$response" >> "$DEBUG_FILE"
        return 1
    fi

    # Extract first content field
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
    auth_sample=$(escape_json "$auth_sample")
    auth_analysis=$(call_api "Analyze these authentication log entries for suspicious patterns. Be concise and practical:\n\n$auth_sample" || true)

    if [[ -n "$auth_analysis" ]]; then
        echo "AI Authentication Analysis:" >> "$OUTPUT_FILE"
        echo "$auth_analysis" >> "$OUTPUT_FILE"
    else
        echo "AI Authentication Analysis: No AI response returned." >> "$OUTPUT_FILE"
    fi

elif [[ -f "$RAW_DIR/secure.log.txt" ]]; then
    FAILED=$(grep -i "failed" "$RAW_DIR/secure.log.txt" | wc -l)
    echo "Failed login attempts detected: $FAILED" >> "$OUTPUT_FILE"

    auth_sample=$(head -n 20 "$RAW_DIR/secure.log.txt")
    auth_sample=$(escape_json "$auth_sample")
    auth_analysis=$(call_api "Analyze these authentication log entries for suspicious patterns. Be concise and practical:\n\n$auth_sample" || true)

    if [[ -n "$auth_analysis" ]]; then
        echo "AI Authentication Analysis:" >> "$OUTPUT_FILE"
        echo "$auth_analysis" >> "$OUTPUT_FILE"
    else
        echo "AI Authentication Analysis: No AI response returned." >> "$OUTPUT_FILE"
    fi
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
    ports_sample=$(escape_json "$ports_sample")
    port_analysis=$(call_api "Review these listening ports and flag any that seem unusual or suspicious. Be concise:\n\n$ports_sample" || true)

    if [[ -n "$port_analysis" ]]; then
        echo >> "$OUTPUT_FILE"
        echo "AI Security Assessment:" >> "$OUTPUT_FILE"
        echo "$port_analysis" >> "$OUTPUT_FILE"
    else
        echo >> "$OUTPUT_FILE"
        echo "AI Security Assessment: No AI response returned." >> "$OUTPUT_FILE"
    fi
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
    process_sample=$(escape_json "$process_sample")
    process_analysis=$(call_api "Review these running processes and flag any that appear suspicious or unusual. Be concise:\n\n$process_sample" || true)

    if [[ -n "$process_analysis" ]]; then
        echo >> "$OUTPUT_FILE"
        echo "AI Process Analysis:" >> "$OUTPUT_FILE"
        echo "$process_analysis" >> "$OUTPUT_FILE"
    else
        echo >> "$OUTPUT_FILE"
        echo "AI Process Analysis: No AI response returned." >> "$OUTPUT_FILE"
    fi
else
    echo "No process snapshot data available." >> "$OUTPUT_FILE"
fi

echo >> "$OUTPUT_FILE"
echo "Summary complete." >> "$OUTPUT_FILE"
