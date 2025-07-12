#!/bin/bash

# Minimal bash version check (require 4+ for associative arrays and nameref)
if (( BASH_VERSINFO[0] < 4 )); then
    echo "Error: This script requires bash version 4 or higher." >&2
    exit 1
fi

# Enable strict mode for better error handling
set -euo pipefail
IFS=$'\n\t'

# Setup colors and formatting variables
setup_colors() {
    PURPLE="\033[95m"
    BLUE="\033[94m"
    GREEN="\033[92m"
    YELLOW="\033[93m"
    RED="\033[91m"
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    RESET="\033[0m"

    STEPS="[${PURPLE} STEPS ${RESET}]"
    INFO="[${BLUE} INFO ${RESET}]"
    SUCCESS="[${GREEN} SUCCESS ${RESET}]"
    WARNING="[${YELLOW} WARNING ${RESET}]"
    ERROR="[${RED} ERROR ${RESET}]"

    # Formatting escapes
    CL="\033[m"
    UL="\033[4m"
    BOLD="\033[1m"
    BFR="\r\033[K"
    HOLD=" "
    TAB="  "
}

# **PENTING: Panggil setup_colors seawal mungkin agar variabel warna terdefinisi saat script mulai**
setup_colors

# Global variables for configuration
declare -A CONFIG=(
    ["MAX_RETRIES"]=5
    ["RETRY_DELAY"]=2
    ["SPINNER_INTERVAL"]=0.1
    ["DEBUG"]="false"
)

# Cleanup function
cleanup() {
    printf "\e[?25h"  # Ensure cursor is visible
    # Kill spinner jobs if any
    jobs -p 2>/dev/null | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%d-%m-%Y %H:%M:%S')

    case "$level" in
        "ERROR")   echo -e "${ERROR} $message" >&2 ;;
        "STEPS")   echo -e "${STEPS} $message" ;;
        "WARNING") echo -e "${WARNING} $message" ;;
        "SUCCESS") echo -e "${SUCCESS} $message" ;;
        "INFO")    echo -e "${INFO} $message" ;;
        *)         echo -e "${INFO} $message" ;;
    esac
}

# Error message and exit
error_msg() {
    local msg="$1"
    local line_number=${2:-${BASH_LINENO[0]}}
    echo -e "${ERROR} ${msg} (Line: ${line_number})" >&2
    echo "Call stack:" >&2
    local frame=0
    while caller $frame; do
        ((frame++))
    done >&2
    exit 1
}

