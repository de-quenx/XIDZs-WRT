#!/bin/bash

# Source the include file containing common functions and variables
if [[ ! -f "./scripts/INCLUDE.sh" ]]; then
    error_msg "INCLUDE.sh not found in ./scripts/"
    exit 1
fi

. ./scripts/INCLUDE.sh

# Define repositories with proper quoting
declare -A REPOS
REPOS+=(
    ["OPENWRT"]="https://downloads.openwrt.org/releases/packages-${VEROP}/${ARCH_3}"
    ["IMMORTALWRT"]="https://downloads.immortalwrt.org/releases/packages-${VEROP}/${ARCH_3}"
    ["KIDDIN9"]="https://dl.openwrt.ai/releases/24.10/packages/${ARCH_3}/kiddin9"
    ["GSPOTX2F"]="https://github.com/gSpotx2f/packages-openwrt/raw/refs/heads/master/current"
    ["FANTASTIC"]="https://fantastic-packages.github.io/packages/releases/${VEROP}/packages/x86_64"
    ["DLLKIDS"]="https://op.dllkids.xyz/packages/${ARCH_3}"
    ["OPENWRTRU"]="https://openwrt.132lan.ru/packages/24.10/packages/${ARCH_3}/modemfeed"
)

# Define package categories with improved structure
declare -a packages_custom
packages_custom+=(
    "modeminfo_|${REPOS[KIDDIN9]}"
    "luci-app-modeminfo_|${REPOS[KIDDIN9]}"
    "modeminfo-serial-tw_|${REPOS[KIDDIN9]}"
    "modeminfo-serial-dell_|${REPOS[KIDDIN9]}"
    "modeminfo-serial-sierra_|${REPOS[KIDDIN9]}"
    "modeminfo-serial-xmm_|${REPOS[KIDDIN9]}"
    "modeminfo-serial-fibocom_|${REPOS[KIDDIN9]}"
    "modeminfo-serial-sierra_|${REPOS[KIDDIN9]}"
    #"luci-app-mmconfig_|${REPOS[OPENWRTRU]}"
    
    "atinout_|${REPOS[KIDDIN9]}"
    "luci-app-diskman_|${REPOS[KIDDIN9]}"
    #"luci-app-poweroff_|${REPOS[DLLKIDS]}"
    "luci-app-poweroffdevice_|${REPOS[KIDDIN9]}" 
    "xmm-modem_|${REPOS[KIDDIN9]}"
    
    "luci-app-lite-watchdog_|${REPOS[KIDDIN9]}"
    #"luci-app-speedtest-web_|${REPOS[KIDDIN9]}"
    #"luci-app-fancontrol_|${REPOS[KIDDIN9]}"
    "luci-app-atcommands_|${REPOS[KIDDIN9]}"
    "tailscale_|${REPOS[KIDDIN9]}"
    
    "luci-app-oled_|${REPOS[KIDDIN9]}"
    "modemband_|${REPOS[IMMORTALWRT]}/packages"
    "luci-app-ramfree_|${REPOS[IMMORTALWRT]}/luci"
    "luci-app-modemband_|${REPOS[IMMORTALWRT]}/luci"
    "luci-app-sms-tool-js_|${REPOS[IMMORTALWRT]}/luci"
    "dns2tcp_|${REPOS[IMMORTALWRT]}/packages"
    "luci-theme-argon_|${REPOS[IMMORTALWRT]}/luci"
    
    "speedtest-cli_|${REPOS[KIDDIN9]}"
    "luci-app-eqosplus_|${REPOS[KIDDIN9]}"
    "luci-app-internet-detector_|${REPOS[KIDDIN9]}"
    "internet-detector_|${REPOS[KIDDIN9]}"
    #"internet-detector-mod-modem-restart_|${REPOS[KIDDIN9]}"
    "luci-app-temp-status_|${REPOS[KIDDIN9]}"
    #"luci-theme-edge_|${REPOS[KIDDIN9]}"
    
    "luci-app-tinyfm_|https://api.github.com/repos/bobbyunknown/luci-app-tinyfm/releases/latest"
    "luci-app-droidnet_|https://api.github.com/repos/animegasan/luci-app-droidmodem/releases/latest"
    "luci-theme-alpha_|https://api.github.com/repos/derisamedia/luci-theme-alpha/releases/latest"
    "luci-app-tailscale_|https://api.github.com/repos/asvow/luci-app-tailscale/releases/latest"
    #"luci-app-rakitanmanager_|https://api.github.com/repos/rtaserver/RakitanManager/releases/latest"
    "luci-app-ipinfo_|https://api.github.com/repos/bobbyunknown/luci-app-ipinfo/releases/latest"
)

if [[ "${TYPE}" == "OPHUB" || "${TYPE}" == "ULO" ]]; then
    log "INFO" "Add Packages Amlogic In ${TYPE}.."
    packages_custom+=(
        "luci-app-amlogic_|https://api.github.com/repos/ophub/luci-app-amlogic/releases/latest"
    )
fi

# Enhanced package verification function
verify_packages() {
    local pkg_dir="packages"
    local -a failed_packages=()
    local -a package_list=("${!1}")
    
    if [[ ! -d "$pkg_dir" ]]; then
        error_msg "Package directory not found: $pkg_dir"
        return 1
    fi
    
    local total_found=$(find "$pkg_dir" \( -name "*.ipk" -o -name "*.apk" \) | wc -l)
    log "INFO" "Found $total_found package files"
    
    for package in "${package_list[@]}"; do
        local pkg_name="${package%%|*}"
        if ! find "$pkg_dir" \( -name "${pkg_name}*.ipk" -o -name "${pkg_name}*.apk" \) -print -quit | grep -q .; then
            failed_packages+=("$pkg_name")
        fi
    done
    
    local failed=${#failed_packages[@]}
    
    if ((failed > 0)); then
        log "WARNING" "$failed packages failed to download:"
        for pkg in "${failed_packages[@]}"; do
            log "WARNING" "- $pkg"
        done
        return 1
    fi
    
    log "SUCCESS" "All packages downloaded successfully"
    return 0
}

# Main execution
main() {
    local rc=0
    
    # Download Custom packages
    log "INFO" "Downloading Custom packages..."
    download_packages packages_custom || rc=1
    
    # Verify all downloads
    log "INFO" "Verifying all packages..."
    verify_packages packages_custom || rc=1
    
    if [ $rc -eq 0 ]; then
        log "SUCCESS" "Package download and verification completed successfully"
    else
        error_msg "Package download or verification failed"
    fi
    
    return $rc
}

# Run main function if script is not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
