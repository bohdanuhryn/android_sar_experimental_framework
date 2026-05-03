_format_log_line() {
    local level="$1"
    local function="$2"
    local message="$3"
    local timestamp
    timestamp=$(date +"%Y-%m-%dT%H:%M:%S")
    echo "[$level] $function ($timestamp): $message"
}

_log_file() {
    local line="$1"
    [[ -n "$LOG_FILE" ]] && echo "$line" >> "$LOG_FILE"
}

logger() {
    local line
    line=$(_format_log_line "$1" "$2" "$3")
    echo "$line"
    _log_file "$line"
}

log_info() {
    logger "INFO" "$1" "$2"
}

log_warn() {
    local line
    line=$(_format_log_line "WARN" "$1" "$2")
    echo "$line"
    echo "$line" >&2
    _log_file "$line"
}

log_debug() {
    [[ "$DEBUG" != "1" ]] && return 0
    logger "DEBUG" "$1" "$2"
}

log_error() {
    local line
    line=$(_format_log_line "ERROR" "$1" "$2")
    echo "$line"
    echo "$line" >&2
    _log_file "$line"
}
