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

OUTPUT_FILE="$REPORT_DIR/ai_summary.json"
DEBUG_FILE="$REPORT_DIR/ai_debug.json"

: > "$OUTPUT_FILE"
: > "$DEBUG_FILE"

{
    echo "{"
    echo "  \"tool\": \"ForensiCollect\","
    echo "  \"analysis_type\": \"AI Summary\","
    echo "  \"sections\": {"
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
    local cleaned_response

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

    # Extract content and remove escaped newlines
    cleaned_response=$(echo "$response" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4 | sed 's/\\n/ /g')
    echo "$cleaned_response"
}

# HOST INFO
{
    echo "    \"host_info\": {"
} >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/hostname.txt" ]]; then
    hostname=$(head -n 1 "$RAW_DIR/hostname.txt")
    echo "      \"hostname\": \"$hostname\"," >> "$OUTPUT_FILE"
fi

if [[ -f "$RAW_DIR/os-release.txt" ]]; then
    os_info=$(grep PRETTY_NAME "$RAW_DIR/os-release.txt" | cut -d= -f2- | tr -d '"')
    echo "      \"os\": \"$os_info\"" >> "$OUTPUT_FILE"
fi

{
    echo "    },"
} >> "$OUTPUT_FILE"

# AUTHENTICATION ACTIVITY
{
    echo "    \"authentication_activity\": {"
} >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/auth.log.txt" ]]; then
    FAILED=$(grep -i "failed" "$RAW_DIR/auth.log.txt" | wc -l)
    
    {
        echo "      \"failed_login_attempts\": $FAILED,"
    } >> "$OUTPUT_FILE"

    auth_sample=$(head -n 20 "$RAW_DIR/auth.log.txt")
    auth_analysis=$(call_api "Analyze these Linux authentication log entries for suspicious activity. Be concise and practical: $auth_sample" || true)
    
    {
        echo "      \"ai_analysis\": \"$auth_analysis\""
        echo "    },"
    } >> "$OUTPUT_FILE"
else
    {
        echo "      \"status\": \"No authentication log data available\""
        echo "    },"
    } >> "$OUTPUT_FILE"
fi

# NETWORK ACTIVITY
{
    echo "    \"network_activity\": {"
} >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/listening_ports.txt" ]]; then
    PORT_COUNT=$(grep -E "LISTEN|tcp|udp" "$RAW_DIR/listening_ports.txt" | wc -l)
    
    {
        echo "      \"listening_ports_detected\": $PORT_COUNT,"
    } >> "$OUTPUT_FILE"

    ports_sample=$(head -n 10 "$RAW_DIR/listening_ports.txt")
    port_analysis=$(call_api "Review these Linux listening ports. Flag anything unusual or suspicious, especially ports like 4444. Be concise: $ports_sample" || true)

    {
        echo "      \"ai_security_assessment\": \"$port_analysis\""
        echo "    },"
    } >> "$OUTPUT_FILE"
else
    {
        echo "      \"status\": \"No listening port data available\""
        echo "    },"
    } >> "$OUTPUT_FILE"
fi

# RECENT SYSTEM CHANGES
{
    echo "    \"recent_system_changes\": {"
} >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/etc_recent_changes.txt" ]]; then
    etc_changes=$(head -n 5 "$RAW_DIR/etc_recent_changes.txt" | tr '\n' ' ')
    echo "      \"etc_changes\": \"$etc_changes\"," >> "$OUTPUT_FILE"
fi

if [[ -f "$RAW_DIR/varlog_recent_changes.txt" ]]; then
    varlog_changes=$(head -n 5 "$RAW_DIR/varlog_recent_changes.txt" | tr '\n' ' ')
    echo "      \"varlog_changes\": \"$varlog_changes\"" >> "$OUTPUT_FILE"
fi

{
    echo "    },"
} >> "$OUTPUT_FILE"

# PROCESS SNAPSHOT
{
    echo "    \"process_snapshot\": {"
} >> "$OUTPUT_FILE"

if [[ -f "$RAW_DIR/ps_aux.txt" ]]; then
    process_sample=$(head -n 10 "$RAW_DIR/ps_aux.txt")
    process_analysis=$(call_api "Review these Linux running processes. Flag anything suspicious or unusual. Be concise: $process_sample" || true)

    {
        echo "      \"ai_process_analysis\": \"$process_analysis\""
        echo "    }"
    } >> "$OUTPUT_FILE"
else
    {
        echo "      \"status\": \"No process snapshot data available\""
        echo "    }"
    } >> "$OUTPUT_FILE"
fi

{
    echo "  }"
    echo "}"
} >> "$OUTPUT_FILE"
