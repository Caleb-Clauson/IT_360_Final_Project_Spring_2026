#!/usr/bin/env bash

# Exit if undefined variables are used
set -u

# ==============================
# CREDENTIALS VALIDATION
# ==============================

# Check if API key is set
if [[ -z "${AI_API_KEY:-}" ]]; then
    echo "ERROR: AI_API_KEY not set. Please configure .env file with your API key." >&2
    exit 1
fi

# Set defaults for optional variables
AI_MODEL="${AI_MODEL:-}"

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
# AI ANALYSIS FUNCTIONS
# ==============================

# Call AI API to analyze text
call_api() {
    local prompt="Analyze the following:"
    local response
    
    # Make API call
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
    
    # Extract the response text (safely handling JSON)
    echo "$response" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4
}

# Safely escape text for JSON
escape_json() {
    local text="$1"
    # Escape special JSON characters
    text="${text//\\/\\\\}"
    text="${text//\"/\\\"}"
    text="${text//$'\n'/\\n}"
    echo "$text"
}

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
            
            # Use AI to analyze auth logs
            if [[ -n "$AI_API_KEY" ]]; then
                auth_sample
                auth_sample=$(head -n 20 "$RAW_DIR/auth.log.txt" | escape_json)
                ai_analysis
                ai_analysis=$(call_api "Analyze these authentication log entries for suspicious patterns. Be concise:\n\n$auth_sample")
                
                if [[ -n "$ai_analysis" ]]; then
                    echo "AI Analysis: $ai_analysis" >> "$OUTPUT_FILE"
                fi
            fi
        fi# Same logic if secure.log exists instead
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
    
    # Use AI to identify suspicious ports
    if [[ -n "$AI_API_KEY" ]]; then
        ports_sample
        ports_sample=$(head -n 10 "$RAW_DIR/listening_ports.txt" | escape_json)
        port_analysis
        port_analysis=$(call_api "Review these listening ports and flag any that seem unusual or suspicious:\n\n$ports_sample")
        
        if [[ -n "$port_analysis" ]]; then
            echo >> "$OUTPUT_FILE"
            echo "AI Security Assessment:" >> "$OUTPUT_FILE"
            echo "$port_analysis" >> "$OUTPUT_FILE"
        fi
    fi
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
    
    # Use AI to identify suspicious processes
    if [[ -n "$AI_API_KEY" ]]; then
        process_sample
        process_sample=$(head -n 10 "$RAW_DIR/ps_aux.txt" | escape_json)
        process_analysis
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
