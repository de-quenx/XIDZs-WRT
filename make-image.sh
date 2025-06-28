#!/bin/bash

. ./scripts/INCLUDE.sh

# Exit on error
set -e

# Profile info
make info

# Main configuration name
PROFILE=""
PACKAGES=""

# Modem Usb LAN Driver
PACKAGES+=" kmod-usb-net-rtl8150 kmod-usb-net-rtl8152 kmod-usb-net-asix kmod-usb-net-asix-ax88179"
PACKAGES+=" kmod-mii kmod-usb-net kmod-usb-wdm kmod-usb-net-rndis kmod-usb-net-sierrawireless kmod-usb-net-qmi-wwan uqmi \
kmod-usb-net-cdc-ether usb-modeswitch kmod-usb-acm kmod-usb-net-huawei-cdc-ncm kmod-usb-net-cdc-ncm \
kmod-usb-net-cdc-mbim umbim kmod-usb-serial-option kmod-usb-serial kmod-usb-serial-wwan kmod-usb-serial-qualcomm mbim-utils qmi-utils \
libqmi libmbim luci-proto-qmi modemmanager luci-proto-modemmanager xmm-modem usbutils \
kmod-usb-uhci kmod-usb-ohci kmod-usb2 kmod-usb-ehci kmod-usb3 kmod-macvlan"

# Modem Tools
PACKAGES+=" modeminfo luci-app-modeminfo atinout modemband luci-app-modemband luci-app-mmconfig sms-tool luci-app-sms-tool-js luci-app-3ginfo-lite picocom minicom"

# ModemInfo
PACKAGES+=" modeminfo-serial-tw modeminfo-serial-dell modeminfo-serial-xmm modeminfo-serial-fibocom modeminfo-serial-sierra"

# Tunnel VPN
OPENCLASH="coreutils-nohup bash ca-certificates ipset ip-full libcap libcap-bin ruby ruby-yaml kmod-tun kmod-inet-diag kmod-nft-tproxy luci luci-base luci-app-openclash"
NIKKI="nikki luci-app-nikki"
NEKO="bash kmod-tun php8 php8-cgi luci-app-neko"
PASSWALL="chinadns-ng resolveip dns2socks dns2tcp ipt2socks microsocks tcping xray-core xray-plugin luci-app-passwall"

# Handle_Tunnel
handle_tunnel_option() {
    if [[ "$1" == "openclash" ]]; then
        PACKAGES+=" $OPENCLASH"
    elif [[ "$1" == "openclash-nikki" ]]; then
        PACKAGES+=" $OPENCLASH $NIKKI" 
    elif [[ "$1" == "openclash-nikki-passwall" ]]; then
        PACKAGES+=" $OPENCLASH $NIKKI $PASSWALL"
    fi
}

# Nas And Storage
PACKAGES+=" luci-app-diskman kmod-usb-storage kmod-usb-storage-uas ntfs-3g"

# Bandwidth And Network Monitoring
PACKAGES+=" internet-detector luci-app-internet-detector vnstat2 vnstati2 luci-app-netmonitor"

# Remote Services
PACKAGES+=" tailscale luci-app-tailscale"

# Bandwidth And Speedtest
PACKAGES+=" speedtest-cli luci-app-eqosplus"

# Theme
PACKAGES+=" luci-theme-argon luci-theme-alpha luci-theme-material"

# Php8
PACKAGES+=" libc php8 php8-fastcgi php8-fpm php8-mod-session php8-mod-ctype php8-mod-fileinfo php8-mod-zip php8-mod-iconv php8-mod-mbstring zoneinfo-core zoneinfo-asia"

# Misc And Custom Package
MISC=""

# Handle_profile
handle_profile_packages() {
    if [ "$1" == "rpi-4" ]; then
        MISC+=" kmod-i2c-bcm2835 i2c-tools kmod-i2c-core kmod-i2c-gpio"
    elif [ "$ARCH_2" == "x86_64" ]; then
        MISC+=" kmod-iwlwifi iw-full pciutils"
    fi

    # Packages OPHUB | ULO
    if [[ "${TYPE}" == "OPHUB" ]]; then
        MISC+=" kmod-fs-btrfs btrfs-progs luci-app-amlogic"
        EXCLUDED+=" -procd-ujail"
    elif [[ "${TYPE}" == "ULO" ]]; then
        MISC+=" luci-app-amlogic"
        EXCLUDED+=" -procd-ujail"
    fi
}

# Handle_release
handle_release_packages() {
    if [ "${BASE}" == "openwrt" ]; then
        MISC+=" wpad-openssl iw iwinfo wireless-regdb kmod-cfg80211 kmod-mac80211 luci-app-temp-status"
        EXCLUDED+=" -dnsmasq"
    elif [ "${BASE}" == "immortalwrt" ]; then
        MISC+=" wpad-openssl iw iwinfo wireless-regdb kmod-cfg80211 kmod-mac80211"
        EXCLUDED+=" -dnsmasq -cpusage -automount -libustream-openssl -default-settings-chn -luci-i18n-base-zh-cn"
        if [ "$ARCH_2" == "x86_64" ]; then
            EXCLUDED+=" -kmod-usb-net-rtl8152-vendor"
        fi
    fi
}

# Tambahkan paket misc umum
MISC+=" adb parted losetup resize2fs block-mount coreutils-base64 coreutils-stty coreutils-stat coreutils-sleep \
htop bash curl wget-ssl tar unzip jq httping screen lolcat \
uhttpd uhttpd-mod-ubus python3-pip zram-swap luci-app-poweroffdevice luci-app-ramfree luci-app-ttyd \
luci-app-lite-watchdog luci-app-ipinfo luci-app-droidnet luci-app-mactodong luci-app-tinyfm"

# Main Build Function
build_firmware() {
    local profile=$1
    local tunnel_option=$2

    log "INFO" "Memulai build untuk profil: $profile"
    
    handle_profile_packages "$profile"
    handle_tunnel_option "$tunnel_option"
    handle_release_packages
    
    # Tambahkan paket MISC ke PACKAGES
    PACKAGES+="$MISC"
    
    # Custom Files
    FILES="files"
    
    make image PROFILE="$profile" PACKAGES="$PACKAGES $EXCLUDED" FILES="$FILES" 2>&1
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log "INFO" "Build Selesai dengan Sukses!"
    else
        log "ERROR" "Build gagal. Periksa log untuk detail."
    fi
}

# Eksekusi script utama
if [ -z "$1" ]; then
    log "ERROR" "Profil tidak ditentukan"
fi

build_firmware "$1" "$2"