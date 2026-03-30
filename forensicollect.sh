#!/usr/bin/env bash

set -u

TOOL_NAME="ForensiCollect"
VERSION="1.0.0"
RECENT_DAYS="${RECENT_DAYS:-2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
ARCHIVE_HASH_FILE=""

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

init_case_dir() {
    mkdir -p "$OUT_BASE" || die "Could not create output directory: $OUT_BASE"

    local stamp
    stamp="$(date +"%Y-%m-%d_%H%M%S")"

    CASE_DIR="$OUT_BASE/case_$stamp"
    RAW_DIR="$CASE_DIR/raw"
    REPORT_DIR="$CASE_DIR/report"

    mkdir -p "$RAW_DIR" "$REPORT_DIR" || die "Could not create case directory structure"

    COLLECTION_LOG="$CASE_DIR/collection_log.txt"
    WARNINGS_FILE="$CASE_DIR/warnings.txt"
    HASH_MANIFEST="$CASE_DIR/hash_manifest.txt"
    SUMMARY_FILE="$CASE_DIR/summary.txt"
    REPORT_JSON="$CASE_DIR/report.json"
    TIMELINE_CSV="$CASE_DIR/timeline.csv"

    touch "$COLLECTION_LOG" "$WARNINGS_FILE" "$HASH_MANIFEST" "$SUMMARY_FILE" "$REPORT_JSON" "$TIMELINE_CSV" \
        || die "Could not initialize output files"

    log "$TOOL_NAME v$VERSION started"
    log "Case directory created at $CASE_DIR"
    log "Raw output directory: $RAW_DIR"
    log "Report output directory: $REPORT_DIR"
}

check_dependencies() {
    log "Checking required and optional commands"

    local required_commands=("bash" "date" "find" "sha256sum" "tar" "gzip")
    local optional_commands=("ip" "ss" "netstat" "ps" "systemctl" "last" "who" "lsblk" "df" "hostnamectl" "uname" "uptime" "journalctl" "top")

    for cmd in "${required_commands[@]}"; do
        if check_command "$cmd"; then
            log "Found required command: $cmd"
        else
            warn "Missing required command: $cmd"
        fi
    done

    for cmd in "${optional_commands[@]}"; do
        if check_command "$cmd"; then
            log "Found optional command: $cmd"
        else
            warn "Optional command not found: $cmd"
        fi
    done
}

check_disk_space() {
    log "Checking available disk space"

    local available_kb=""
    available_kb=$(df "$OUT_BASE" 2>/dev/null | awk 'NR==2 {print $4}')

    if [[ -n "${available_kb:-}" ]]; then
        if (( available_kb < 102400 )); then
            warn "Low disk space detected: less than 100 MB available"
        else
            log "Disk space check passed"
        fi
    else
        warn "Unable to determine available disk space"
    fi
}

init_timeline() {
    echo "timestamp,event,details" > "$TIMELINE_CSV"
    echo "\"$(ts)\",\"collection_start\",\"$TOOL_NAME v$VERSION started\"" >> "$TIMELINE_CSV"
}

run_module() {
    local module_name="$1"
    local module_path="$MODULE_DIR/$module_name"

    if [[ ! -f "$module_path" ]]; then
        warn "Module file not found: $module_name"
        echo "\"$(ts)\",\"module_missing\",\"$module_name\"" >> "$TIMELINE_CSV"
        return 1
    fi

    if [[ ! -x "$module_path" ]]; then
        warn "Module is not executable: $module_name"
        echo "\"$(ts)\",\"module_not_executable\",\"$module_name\"" >> "$TIMELINE_CSV"
        return 1
    fi

    log "Running module: $module_name"
    echo "\"$(ts)\",\"module_start\",\"$module_name\"" >> "$TIMELINE_CSV"

    if RAW_DIR="$RAW_DIR" \
       REPORT_DIR="$REPORT_DIR" \
       WARNINGS_FILE="$WARNINGS_FILE" \
       COLLECTION_LOG="$COLLECTION_LOG" \
       RECENT_DAYS="$RECENT_DAYS" \
       "$module_path" >> "$COLLECTION_LOG" 2>&1; then
        log "Completed module: $module_name"
        echo "\"$(ts)\",\"module_complete\",\"$module_name\"" >> "$TIMELINE_CSV"
    else
        warn "Module failed: $module_name"
        echo "\"$(ts)\",\"module_failed\",\"$module_name\"" >> "$TIMELINE_CSV"
    fi
}

run_ai_explainer() {
    if [[ ! -f "$AI_SCRIPT" ]]; then
        warn "AI script not found: $AI_SCRIPT"
        echo "\"$(ts)\",\"ai_missing\",\"ai_explainer.sh\"" >> "$TIMELINE_CSV"
        return 1
    fi

    if [[ ! -x "$AI_SCRIPT" ]]; then
        warn "AI script is not executable: $AI_SCRIPT"
        echo "\"$(ts)\",\"ai_not_executable\",\"ai_explainer.sh\"" >> "$TIMELINE_CSV"
        return 1
    fi

    log "Running AI explainer"
    echo "\"$(ts)\",\"ai_start\",\"ai_explainer.sh\"" >> "$TIMELINE_CSV"

    if RAW_DIR="$RAW_DIR" \
       REPORT_DIR="$REPORT_DIR" \
       WARNINGS_FILE="$WARNINGS_FILE" \
       COLLECTION_LOG="$COLLECTION_LOG" \
       "$AI_SCRIPT" >> "$COLLECTION_LOG" 2>&1; then
        log "Completed AI explainer"
        echo "\"$(ts)\",\"ai_complete\",\"ai_explainer.sh\"" >> "$TIMELINE_CSV"
    else
        warn "AI explainer failed"
        echo "\"$(ts)\",\"ai_failed\",\"ai_explainer.sh\"" >> "$TIMELINE_CSV"
    fi
}

