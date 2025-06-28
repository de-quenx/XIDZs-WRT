#!/bin/bash

# Source include file
. ./scripts/INCLUDE.sh

# Exit on error
set -e

# Display profile information
make info

# Initialize package variables
PROFILE=""
PACKAGES=""

# Hardware support packages - USB Networking drivers
PACKAGES+=" kmod-usb-net-rtl8150 kmod-usb-net-rtl8152 kmod-usb-net-asix kmod-usb-net-asix-ax88179"
PACKAGES+=" kmod-mii kmod-usb-net kmod-usb-wdm kmod-usb-net-rndis kmod-usb-net-sierrawireless kmod-usb-net-qmi-wwan uqmi"
PACKAGES+=" kmod-usb-net-cdc-ether usb-modeswitch kmod-usb-acm kmod-usb-net-huawei-cdc-ncm kmod-usb-net-cdc-ncm"
PACKAGES+=" kmod-usb-net-cdc-mbim umbim kmod-usb-serial-option kmod-usb-serial kmod-usb-serial-wwan kmod-usb-serial-qualcomm mbim-utils qmi-utils"
PACKAGES+=" libqmi libmbim modemmanager luci-proto-modemmanager luci-proto-qmi xmm-modem usbutils"
PACKAGES+=" kmod-usb-uhci kmod-usb-ohci kmod-usb2 kmod-usb-ehci kmod-usb3 kmod-macvlan"

# Modem management tools
PACKAGES+=" modeminfo luci-app-modeminfo atinout modemband luci-app-modemband luci-app-mmconfig sms-tool luci-app-sms-tool-js luci-app-3ginfo-lite picocom minicom"

# ModemInfo serial support packages
PACKAGES+=" modeminfo-serial-tw modeminfo-serial-dell modeminfo-serial-xmm modeminfo-serial-fibocom modeminfo-serial-sierra"

# VPN tunnel package groups
OPENCLASH="coreutils-nohup bash ca-certificates ipset ip-full libcap libcap-bin ruby ruby-yaml kmod-tun kmod-inet-diag kmod-nft-tproxy luci luci-base luci-app-openclash"
NIKKI="nikki luci-app-nikki"
NEKO="bash kmod-tun php8 php8-cgi luci-app-neko"
PASSWALL="chinadns-ng resolveip dns2socks dns2tcp ipt2socks microsocks tcping xray-core xray-plugin luci-app-passwall"

# Function to add requested tunnel packages
add_tunnel_packages() {
    local option="$1"
    
    case "$option" in
        "openclash")
            PACKAGES+=" $OPENCLASH"
            ;;
        "openclash-nikki")
            PACKAGES+=" $OPENCLASH $NIKKI"
            ;;
        "openclash-nikki-passwall")
            PACKAGES+=" $OPENCLASH $NIKKI $PASSWALL"
            ;;
    esac
    
    log "INFO" "Added tunnel option: $option"
}

# Storage and NAS functionality
PACKAGES+=" luci-app-diskman kmod-usb-storage kmod-usb-storage-uas ntfs-3g"

# Network monitoring tools
PACKAGES+=" internet-detector luci-app-internet-detector vnstat2 vnstati2 luci-app-netmonitor"

# Remote access services
PACKAGES+=" tailscale luci-app-tailscale"

# Bandwidth testing and management
PACKAGES+=" speedtest-cli luci-app-eqosplus"

# UI themes
PACKAGES+=" luci-theme-argon luci-theme-alpha luci-theme-material"

# PHP support packages
PACKAGES+=" libc php8 php8-fastcgi php8-fpm php8-mod-session php8-mod-ctype php8-mod-fileinfo php8-mod-zip php8-mod-iconv php8-mod-mbstring zoneinfo-core zoneinfo-asia"

# Initialize variables for misc packages and exclusions
MISC=""
EXCLUDED=""

