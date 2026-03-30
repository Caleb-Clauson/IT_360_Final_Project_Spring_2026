#!/usr/bin/env bash

# Exit on undefined variables
set -u

# ==============================
# TOOL CONFIGURATION
# ==============================

TOOL_NAME="ForensiCollect"
VERSION="1.0.0"

# Number of days to look back for "recent changes"
RECENT_DAYS="${RECENT_DAYS:-2}"

# ==============================
# PATH SETUP
# ==============================

# Get directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define important directories
MODULE_DIR="$SCRIPT_DIR/modules"     # Where modules live
AI_SCRIPT="$SCRIPT_DIR/ai/ai_explainer.sh"  # AI script
OUT_BASE="$SCRIPT_DIR/output"       # Output folder

# ==============================
# GLOBAL VARIABLES (initialized later)
# ==============================

CASE_DIR=""
RAW_DIR=""
REPORT_DIR=""
COLLECTION_LOG=""
WARNINGS_FILE=""
HASH_MANIFEST=""
SUMMARY_FILE=""
REPORT_JSON=""
TIMELINE_CSV=""
ARCHIVE_FILE=""
ARCHIVE_HASH_FILE=""

# ==============================
# HELPER FUNCTIONS
# ==============================

# Return current timestamp
ts() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Log standard messages (console + file)
log() {
    local msg="$1"
    echo "[$(ts)] $msg"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(ts)] $msg" >> "$COLLECTION_LOG"
}

# Log warnings (console + warnings file)
warn() {
    local msg="$1"
    echo "[$(ts)] WARNING: $msg" >&2
    [[ -n "${WARNINGS_FILE:-}" ]] && echo "[$(ts)] WARNING: $msg" >> "$WARNINGS_FILE"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(ts)] WARNING: $msg" >> "$COLLECTION_LOG"
}

# Fatal error → stop script
die() {
    local msg="$1"
    echo "[$(ts)] ERROR: $msg" >&2
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(ts)] ERROR: $msg" >> "$COLLECTION_LOG"
    exit 1
}

# Check if a command exists
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# ==============================
# INITIALIZATION
# ==============================

init_case_dir() {
    # Create base output folder
    mkdir -p "$OUT_BASE" || die "Could not create output directory"

    # Create unique timestamped case folder
    local stamp
    stamp="$(date +"%Y-%m-%d_%H%M%S")"

    CASE_DIR="$OUT_BASE/case_$stamp"
    RAW_DIR="$CASE_DIR/raw"
    REPORT_DIR="$CASE_DIR/report"

    # Create subdirectories
    mkdir -p "$RAW_DIR" "$REPORT_DIR" || die "Could not create case structure"

    # Define output files
    COLLECTION_LOG="$CASE_DIR/collection_log.txt"
    WARNINGS_FILE="$CASE_DIR/warnings.txt"
    HASH_MANIFEST="$CASE_DIR/hash_manifest.txt"
    SUMMARY_FILE="$CASE_DIR/summary.txt"
    REPORT_JSON="$CASE_DIR/report.json"
    TIMELINE_CSV="$CASE_DIR/timeline.csv"

    # Create empty files
    touch "$COLLECTION_LOG" "$WARNINGS_FILE" "$HASH_MANIFEST" "$SUMMARY_FILE" "$REPORT_JSON" "$TIMELINE_CSV"

    log "$TOOL_NAME v$VERSION started"
    log "Case directory: $CASE_DIR"
}

# ==============================
# ENVIRONMENT CHECKS
# ==============================

check_dependencies() {
    log "Checking dependencies..."

    # Required tools
    local required=("bash" "date" "find" "sha256sum" "tar" "gzip")

    # Optional tools (tool still works without them)
    local optional=("ip" "ss" "netstat" "ps" "systemctl" "last" "who" "lsblk" "df")

    for cmd in "${required[@]}"; do
        check_command "$cmd" || warn "Missing required command: $cmd"
    done

    for cmd in "${optional[@]}"; do
        check_command "$cmd" || warn "Optional command missing: $cmd"
    done
}