# Spinner for background process
spinner() {
    local pid=$1
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local colors=("\033[31m" "\033[33m" "\033[32m" "\033[36m" "\033[34m" "\033[35m")

    printf "\e[?25l"  # hide cursor

    while kill -0 "$pid" 2>/dev/null; do
        for ((i=0; i < ${#frames[@]}; i++)); do
            printf "\r ${colors[i]}%s${RESET}" "${frames[i]}"
            sleep "${CONFIG[SPINNER_INTERVAL]}"
        done
    done

    printf "\e[?25h"  # show cursor
    wait "$pid"
    return $?
}

# Command install with spinner and error handling
cmdinstall() {
    local cmd="$1"
    local desc="${2:-$cmd}"

    log "INFO" "Installing: $desc"

    # Run the command in a subshell and background it to use spinner
    ( eval "$cmd" ) &
    local pid=$!
    spinner "$pid"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log "SUCCESS" "$desc installed successfully"
        if [[ "${CONFIG[DEBUG]}" == "true" ]]; then set -x; fi
    else
        error_msg "Failed to install $desc"
        return 1
    fi
}

# Dependency check including version extraction, fallback if grep -P not available
check_dependencies() {
    local -A dependencies=(
        ["aria2"]="aria2c --version | head -n1 | grep -oE '[0-9]+(\.[0-9]+)+'"
        ["curl"]="curl --version | head -n1 | grep -oE '[0-9]+(\.[0-9]+)+'"
        ["tar"]="tar --version | head -n1 | grep -oE '[0-9]+(\.[0-9]+)+'"
        ["gzip"]="gzip --version | head -n1 | grep -oE '[0-9]+(\.[0-9]+)+'"
        ["unzip"]="unzip -v | head -n1 | grep -oE '[0-9]+(\.[0-9]+)+'"
        ["git"]="git --version | head -n1 | grep -oE '[0-9]+(\.[0-9]+)+'"
        ["wget"]="wget --version | head -n1 | grep -oE '[0-9]+(\.[0-9]+)+'"
        ["jq"]="jq --version | grep -oE '[0-9]+(\.[0-9]+)+'"
    )

    log "STEPS" "Checking system dependencies..."

    # Check if apt-get available (Ubuntu/Debian)
    if ! command -v apt-get >/dev/null 2>&1; then
        error_msg "apt-get not found. Unsupported environment."
        return 1
    fi

    if ! sudo apt-get update -qq &>/dev/null; then
        error_msg "Failed to update package lists"
        return 1
    fi

    for pkg in "${!dependencies[@]}"; do
        local version_cmd="${dependencies[$pkg]}"
        local installed_version=""

        if command -v "$pkg" >/dev/null 2>&1; then
            installed_version=$(eval "$version_cmd" 2>/dev/null || echo "")
            if [[ -n "$installed_version" ]]; then
                log "SUCCESS" "Found $pkg version $installed_version"
                continue
            fi
        fi

        log "WARNING" "Installing $pkg..."
        if ! sudo apt-get install -y "$pkg" &>/dev/null; then
            error_msg "Failed to install $pkg"
            return 1
        fi
        # Recheck version
        installed_version=$(eval "$version_cmd" 2>/dev/null || echo "")
        if [[ -n "$installed_version" ]]; then
            log "SUCCESS" "Installed $pkg version $installed_version"
        else
            log "WARNING" "Installed $pkg but version check failed"
        fi
    done

    log "SUCCESS" "All dependencies are satisfied!"
}

# Download file using aria2c with retries
ariadl() {
    if [ "$#" -lt 1 ]; then
        error_msg "Usage: ariadl <URL> [OUTPUT_FILE]"
        return 1
    fi

    log "STEPS" "Aria2 Downloader"

    local URL=$1
    local OUTPUT_FILE=""
    local OUTPUT_DIR=""
    local RETRY_COUNT=0
    local MAX_RETRIES=${CONFIG[MAX_RETRIES]}
    local RETRY_DELAY=${CONFIG[RETRY_DELAY]}

    if [ "$#" -eq 1 ]; then
        OUTPUT_FILE=$(basename "$URL")
        OUTPUT_DIR="."
    else
        OUTPUT_FILE=$(basename "$2")
        OUTPUT_DIR=$(dirname "$2")
    fi

    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
    fi

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        log "INFO" "Downloading: $URL (Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"

        if [ -f "$OUTPUT_DIR/$OUTPUT_FILE" ]; then
            rm -f "$OUTPUT_DIR/$OUTPUT_FILE"
        fi

        aria2c -q -d "$OUTPUT_DIR" -o "$OUTPUT_FILE" "$URL"

        if [ $? -eq 0 ]; then
            log "SUCCESS" "Downloaded: $OUTPUT_FILE"
            return 0
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                log "WARNING" "Download failed. Retrying..."
                sleep "$RETRY_DELAY"
            fi
        fi
    done

    error_msg "Failed to download: $OUTPUT_FILE after $MAX_RETRIES attempts"
    return 1
}

# Download multiple packages given array with format "filename|base_url"
download_packages() {
    local -n package_list="$1"  # nameref for array
    local download_dir="packages"

    mkdir -p "$download_dir"

    download_file() {
        local url="$1"
        local output="$2"
        local max_retries=5
        local retry=0

        while [ $retry -lt $max_retries ]; do
            if ariadl "$url" "$output"; then
                return 0
            fi
            retry=$((retry + 1))
            log "WARNING" "Retry $retry/$max_retries for $output"
            sleep 2
        done
        return 1
    }

    for entry in "${package_list[@]}"; do
        IFS="|" read -r filename base_url <<< "$entry"
        unset IFS

        if [[ -z "$filename" || -z "$base_url" ]]; then
            log "ERROR" "Invalid entry format: $entry"
            continue
        fi

        local download_url=""
        if [[ "$base_url" == *"api.github.com"* ]]; then
            # Query GitHub API assets with jq
            local file_urls=""
            if ! file_urls=$(curl -sL "$base_url" | jq -r '.assets[].browser_download_url' 2>/dev/null); then
                log "ERROR" "Failed to parse JSON from $base_url"
                continue
            fi
            download_url=$(echo "$file_urls" | grep -E '\.(ipk|apk)$' | grep -i "$filename" | sort -V | tail -1)
        else
            # Download and parse webpage, find matching package
            local page_content=""
            if ! page_content=$(curl -sL --max-time 30 --retry 3 --retry-delay 2 "$base_url"); then
                log "ERROR" "Failed to fetch page: $base_url"
                continue
            fi

            # Patterns try match filenames with extensions
            local patterns=(
                "${filename}[^\"]*\\.(ipk|apk)"
                "${filename}_.*\\.(ipk|apk)"
                "${filename}.*\\.(ipk|apk)"
            )

            # Try to find download URL matching pattern
            for pattern in "${patterns[@]}"; do
                download_url=$(echo "$page_content" | grep -oE "\"${pattern}\"" | tr -d '"' | sort -V | tail -n 1 || true)
                if [[ -n "$download_url" ]]; then
                    # Check if download_url already absolute URL or relative
                    if [[ "$download_url" =~ ^https?:// ]]; then
                        # full URL ready
                        :
                    else
                        # concat base_url without trailing slash + slash + download_url
                        download_url="${base_url%/}/$download_url"
                    fi
                    break
                fi
            done
        fi

        if [[ -z "$download_url" ]]; then
            log "ERROR" "No matching package found for $filename"
            continue
        fi

        local output_file="$download_dir/$(basename "$download_url")"
        if ! download_file "$download_url" "$output_file"; then
            error_msg "Failed to download $filename"
        fi
    done

    return 0
}

# Main function, entry point
main() {

    check_dependencies || exit 1

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
