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
PACKAGES+=" kmod-mii kmod-usb-net kmod-usb-wdm kmod-usb-net-qmi-wwan uqmi luci-proto-qmi"
PACKAGES+=" kmod-usb-net-cdc-ether kmod-usb-serial-option kmod-usb-serial kmod-usb-serial-wwan qmi-utils"
PACKAGES+=" kmod-usb-serial-qualcomm kmod-usb-acm kmod-usb-net-cdc-ncm kmod-usb-net-cdc-mbim umbim"
PACKAGES+=" modemmanager luci-proto-modemmanager libmbim libqmi usbutils luci-proto-ncm"
PACKAGES+=" kmod-usb-net-huawei-cdc-ncm kmod-usb-net-cdc-ether kmod-usb-net-rndis kmod-usb-net-sierrawireless kmod-usb-ohci kmod-usb-serial-sierrawireless"
PACKAGES+=" kmod-usb-uhci kmod-usb2 kmod-usb-ehci usb-modeswitch kmod-nls-utf8 mbim-utils xmm-modem kmod-macvlan"

# Modem management tools
PACKAGES+=" modeminfo luci-app-modeminfo atinout modemband luci-app-modemband sms-tool luci-app-sms-tool-js picocom minicom"

# ModemInfo serial support packages
PACKAGES+=" modeminfo-serial-tw modeminfo-serial-dell modeminfo-serial-xmm modeminfo-serial-fibocom modeminfo-serial-sierra"

# VPN tunnel package groups
OPENCLASH="coreutils-nohup bash ca-certificates ipset ip-full libcap libcap-bin ruby ruby-yaml kmod-tun kmod-inet-diag kmod-nft-tproxy luci-app-openclash"
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
PACKAGES+=" luci-theme-argon luci-theme-material"

# PHP support packages
PACKAGES+=" libc php8 php8-fastcgi php8-fpm php8-mod-session php8-mod-ctype php8-mod-fileinfo php8-mod-zip php8-mod-iconv php8-mod-mbstring zoneinfo-core zoneinfo-asia"

# Initialize variables for misc packages and exclusions
misc=""
EXCLUDED=""

# Add hardware-specific packages based on profile
configure_profile_packages() {
    local profile_name="$1"
    
    # Add Raspberry Pi specific packages
    if [ "$profile_name" == "rpi-4" ]; then
        misc+=" kmod-i2c-bcm2835 i2c-tools kmod-i2c-core kmod-i2c-gpio"
    fi
    
    # Add x86_64 specific packages
    if [ "$ARCH_2" == "x86_64" ]; then
        misc+=" kmod-iwlwifi iw-full pciutils"
    fi
    
    # Add build type specific packages
    if [[ "${TYPE}" == "OPHUB" ]]; then
        misc+=" luci-app-amlogic btrfs-progs kmod-fs-btrfs"
        EXCLUDED+=" -procd-ujail"
    elif [[ "${TYPE}" == "ULO" ]]; then
        misc+=" luci-app-amlogic"
        EXCLUDED+=" -procd-ujail"
    fi
}

# Add base release specific packages
configure_release_packages() {
    if [ "${BASE}" == "openwrt" ]; then
        misc+=" wpad-openssl iw iwinfo wireless-regdb kmod-cfg80211 kmod-mac80211 luci-app-temp-status"
        EXCLUDED+=" -dnsmasq"
    elif [ "${BASE}" == "immortalwrt" ]; then
        misc+=" wpad-openssl iw iwinfo wireless-regdb kmod-cfg80211 kmod-mac80211"
        EXCLUDED+=" -dnsmasq -cpusage -automount -libustream-openssl -default-settings-chn -luci-i18n-base-zh-cn"
        if [ "$ARCH_2" == "x86_64" ]; then
            EXCLUDED+=" -kmod-usb-net-rtl8152-vendor"
        elif [ "$ARCH_3" == "i386_pentium4" ]; then
            EXCLUDED+=" -kmod-usb-net-rtl8152-vendor"
        fi
    fi
}

# Common utility packages
misc+=" adb bash block-mount coreutils-base64 coreutils-sleep coreutils-stat coreutils-stty curl"
misc+=" htop httping jq libc losetup lolcat luci luci-ssl parted python3-pip"
misc+=" resize2fs screen tar uhttpd uhttpd-mod-ubus unzip wget-ssl zram-swap"
misc+=" luci-app-droidnet luci-app-ipinfo luci-app-lite-watchdog luci-app-mactodong"
misc+=" luci-app-poweroffdevice luci-app-ramfree luci-app-tinyfm luci-app-ttyd luci-app-3ginfo-lite luci-app-mmconfig"

# Main firmware build function
build_firmware() {
    local target_profile="$1"
    local tunnel_option="$2"
    local build_files="files"
    
    configure_profile_packages "$target_profile"
    add_tunnel_packages "$tunnel_option"
    configure_release_packages
    
    PACKAGES+=" $misc"
    
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