# Add hardware-specific packages based on profile
configure_profile_packages() {
    local profile_name="$1"
    
    # Add Raspberry Pi specific packages
    if [ "$profile_name" == "rpi-4" ]; then
        MISC+=" kmod-i2c-bcm2835 i2c-tools kmod-i2c-core kmod-i2c-gpio"
        log "INFO" "Added Raspberry Pi specific packages"
    fi
    
    # Add x86_64 specific packages
    if [ "$ARCH_2" == "x86_64" ]; then
        MISC+=" kmod-iwlwifi iw-full pciutils"
        log "INFO" "Added x86_64 specific packages"
    fi
    
    # Add build type specific packages
    if [[ "${TYPE}" == "OPHUB" ]]; then
        MISC+=" kmod-fs-btrfs btrfs-progs luci-app-amlogic"
        EXCLUDED+=" -procd-ujail"
        log "INFO" "Configured for OPHUB build type"
    elif [[ "${TYPE}" == "ULO" ]]; then
        MISC+=" luci-app-amlogic"
        EXCLUDED+=" -procd-ujail"
        log "INFO" "Configured for ULO build type"
    fi
}

# Add base release specific packages
configure_release_packages() {
    if [ "${BASE}" == "openwrt" ]; then
        MISC+=" wpad-openssl iw iwinfo wireless-regdb kmod-cfg80211 kmod-mac80211 luci-app-temp-status"
        EXCLUDED+=" -dnsmasq"
        log "INFO" "Configured for OpenWrt base"
    elif [ "${BASE}" == "immortalwrt" ]; then
        MISC+=" wpad-openssl iw iwinfo wireless-regdb kmod-cfg80211kmod-mac80211"
        EXCLUDED+=" -dnsmasq -cpusage -automount -libustream-openssl -default-settings-chn -luci-i18n-base-zh-cn"
        if [ "$ARCH_2" == "x86_64" ]; then
        EXCLUDED+=" -kmod-usb-net-rtl8152-vendor"
        fi
        log "INFO" "Configured for ImmortalWrt base"
    fi
}

# Add common utility packages
MISC+=" coreutils-base64 coreutils-sleep coreutils-stat coreutils-stty block-mount losetup parted resize2fs"
MISC+=" bash luci luci-ssl uhttpd uhttpd-mod-ubus curl wget-ssl tar unzip jq httping python3-pip zram-swap"
MISC+=" adb htop screen lolcat luci-app-poweroffdevice luci-app-ramfree luci-app-ttyd luci-app-lite-watchdog"
MISC+=" luci-app-ipinfo luci-app-droidnet luci-app-mactodong luci-app-tinyfm"

# Main firmware build function
build_firmware() {
    local target_profile="$1"
    local tunnel_option="$2"
    local build_files="files"
    
    log "INFO" "==============================================="
    log "INFO" "Starting build for profile: $target_profile"
    log "INFO" "Tunnel option: $tunnel_option"
    log "INFO" "==============================================="
    # Configure packages based on profile and options
    configure_profile_packages "$target_profile"
    add_tunnel_packages "$tunnel_option"
    configure_release_packages
    
    # Add misc packages to the main package list
    PACKAGES+=" $MISC"
    log "INFO" "Building image with profile: $target_profile"
    
    # Execute the build command
    make image PROFILE="$target_profile" PACKAGES="$PACKAGES $EXCLUDED" FILES="$build_files" 2>&1
    local build_status=${PIPESTATUS[0]}
    if [ $build_status -eq 0 ]; then
        log "SUCCESS" "Build completed successfully!"
    else
        log "ERROR" "Build failed with exit code $build_status"
        exit $build_status
    fi
}

# Validate arguments
if [ -z "$1" ]; then
    log "ERROR" "Profile not specified. Usage: $0 <profile> [tunnel_option]"
    exit1
fi

# Execute the build with provided arguments
build_firmware "$1" "$2"