write_summary() {
    log "Writing summary file"

    local warning_count="0"
    warning_count=$(wc -l < "$WARNINGS_FILE" 2>/dev/null || echo "0")

    {
        echo "$TOOL_NAME Summary"
        echo "========================================"
        echo "Tool Version: $VERSION"
        echo "Case Directory: $CASE_DIR"
        echo "Collection Time: $(ts)"
        echo "Recent Days Window: $RECENT_DAYS"
        echo "Warnings Count: $warning_count"
        echo

        echo "Artifacts Generated:"
        echo "- raw/ directory"
        echo "- report/ directory"
        echo "- collection_log.txt"
        echo "- warnings.txt"
        echo "- hash_manifest.txt"
        echo "- summary.txt"
        echo "- report.json"
        echo "- timeline.csv"
        echo

        echo "Modules Attempted:"
        echo "- system_info.sh"
        echo "- user_activity.sh"
        echo "- process_service.sh"
        echo "- network.sh"
        echo "- recent_changes.sh"
        echo

        echo "AI Component:"
        if [[ -f "$REPORT_DIR/ai_summary.txt" ]]; then
            echo "- ai_summary.txt generated"
        else
            echo "- AI summary not generated"
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
    log "Writing report.json"

    local hostname_value="N/A"
    local os_value="N/A"
    local warning_count="0"
    local ai_generated="false"

    if [[ -f "$RAW_DIR/hostname.txt" ]]; then
        hostname_value=$(head -n 1 "$RAW_DIR/hostname.txt" | sed 's/"/\\"/g')
    fi

    if [[ -f "$RAW_DIR/os-release.txt" ]]; then
        os_value=$(grep '^PRETTY_NAME=' "$RAW_DIR/os-release.txt" 2>/dev/null | cut -d= -f2- | tr -d '"' | sed 's/"/\\"/g')
        [[ -z "$os_value" ]] && os_value="N/A"
    fi

    if [[ -f "$WARNINGS_FILE" ]]; then
        warning_count=$(wc -l < "$WARNINGS_FILE")
    fi

    if [[ -f "$REPORT_DIR/ai_summary.txt" ]]; then
        ai_generated="true"
    fi

    cat > "$REPORT_JSON" <<EOF
{
  "tool": "$TOOL_NAME",
  "version": "$VERSION",
  "case_directory": "$(basename "$CASE_DIR")",
  "collection_time": "$(ts)",
  "recent_days_window": "$RECENT_DAYS",
  "hostname": "$hostname_value",
  "operating_system": "$os_value",
  "warnings_count": "$warning_count",
  "ai_summary_generated": $ai_generated
}
EOF
}

generate_hash_manifest() {
    log "Generating SHA-256 hash manifest"

    : > "$HASH_MANIFEST"

    if ! check_command sha256sum; then
        warn "sha256sum not available; skipping hash manifest"
        return 1
    fi

    (
        cd "$CASE_DIR" || exit 1
        find . -type f ! -name "hash_manifest.txt" -print0 | sort -z | xargs -0 sha256sum
    ) > "$HASH_MANIFEST" 2>>"$COLLECTION_LOG"

    if [[ $? -eq 0 ]]; then
        log "Hash manifest created successfully"
    else
        warn "Failed to create hash manifest"
    fi
}

package_case() {
    log "Creating compressed case archive"

    local case_name
    case_name="$(basename "$CASE_DIR")"
    ARCHIVE_FILE="$OUT_BASE/${case_name}.tar.gz"
    ARCHIVE_HASH_FILE="${ARCHIVE_FILE}.sha256"

    (
        cd "$OUT_BASE" || exit 1
        tar -czf "$(basename "$ARCHIVE_FILE")" "$case_name"
    ) >> "$COLLECTION_LOG" 2>&1

    if [[ $? -eq 0 ]]; then
        log "Archive created: $ARCHIVE_FILE"
    else
        warn "Failed to create archive"
        return 1
    fi

    if check_command sha256sum; then
        sha256sum "$ARCHIVE_FILE" > "$ARCHIVE_HASH_FILE" 2>>"$COLLECTION_LOG"
        if [[ $? -eq 0 ]]; then
            log "Archive hash created: $ARCHIVE_HASH_FILE"
        else
            warn "Failed to hash archive"
        fi
    else
        warn "sha256sum not available; skipping archive hash"
    fi
}

finalize_timeline() {
    echo "\"$(ts)\",\"collection_complete\",\"$TOOL_NAME finished\"" >> "$TIMELINE_CSV"
}

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

    run_ai_explainer

    write_summary
    write_report_json
    generate_hash_manifest
    finalize_timeline
    package_case

    log "$TOOL_NAME completed successfully"
    log "Output located at: $CASE_DIR"
}

main "$@"
