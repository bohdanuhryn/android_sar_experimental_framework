logger() {
    local level=$1
    local function=$2
    local message=$3
    echo "[$level] $function ($(date)): $message"
}

info_log() {
    local function=$1
    local message=$2
    logger "INFO" "$function" "$message"
}