check_disk_space() {
    log "Checking disk space..."

    local available_kb
    available_kb=$(df "$OUT_BASE" | awk 'NR==2 {print $4}')

    # Warn if less than ~100MB free
    (( available_kb < 102400 )) && warn "Low disk space"
}

# ==============================
# TIMELINE
# ==============================

init_timeline() {
    echo "timestamp,event,details" > "$TIMELINE_CSV"
    echo "\"$(ts)\",\"start\",\"collection started\"" >> "$TIMELINE_CSV"
}

# ==============================
# MODULE EXECUTION
# ==============================

run_module() {
    local module="$1"
    local path="$MODULE_DIR/$module"

    # Check file exists
    [[ ! -f "$path" ]] && warn "Missing module: $module" && return

    # Check executable
    [[ ! -x "$path" ]] && warn "Not executable: $module" && return

    log "Running module: $module"

    # Run module with environment variables
    if RAW_DIR="$RAW_DIR" REPORT_DIR="$REPORT_DIR" \
       WARNINGS_FILE="$WARNINGS_FILE" COLLECTION_LOG="$COLLECTION_LOG" \
       RECENT_DAYS="$RECENT_DAYS" "$path" >> "$COLLECTION_LOG" 2>&1
    then
        log "Completed module: $module"
    else
        warn "Module failed: $module"
    fi
}

# ==============================
# AI ANALYSIS
# ==============================

run_ai_explainer() {
    # Check if AI script exists
    [[ ! -f "$AI_SCRIPT" ]] && warn "AI script missing" && return

    # Check executable
    [[ ! -x "$AI_SCRIPT" ]] && warn "AI script not executable" && return

    log "Running AI analysis..."

    RAW_DIR="$RAW_DIR" REPORT_DIR="$REPORT_DIR" \
    "$AI_SCRIPT" >> "$COLLECTION_LOG" 2>&1
}

# ==============================
# OUTPUT GENERATION
# ==============================

write_summary() {
    log "Writing summary..."

    local warnings
    warnings=$(wc -l < "$WARNINGS_FILE")

    {
        echo "$TOOL_NAME Summary"
        echo "==========================="
        echo "Version: $VERSION"
        echo "Case: $CASE_DIR"
        echo "Warnings: $warnings"
        echo

        echo "Artifacts:"
        echo "- raw/"
        echo "- report/"
        echo

        echo "AI Summary:"
        [[ -f "$REPORT_DIR/ai_summary.txt" ]] && echo "Generated" || echo "Not generated"
    } > "$SUMMARY_FILE"
}

write_report_json() {
    log "Writing JSON report..."

    cat > "$REPORT_JSON" <<EOF
{
  "tool": "$TOOL_NAME",
  "version": "$VERSION",
  "case": "$(basename "$CASE_DIR")",
  "time": "$(ts)"
}
EOF
}

# ==============================
# HASHING
# ==============================

generate_hash_manifest() {
    log "Hashing files..."

    cd "$CASE_DIR" || return
    find . -type f ! -name "hash_manifest.txt" | xargs sha256sum > "$HASH_MANIFEST"
}

# ==============================
# PACKAGING
# ==============================

package_case() {
    log "Creating archive..."

    local name
    name=$(basename "$CASE_DIR")

    ARCHIVE_FILE="$OUT_BASE/$name.tar.gz"

    cd "$OUT_BASE" || return
    tar -czf "$name.tar.gz" "$name"

    sha256sum "$ARCHIVE_FILE" > "$ARCHIVE_FILE.sha256"
}

# ==============================
# MAIN FUNCTION
# ==============================

main() {
    init_case_dir
    check_dependencies
    check_disk_space
    init_timeline

    # Run all modules
    run_module "system_info.sh"
    run_module "user_activity.sh"
    run_module "process_service.sh"
    run_module "network.sh"
    run_module "recent_changes.sh"

    # Run AI analysis
    run_ai_explainer

    # Generate outputs
    write_summary
    write_report_json
    generate_hash_manifest
    package_case

    log "Collection complete"
}

main "$@"
