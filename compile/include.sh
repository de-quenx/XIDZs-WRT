#!/bin/bash

# Check bash version
if (( BASH_VERSINFO[0] < 4 )) || (( BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3 )); then
    echo "FATAL: Bash 4.3+ required for nameref support" >&2
    exit 1
fi

# Enable strict execution mode
set -euo pipefail
IFS=$'\n\t'

# Setup logging colors
setup_colors() {
    PURPLE="\033[95m"
    BLUE="\033[94m"
    GREEN="\033[92m"
    YELLOW="\033[93m"
    RED="\033[91m"
    RESET="\033[0m"
    STEPS="[${PURPLE} STEPS ${RESET}]"
    INFO="[${BLUE} INFO ${RESET}]"
    SUCCESS="[${GREEN} SUCCESS ${RESET}]"
    WARN="[${YELLOW} WARN ${RESET}]"
    ERROR="[${RED} ERROR ${RESET}]"
}
setup_colors

# Global configurations
declare -A CONFIG=(
    ["MAX_RETRIES"]=6
    ["RETRY_DELAY"]=2
    ["SPINNER_INTERVAL"]=0.1
    ["DEBUG"]="false"
)

# Cleanup background jobs on exit
cleanup() {
    printf "\e[?25h"
    jobs -p 2>/dev/null | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT

# Core logging function
log() {
    local level="$1" message="$2"
    case "$level" in
        "ERROR")   echo -e "${ERROR} $message" >&2 ;;
        "STEPS")   echo -e "${STEPS} $message" ;;
        "WARN")    echo -e "${WARN} $message" ;;
        "SUCCESS") echo -e "${SUCCESS} $message" ;;
        *)         echo -e "${INFO} $message" ;;
    esac
}

# Error handler
error_msg() {
    local msg="$1" line_number=${2:-${BASH_LINENO[0]}}
    echo -e "${ERROR} ${msg} (Line: ${line_number})" >&2
    echo "Trace:" >&2
    local frame=0
    while caller $frame; do ((frame++)); done >&2
    exit 1
}

