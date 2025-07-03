#!/bin/bash

# Source include file
. ./scripts/INCLUDE.sh

# Exit on error
set -e

# Display profile information
make info

# Validasi
PROFILE=""
PACKAGES=""
MISC=""
EXCLUDED=""

# Hardware support - USB and LAN networking drivers
PACKAGES+=" kmod-usb-net-rtl8150 kmod-usb-net-rtl8152 kmod-usb-net-asix kmod-usb-net-asix-ax88179"
PACKAGES+=" kmod-mii kmod-usb-net kmod-usb-wdm kmod-usb-net-qmi-wwan uqmi luci-proto-qmi"
PACKAGES+=" kmod-usb-net-cdc-ether kmod-usb-serial-option kmod-usb-serial kmod-usb-serial-wwan qmi-utils"
PACKAGES+=" kmod-usb-serial-qualcomm kmod-usb-acm kmod-usb-net-cdc-ncm kmod-usb-net-cdc-mbim umbim"
PACKAGES+=" modemmanager luci-proto-modemmanager libmbim libqmi usbutils luci-proto-ncm"
PACKAGES+=" kmod-usb-net-huawei-cdc-ncm kmod-usb-net-rndis kmod-usb-net-sierrawireless kmod-usb-ohci kmod-usb-serial-sierrawireless"
PACKAGES+=" kmod-usb-uhci kmod-usb2 kmod-usb-ehci usb-modeswitch kmod-nls-utf8 mbim-utils xmm-modem kmod-macvlan"

# Modem management tools - ModemInfo serial support
PACKAGES+=" modeminfo luci-app-modeminfo atinout modemband luci-app-modemband sms-tool luci-app-sms-tool-js picocom minicom"
PACKAGES+=" modeminfo-serial-tw modeminfo-serial-dell modeminfo-serial-xmm modeminfo-serial-fibocom modeminfo-serial-sierra"

# VPN tunnel packages
OPENCLASH="coreutils-nohup bash ca-certificates ipset ip-full libcap libcap-bin ruby ruby-yaml kmod-tun kmod-inet-diag kmod-nft-tproxy luci-app-openclash"
NIKKI="nikki luci-app-nikki"
NEKO="bash kmod-tun php8 php8-cgi luci-app-neko"
PASSWALL="chinadns-ng resolveip dns2socks dns2tcp ipt2socks microsocks tcping xray-core xray-plugin luci-app-passwall"

add_tunnel_packages() {
    local option="$1"
    case "$option" in
        openclash)
            PACKAGES+=" $OPENCLASH"
            ;;
        openclash-nikki)
            PACKAGES+=" $OPENCLASH $NIKKI"
            ;;
        openclash-nikki-passwall)
            PACKAGES+=" $OPENCLASH $NIKKI $PASSWALL"
            ;;
        "")
            # tidak menambah tunnel packages
            ;;
    esac
}

# Storage - NAS - Monitoring - Autorekonek - Remote access - Bandwidth - Theme
PACKAGES+=" kmod-usb-storage kmod-usb-storage-uas ntfs-3g luci-app-diskman"
PACKAGES+=" internet-detector luci-app-internet-detector vnstat2 vnstati2 luci-app-netmonitor"
PACKAGES+=" tailscale luci-app-tailscale speedtest-cli luci-app-eqosplus"
PACKAGES+=" luci-theme-argon luci-theme-material"

# PHP packages
PACKAGES+=" php8 php8-fastcgi php8-fpm php8-mod-session php8-mod-ctype php8-mod-fileinfo php8-mod-zip php8-mod-iconv php8-mod-mbstring zoneinfo-core zoneinfo-asia"

# MISC - Custom Packages
MISC+=" libc bash coreutils-base64 coreutils-sleep coreutils-stat coreutils-stty curl wget-ssl"
MISC+=" jq httping tar unzip parted resize2fs losetup zram-swap"
MISC+=" adb screen htop lolcat python3-pip uhttpd uhttpd-mod-ubus"
MISC+=" luci luci-base luci-mod-admin-full luci-lib-ip luci-compat luci-ssl"
MISC+=" luci-app-droidnet luci-app-ipinfo luci-app-lite-watchdog luci-app-mactodong luci-app-poweroffdevice"
MISC+=" luci-app-ramfree luci-app-tinyfm luci-app-ttyd luci-app-3ginfo-lite luci-app-mmconfig"

# Profil Name
configure_profile_packages() {
    local profile_name="$1"

    if [[ "$profile_name" == "rpi-4" ]]; then
        PACKAGES+=" kmod-i2c-bcm2835 i2c-tools kmod-i2c-core kmod-i2c-gpio"
    fi

    if [[ "${ARCH_2:-}" == "x86_64" ]] || [[ "${ARCH_3:-}" == "i386_pentium4" ]]; then
        PACKAGES+=" kmod-iwlwifi iw-full pciutils"
    fi

    if [[ "${TYPE:-}" == "OPHUB" ]]; then
        PACKAGES+=" kmod-fs-btrfs btrfs-progs luci-app-amlogic"
        EXCLUDED+=" -procd-ujail"
    elif [[ "${TYPE:-}" == "ULO" ]]; then
        PACKAGES+=" luci-app-amlogic"
        EXCLUDED+=" -procd-ujail"
    fi
}

# Packages base
configure_release_packages() {
    if [[ "${BASE:-}" == "openwrt" ]]; then
        PACKAGES+=" wpad-openssl iw iwinfo wireless-regdb kmod-cfg80211 kmod-mac80211 luci-app-temp-status"
        EXCLUDED+=" -dnsmasq"
    elif [[ "${BASE:-}" == "immortalwrt" ]]; then
        PACKAGES+=" wpad-openssl iw iwinfo wireless-regdb kmod-cfg80211 kmod-mac80211"
        EXCLUDED+=" -dnsmasq -cpusage -automount -libustream-openssl -default-settings-chn -luci-i18n-base-zh-cn"
        if [[ "${ARCH_2:-}" == "x86_64" ]] || [[ "${ARCH_3:-}" == "i386_pentium4" ]]; then
            EXCLUDED+=" -kmod-usb-net-rtl8152-vendor"
        fi
    fi
}

# 11. Build firmware
build_firmware() {
    local target_profile="$1"
    local tunnel_option="${2:-}"
    local build_files="files"

    log "INFO" "Starting build for profile '$target_profile' with tunnel option '$tunnel_option'..."

    configure_profile_packages "$target_profile"
    add_tunnel_packages "$tunnel_option"
    configure_release_packages

    # Add MISC+ ke PACKAGES
    PACKAGES+=" $MISC"

    make image PROFILE="$target_profile" PACKAGES="$PACKAGES $EXCLUDED" FILES="$build_files"
    local build_status=$?

    if [ "$build_status" -eq 0 ]; then
        log "SUCCESS" "Build completed successfully!"
    else
        log "ERROR" "Build failed with exit code $build_status"
        exit $build_status
    fi
}

# Validasi argumen
if [ -z "${1:-}" ]; then
    log "ERROR" "Profile not specified. Usage: $0 <profile> [tunnel_option]"
    exit 1
fi

# Running Build
build_firmware "$1" "${2:-}"
