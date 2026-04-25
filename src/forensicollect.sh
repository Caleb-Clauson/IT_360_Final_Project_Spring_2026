#!/usr/bin/env bash

set -u

# ==============================
# CREDENTIALS LOADING
# ==============================

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
fi

export AI_API_KEY="${AI_API_KEY:-}"
export AI_MODEL="${AI_MODEL:-}"

# ==============================
# TOOL CONFIGURATION
# ==============================

TOOL_NAME="ForensiCollect"
VERSION="1.0.0"
RECENT_DAYS="${RECENT_DAYS:-2}"

MODULE_DIR="$SCRIPT_DIR/modules"
AI_SCRIPT="$SCRIPT_DIR/ai/ai_explainer.sh"
OUT_BASE="$SCRIPT_DIR/output"

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

# ==============================
# HELPER FUNCTIONS
# ==============================

ts() {
    date +"%Y-%m-%d %H:%M:%S"
}

log() {
    local msg="$1"
    echo "[$(ts)] $msg"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(ts)] $msg" >> "$COLLECTION_LOG"
}

warn() {
    local msg="$1"
    echo "[$(ts)] WARNING: $msg" >&2
    [[ -n "${WARNINGS_FILE:-}" ]] && echo "[$(ts)] WARNING: $msg" >> "$WARNINGS_FILE"
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(ts)] WARNING: $msg" >> "$COLLECTION_LOG"
}