# Loading spinner
spinner() {
    local pid=$1
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local colors=("\033[31m" "\033[33m" "\033[32m" "\033[36m" "\033[34m" "\033[35m")
    printf "\e[?25l"
    while kill -0 "$pid" 2>/dev/null; do
        for ((i=0; i < ${#frames[@]}; i++)); do
            printf "\r ${colors[i]}%s${RESET}" "${frames[i]}"
            sleep "${CONFIG[SPINNER_INTERVAL]}"
        done
    done
    printf "\e[?25h"
    wait "$pid"
    return $?
}

# Execute command with spinner
cmdinstall() {
    local cmd="$1" desc="${2:-$cmd}"
    log "INFO" "Installing: $desc"
    ( eval "$cmd" ) &
    spinner "$!"
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log "SUCCESS" "Installed: $desc"
        if [[ "${CONFIG[DEBUG]}" == "true" ]]; then set -x; fi
    else
        error_msg "Installation failed: $desc"
    fi
}

# Check system dependencies
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
    log "STEPS" "Checking system dependencies"
    if ! command -v apt-get >/dev/null 2>&1; then
        error_msg "apt-get is missing"
    fi
    if ! sudo apt-get update -qq &>/dev/null; then
        error_msg "Failed to update apt cache"
    fi
    for pkg in "${!dependencies[@]}"; do
        local version_cmd="${dependencies[$pkg]}" installed_version=""
        if command -v "$pkg" >/dev/null 2>&1; then
            installed_version=$(eval "$version_cmd" 2>/dev/null || echo "")
            if [[ -n "$installed_version" ]]; then
                log "SUCCESS" "$pkg ($installed_version) resolved"
                continue
            fi
        fi
        log "WARN" "Installing missing dependency: $pkg"
        if ! sudo apt-get install -y "$pkg" &>/dev/null; then
            error_msg "Failed to install: $pkg"
        fi
        installed_version=$(eval "$version_cmd" 2>/dev/null || echo "")
        if [[ -n "$installed_version" ]]; then
            log "SUCCESS" "$pkg ($installed_version) installed"
        else
            log "WARN" "$pkg installed, version check skipped"
        fi
    done
    log "SUCCESS" "All system dependencies satisfied"
}

# Determine package extension by OS version
get_package_extension() {
    local version="${1:-24.10}"
    local fw_version=$(echo "$version" | cut -d'.' -f1)
    if [[ "$fw_version" -ge 25 ]]; then
        echo "apk"
    else
        echo "ipk"
    fi
}

# Download files using aria2c
ariadl() {
    if [ "$#" -lt 1 ]; then error_msg "Usage: ariadl <URL> [OUTPUT_FILE]"; fi
    log "STEPS" "Downloading files"
    local URL=$1 OUTPUT_FILE="" OUTPUT_DIR="" RETRY_COUNT=0
    local MAX_RETRIES=${CONFIG[MAX_RETRIES]} RETRY_DELAY=${CONFIG[RETRY_DELAY]}
    if [ "$#" -eq 1 ]; then
        OUTPUT_FILE=$(basename "$URL")
        OUTPUT_DIR="."
    else
        OUTPUT_FILE=$(basename "$2")
        OUTPUT_DIR=$(dirname "$2")
    fi
    if [ ! -d "$OUTPUT_DIR" ]; then mkdir -p "$OUTPUT_DIR"; fi
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        log "INFO" "Fetching [Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES]: $URL"
        if [ -f "$OUTPUT_DIR/$OUTPUT_FILE" ]; then rm -f "$OUTPUT_DIR/$OUTPUT_FILE"; fi
        if aria2c -q -d "$OUTPUT_DIR" -o "$OUTPUT_FILE" "$URL"; then
            return 0
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            log "WARN" "Download failed, retrying in ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        fi
    done
    log "ERROR" "Download failed after $MAX_RETRIES attempts: $OUTPUT_FILE"
    return 1
}

# Fetch packages dynamically
download_packages() {
    local -n package_list="$1"
    local download_dir="packages"
    local pkg_ext=$(get_package_extension "${VEROP:-24.10}")
    mkdir -p "$download_dir"
    
    # Process package list
    for entry in "${package_list[@]}"; do
        IFS="|" read -r raw_pkg_name base_url <<< "$entry"
        unset IFS
        [[ -z "$raw_pkg_name" || -z "$base_url" ]] && continue
        
        # Detect architecture placeholder dynamically
        local target_arch=""
        local pkg_name="$raw_pkg_name"
        if [[ "$pkg_name" == *"{arch_3}"* || "$pkg_name" == *"{ARCH_3}"* ]]; then
            target_arch="${ARCH_3:-}"
            # Extract clean package name for exact regex base match
            pkg_name="${pkg_name//-\{arch_3\}/}"
            pkg_name="${pkg_name//_\{arch_3\}/}"
            pkg_name="${pkg_name//\{arch_3\}/}"
            pkg_name="${pkg_name//-\{ARCH_3\}/}"
            pkg_name="${pkg_name//_\{ARCH_3\}/}"
            pkg_name="${pkg_name//\{ARCH_3\}/}"
        fi
        
        local download_url=""
        # Strict regex ensures exact base name matches (bypasses versions)
        local strict_regex="(^|/)${pkg_name}(_|-)([0-9]|v[0-9]|r[0-9]|git-)"
        
        # Helper logic to filter architecture accurately
        filter_urls() {
            local urls="$1"
            local ext="$2"
            local res=$(echo "$urls" | grep -E "\.${ext}$" | grep -iE "$strict_regex" || true)
            
            # Apply secondary architecture filter if explicitly defined
            if [[ -n "$res" && -n "$target_arch" ]]; then
                local arch_res=$(echo "$res" | grep -i "$target_arch" || true)
                [[ -n "$arch_res" ]] && res="$arch_res"
            fi
            echo "$res" | sort -V | tail -n 1
        }

        # 1. Fallback for direct URL
        if [[ "$base_url" =~ \.(ipk|apk)$ ]]; then
            download_url="$base_url"

        # 2. GitHub API Releases
        elif [[ "$base_url" == *"api.github.com/repos/"*"/releases"* ]]; then
            local file_urls=$(curl -sL "$base_url" | jq -r '.assets[].browser_download_url' 2>/dev/null || echo "")
            download_url=$(filter_urls "$file_urls" "$pkg_ext")
            
            # Fallback to .ipk
            if [[ -z "$download_url" && "$pkg_ext" == "apk" ]]; then
                download_url=$(filter_urls "$file_urls" "ipk")
            fi

        # 3. Standard GitHub Release URL
        elif [[ "$base_url" == *"github.com/"*"/releases/latest"* ]]; then
            local api_url=$(echo "$base_url" | sed 's|github.com|api.github.com/repos|' | sed 's|/releases/latest|/releases/latest|')
            local file_urls=$(curl -sL "$api_url" | jq -r '.assets[].browser_download_url' 2>/dev/null || echo "")
            download_url=$(filter_urls "$file_urls" "$pkg_ext")
            
            if [[ -z "$download_url" && "$pkg_ext" == "apk" ]]; then
                download_url=$(filter_urls "$file_urls" "ipk")
            fi

        # 4. GitHub API Contents
        elif [[ "$base_url" == *"api.github.com/repos/"*"/contents/"* ]]; then
            local file_urls=$(curl -sL "$base_url" | jq -r '.[].download_url' 2>/dev/null || echo "")
            download_url=$(filter_urls "$file_urls" "$pkg_ext")
            
            if [[ -z "$download_url" && "$pkg_ext" == "apk" ]]; then
                download_url=$(filter_urls "$file_urls" "ipk")
            fi

        # 5. Direct Web Scraper
        else
            local page_content=$(curl -sL --max-time 30 --retry 4 --retry-delay 2 "$base_url" || echo "")
            local file_urls=$(echo "$page_content" | grep -oE 'href="[^"]+\.'${pkg_ext}'"' | sed 's/href="//;s/"//' || true)
            download_url=$(filter_urls "$file_urls" "$pkg_ext")
            
            # Fallback to .ipk
            if [[ -z "$download_url" && "$pkg_ext" == "apk" ]]; then
                file_urls=$(echo "$page_content" | grep -oE 'href="[^"]+\.ipk"' | sed 's/href="//;s/"//' || true)
                download_url=$(filter_urls "$file_urls" "ipk")
            fi
            
            # Absolute URL format
            if [[ -n "$download_url" && ! "$download_url" =~ ^https?:// ]]; then
                download_url="${base_url%/}/$download_url"
            fi
        fi
        
        if [[ -z "$download_url" ]]; then
            log "ERROR" "Package not found: $raw_pkg_name (.$pkg_ext) @ $base_url"
            continue
        fi
        
        # Trim architecture syntax from local filename cleanly
        local output_file="$(basename "$download_url")"
        if [[ -n "$target_arch" ]]; then
            output_file="${output_file//_${target_arch}/}"
            output_file="${output_file//-${target_arch}/}"
        fi
        
        # Output save path
        output_file="$download_dir/$output_file"
        if ! ariadl "$download_url" "$output_file"; then
            log "ERROR" "Failed to download: $raw_pkg_name"
        fi
    done
    return 0
}