die() {
    local msg="$1"
    echo "[$(ts)] ERROR: $msg" >&2
    [[ -n "${COLLECTION_LOG:-}" ]] && echo "[$(ts)] ERROR: $msg" >> "$COLLECTION_LOG"
    exit 1
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

# ==============================
# INITIALIZATION
# ==============================

init_case_dir() {
    mkdir -p "$OUT_BASE" || die "Could not create output directory"

    local stamp
    stamp="$(date +"%Y-%m-%d_%H%M%S")"

    CASE_DIR="$OUT_BASE/case_$stamp"
    RAW_DIR="$CASE_DIR/raw"
    REPORT_DIR="$CASE_DIR/report"

    mkdir -p "$RAW_DIR" "$REPORT_DIR" || die "Could not create case structure"

    COLLECTION_LOG="$CASE_DIR/collection_log.txt"
    WARNINGS_FILE="$CASE_DIR/warnings.txt"
    HASH_MANIFEST="$CASE_DIR/hash_manifest.txt"
    SUMMARY_FILE="$CASE_DIR/summary.txt"
    REPORT_JSON="$CASE_DIR/report.json"
    TIMELINE_CSV="$CASE_DIR/timeline.csv"

    touch "$COLLECTION_LOG" "$WARNINGS_FILE" "$HASH_MANIFEST" "$SUMMARY_FILE" "$REPORT_JSON" "$TIMELINE_CSV" \
        || die "Could not initialize output files"

    log "$TOOL_NAME v$VERSION started"
    log "Case directory: $CASE_DIR"
    log "Raw directory: $RAW_DIR"
    log "Report directory: $REPORT_DIR"
}

# ==============================
# ENVIRONMENT CHECKS
# ==============================

check_dependencies() {
    log "Checking dependencies..."

    local required=("bash" "date" "find" "sha256sum" "tar" "gzip")
    local optional=("ip" "ss" "netstat" "ps" "systemctl" "last" "who" "lsblk" "df" "top" "journalctl" "curl" "crontab" "lsmod" "dpkg" "env")

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
    available_kb=$(df "$OUT_BASE" 2>/dev/null | awk 'NR==2 {print $4}')

    if [[ -n "${available_kb:-}" ]]; then
        (( available_kb < 102400 )) && warn "Low disk space: less than 100 MB available"
    else
        warn "Could not determine available disk space"
    fi
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

    if [[ ! -f "$path" ]]; then
        warn "Missing module: $module"
        echo "\"$(ts)\",\"module_missing\",\"$module\"" >> "$TIMELINE_CSV"
        return 1
    fi

    if [[ ! -x "$path" ]]; then
        warn "Not executable: $module"
        echo "\"$(ts)\",\"module_not_executable\",\"$module\"" >> "$TIMELINE_CSV"
        return 1
    fi

    log "Running module: $module"
    echo "\"$(ts)\",\"module_start\",\"$module\"" >> "$TIMELINE_CSV"

    if RAW_DIR="$RAW_DIR" REPORT_DIR="$REPORT_DIR" \
       WARNINGS_FILE="$WARNINGS_FILE" COLLECTION_LOG="$COLLECTION_LOG" \
       RECENT_DAYS="$RECENT_DAYS" "$path" >> "$COLLECTION_LOG" 2>&1
    then
        log "Completed module: $module"
        echo "\"$(ts)\",\"module_complete\",\"$module\"" >> "$TIMELINE_CSV"
    else
        warn "Module failed: $module"
        echo "\"$(ts)\",\"module_failed\",\"$module\"" >> "$TIMELINE_CSV"
        return 1
    fi
}

# ==============================
# EXTENDED ARTIFACT COLLECTION
# ==============================

collect_extended_artifacts() {
    log "Collecting extended forensic artifacts..."
    echo "\"$(ts)\",\"extended_collection_start\",\"extended artifacts\"" >> "$TIMELINE_CSV"

    # Sudo / privilege escalation activity
    if [[ -f /var/log/auth.log ]]; then
        grep -i "sudo" /var/log/auth.log > "$RAW_DIR/sudo_activity.txt" 2>/dev/null || true
    elif [[ -f /var/log/secure ]]; then
        grep -i "sudo" /var/log/secure > "$RAW_DIR/sudo_activity.txt" 2>/dev/null || true
    else
        echo "No auth.log or secure log found" > "$RAW_DIR/sudo_activity.txt"
    fi

    # User accounts and privileged users
    if [[ -f /etc/passwd ]]; then
        cat /etc/passwd > "$RAW_DIR/passwd_full.txt" 2>/dev/null || true
        awk -F: '($3 == 0 || $3 >= 1000) {print}' /etc/passwd > "$RAW_DIR/important_users.txt" 2>/dev/null || true
        awk -F: '($3 == 0) {print}' /etc/passwd > "$RAW_DIR/uid0_users.txt" 2>/dev/null || true
    else
        echo "No /etc/passwd found" > "$RAW_DIR/passwd_full.txt"
    fi

    # Cron jobs / persistence checks
    crontab -l > "$RAW_DIR/user_cron.txt" 2>/dev/null || echo "No user crontab or permission denied" > "$RAW_DIR/user_cron.txt"

    if [[ -f /etc/crontab ]]; then
        cat /etc/crontab > "$RAW_DIR/system_cron.txt" 2>/dev/null || true
    else
        echo "No /etc/crontab found" > "$RAW_DIR/system_cron.txt"
    fi

    ls -la /etc/cron.* > "$RAW_DIR/cron_dirs.txt" 2>/dev/null || echo "Could not list /etc/cron.*" > "$RAW_DIR/cron_dirs.txt"

    # Active network connections
    if command -v ss >/dev/null 2>&1; then
        ss -antp > "$RAW_DIR/active_connections.txt" 2>/dev/null || true
    elif command -v netstat >/dev/null 2>&1; then
        netstat -antp > "$RAW_DIR/active_connections.txt" 2>/dev/null || true
    else
        echo "Neither ss nor netstat available" > "$RAW_DIR/active_connections.txt"
    fi

    # Loaded kernel modules
    if command -v lsmod >/dev/null 2>&1; then
        lsmod > "$RAW_DIR/kernel_modules.txt" 2>/dev/null || true
    else
        echo "lsmod not available" > "$RAW_DIR/kernel_modules.txt"
    fi

    # Broader recent file changes
    find /home /tmp /var/www -type f -mtime -1 2>/dev/null > "$RAW_DIR/recent_user_files.txt" || true

    # Bash history
    if [[ -f "$HOME/.bash_history" ]]; then
        cat "$HOME/.bash_history" > "$RAW_DIR/bash_history.txt" 2>/dev/null || true
    else
        echo "No bash history found for current user" > "$RAW_DIR/bash_history.txt"
    fi

    # Environment variables
    env > "$RAW_DIR/environment.txt" 2>/dev/null || true

    # Installed packages
    if command -v dpkg >/dev/null 2>&1; then
        dpkg -l > "$RAW_DIR/installed_packages.txt" 2>/dev/null || true
    else
        echo "dpkg not available" > "$RAW_DIR/installed_packages.txt"
    fi

    log "Extended forensic artifact collection complete"
    echo "\"$(ts)\",\"extended_collection_complete\",\"extended artifacts\"" >> "$TIMELINE_CSV"
}

# ==============================
# AI ANALYSIS
# ==============================

run_ai_explainer() {
    if [[ ! -f "$AI_SCRIPT" ]]; then
        warn "AI script missing"
        echo "\"$(ts)\",\"ai_missing\",\"ai_explainer.sh\"" >> "$TIMELINE_CSV"
        return 1
    fi

    if [[ ! -x "$AI_SCRIPT" ]]; then
        warn "AI script not executable"
        echo "\"$(ts)\",\"ai_not_executable\",\"ai_explainer.sh\"" >> "$TIMELINE_CSV"
        return 1
    fi

    log "Running AI analysis..."
    echo "\"$(ts)\",\"ai_start\",\"ai_explainer.sh\"" >> "$TIMELINE_CSV"

    if RAW_DIR="$RAW_DIR" REPORT_DIR="$REPORT_DIR" \
       WARNINGS_FILE="$WARNINGS_FILE" COLLECTION_LOG="$COLLECTION_LOG" \
       AI_API_KEY="${AI_API_KEY:-}" AI_MODEL="${AI_MODEL:-}" \
       "$AI_SCRIPT" >> "$COLLECTION_LOG" 2>&1
    then
        log "AI analysis completed"
        echo "\"$(ts)\",\"ai_complete\",\"ai_explainer.sh\"" >> "$TIMELINE_CSV"
    else
        warn "AI analysis failed"
        echo "\"$(ts)\",\"ai_failed\",\"ai_explainer.sh\"" >> "$TIMELINE_CSV"
        return 1
    fi
}

# ==============================
# OUTPUT GENERATION
# ==============================

write_summary() {
    log "Writing summary..."

    local warnings
    warnings=$(wc -l < "$WARNINGS_FILE" 2>/dev/null || echo "0")

    local ai_file=""
    if [[ -f "$REPORT_DIR/ai_summary.txt" ]]; then
        ai_file="$REPORT_DIR/ai_summary.txt"
    elif [[ -f "$REPORT_DIR/ai_summary.json" ]]; then
        ai_file="$REPORT_DIR/ai_summary.json"
    fi

    {
        echo "$TOOL_NAME Summary"
        echo "==========================="
        echo "Version: $VERSION"
        echo "Case: $CASE_DIR"
        echo "Collection Time: $(ts)"
        echo "Warnings: $warnings"
        echo

        echo "Artifacts:"
        echo "- raw/ contains collected system evidence"
        echo "- report/ contains AI and analysis outputs"
        echo "- collection_log.txt contains the audit trail"
        echo "- hash_manifest.txt contains SHA-256 hashes"
        echo "- timeline.csv contains collection timeline events"
        echo

        echo "Core Modules:"
        echo "- system_info.sh"
        echo "- user_activity.sh"
        echo "- process_service.sh"
        echo "- network.sh"
        echo "- recent_changes.sh"
        echo

        echo "Extended Artifacts Added:"
        echo "- sudo_activity.txt"
        echo "- passwd_full.txt"
        echo "- important_users.txt"
        echo "- uid0_users.txt"
        echo "- user_cron.txt"
        echo "- system_cron.txt"
        echo "- cron_dirs.txt"
        echo "- active_connections.txt"
        echo "- kernel_modules.txt"
        echo "- recent_user_files.txt"
        echo "- bash_history.txt"
        echo "- environment.txt"
        echo "- installed_packages.txt"
        echo

        echo "AI Summary:"
        if [[ -n "$ai_file" ]]; then
            echo "Generated: $(basename "$ai_file")"
            echo
            echo "AI Summary Preview:"
            echo "-------------------"
            head -n 25 "$ai_file"
        else
            echo "Not generated"
        fi
        echo

        echo "Warnings:"
        if [[ -s "$WARNINGS_FILE" ]]; then
            cat "$WARNINGS_FILE"
        else
            echo "None"
        fi
    } > "$SUMMARY_FILE"
}

write_report_json() {
    log "Writing JSON report..."

    local ai_generated="false"
    [[ -f "$REPORT_DIR/ai_summary.txt" || -f "$REPORT_DIR/ai_summary.json" ]] && ai_generated="true"

    cat > "$REPORT_JSON" <<EOF
{
  "tool": "$TOOL_NAME",
  "version": "$VERSION",
  "case": "$(basename "$CASE_DIR")",
  "time": "$(ts)",
  "extended_artifacts": true,
  "ai_summary_generated": $ai_generated
}
EOF
}

# ==============================
# HASHING
# ==============================

generate_hash_manifest() {
    log "Hashing files..."

    (
        cd "$CASE_DIR" || return 1
        find . -type f ! -name "hash_manifest.txt" -print0 | sort -z | xargs -0 sha256sum > "$HASH_MANIFEST"
    ) || warn "Hash manifest generation failed"
}

# ==============================
# PACKAGING
# ==============================

package_case() {
    log "Creating archive..."

    local name
    name=$(basename "$CASE_DIR")

    ARCHIVE_FILE="$OUT_BASE/$name.tar.gz"

    (
        cd "$OUT_BASE" || return 1
        tar -czf "$name.tar.gz" "$name"
    ) || warn "Archive creation failed"

    sha256sum "$ARCHIVE_FILE" > "$ARCHIVE_FILE.sha256" 2>/dev/null || warn "Archive hash generation failed"
}

# ==============================
# MAIN FUNCTION
# ==============================

main() {
    init_case_dir
    check_dependencies
    check_disk_space
    init_timeline

    run_module "system_info.sh"
    run_module "user_activity.sh"
    run_module "process_service.sh"
    run_module "network.sh"
    run_module "recent_changes.sh"

    collect_extended_artifacts

    run_ai_explainer

    write_summary
    write_report_json
    generate_hash_manifest
    package_case

    echo "\"$(ts)\",\"complete\",\"collection finished\"" >> "$TIMELINE_CSV"

    log "Collection complete"
    log "Output stored at: $CASE_DIR"
}

main "$@"
