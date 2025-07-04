#!/bin/sh

# Setup logging
LOG_FILE="/root/setup-xidzwrt.log"
exec > "$LOG_FILE" 2>&1

# Function for logging with status
log_status() {
    local status="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$status" in
        "INFO")
            echo "[$timestamp] [INFO] $message"
            ;;
        "SUCCESS")
            echo "[$timestamp] [SUCCESS] ✓ $message"
            ;;
        "ERROR")
            echo "[$timestamp] [ERROR] ✗ $message"
            ;;
        "WARNING")
            echo "[$timestamp] [WARNING] ⚠ $message"
            ;;
        *)
            echo "[$timestamp] $message"
            ;;
    esac
}

# Function to check command status
check_status() {
    local command="$1"
    local description="$2"

    if eval "$command" >/dev/null 2>&1; then
        log_status "SUCCESS" "$description"
        return 0
    else
        log_status "ERROR" "$description - Command failed: $command"
        return 1
    fi
}

# Log header
log_status "INFO" "========================================="
log_status "INFO" "XIDZs-WRT Setup Script Started"
log_status "INFO" "Script setup by Xidz-x | Fidz"
log_status "INFO" "Installation time: $(date '+%A, %d %B %Y %T')"
log_status "INFO" "========================================="

# Please do not remove this script!!!
log_status "INFO" "Modifying firmware display..."
if sed -i "s#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' / ':'')+(luciversion||''),#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' By Xidz_x':''),#g" /www/luci-static/resources/view/status/include/10_system.js; then
    log_status "SUCCESS" "Firmware display modified"
else
    log_status "ERROR" "Failed to modify firmware display"
fi

check_status "sed -i -E 's/icons\/port_%s\.(svg|png)/icons\/port_%s.gif/g' /www/luci-static/resources/view/status/include/29_ports.js" "Port icons changed from PNG-SVG to GIF"

# Checking system release
log_status "INFO" "Checking system release..."
if grep -q "ImmortalWrt" /etc/openwrt_release; then
    log_status "INFO" "ImmortalWrt detected"
    check_status "sed -i 's/\(DISTRIB_DESCRIPTION='\''ImmortalWrt [0-9]*\.[0-9]*\.[0-9]*\).*'\''/\1'\''/g' /etc/openwrt_release" "ImmortalWrt release description cleaned"
    check_status "sed -i 's|system/ttyd|services/ttyd|g' /usr/share/luci/menu.d/luci-app-ttyd.json" "TTYD menu moved to services"
    BRANCH_VERSION=$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')
    log_status "INFO" "Branch version: $BRANCH_VERSION"
elif grep -q "OpenWrt" /etc/openwrt_release; then
    log_status "INFO" "OpenWrt detected"
    check_status "sed -i 's/\(DISTRIB_DESCRIPTION='\''OpenWrt [0-9]*\.[0-9]*\.[0-9]*\).*'\''/\1'\''/g' /etc/openwrt_release" "OpenWrt release description cleaned"
    BRANCH_VERSION=$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')
    log_status "INFO" "Branch version: $BRANCH_VERSION"
else
    log_status "WARNING" "Unknown system release"
fi

# Setting up root password
log_status "INFO" "Setting up root password..."
if (echo "xyyraa"; sleep 2; echo "xyyraa") | passwd > /dev/null 2>&1; then
    log_status "SUCCESS" "Root password configured"
else
    log_status "ERROR" "Failed to set root password"
fi

# Configuring hostname and timezone to Asia/Jakarta
log_status "INFO" "Configuring hostname and timezone to Asia/Jakarta..."
check_status "uci set system.@system[0].hostname='XIDZs-WRT'" "Hostname set to XIDZs-WRT"
check_status "uci set system.@system[0].timezone='WIB-7'" "Timezone set to WIB-7"
check_status "uci set system.@system[0].zonename='Asia/Jakarta'" "Zone name set to Asia/Jakarta"
check_status "uci delete system.ntp.server" "Existing NTP servers cleared"
check_status "uci add_list system.ntp.server='pool.ntp.org'" "Added pool.ntp.org NTP server"
check_status "uci add_list system.ntp.server='id.pool.ntp.org'" "Added id.pool.ntp.org NTP server"
check_status "uci add_list system.ntp.server='time.google.com'" "Added time.google.com NTP server"
check_status "uci commit system" "System configuration committed"

# Setting up default language to English
log_status "INFO" "Setting up default language to English..."
check_status "uci set luci.@core[0].lang='en'" "Language set to English"
check_status "uci commit luci" "LuCI language configuration committed"

# Configuring WAN and LAN interfaces
log_status "INFO" "Configuring WAN and LAN interfaces..."
check_status "uci set network.tethering=interface" "Tethering interface created"
check_status "uci set network.tethering.proto='dhcp'" "Tethering protocol set to DHCP"
check_status "uci set network.tethering.device='usb0'" "Tethering device set to usb0"
check_status "uci set network.modem=interface" "Modem interface created"
check_status "uci set network.modem.proto='dhcp'" "Modem protocol set to DHCP"
check_status "uci set network.modem.device='eth1'" "Modem device set to eth1"
check_status "uci set network.wan=interface" "WAN interface created"
check_status "uci set network.wan.proto='none'" "WAN protocol set to NONE"
check_status "uci set network.wan.device='wwan0'" "WAN device set to wwan0"
check_status "uci delete network.wan6" "Deleted wan6"
check_status "uci commit network" "Network configuration committed"

log_status "INFO" "Configuring firewall..."
check_status "uci set firewall.@zone[1].network='tethering modem'" "Firewall zone configured for TETHERING MODEM"
check_status "uci commit firewall" "Firewall configuration committed"

# Disabling IPv6 on LAN
log_status "INFO" "Disabling IPv6 on LAN..."
check_status "uci delete dhcp.lan.dhcpv6" "DHCPv6 disabled on LAN"
check_status "uci delete dhcp.lan.ra" "Router Advertisement disabled on LAN"
check_status "uci delete dhcp.lan.ndp" "NDP disabled on LAN"
check_status "uci commit dhcp" "DHCP configuration committed"

# Configuring wireless devices
log_status "INFO" "Configuring wireless devices..."

# Get or create the first wifi-device section
wifi_dev=$(uci show wireless | grep -m1 '=wifi-device' | cut -d'.' -f2 | cut -d'=' -f1)
if [ -z "$wifi_dev" ]; then
    wifi_dev=$(uci add wireless wifi-device)
    uci set wireless."$wifi_dev".type='mac80211'
    uci set wireless."$wifi_dev".channel='1'
    log_status "INFO" "New wireless device created: $wifi_dev"
fi

# Get or create the first wifi-iface section
wifi_iface=$(uci show wireless | grep -m1 '=wifi-iface' | cut -d'.' -f2 | cut -d'=' -f1)
if [ -z "$wifi_iface" ]; then
    wifi_iface=$(uci add wireless wifi-iface)
    uci set wireless."$wifi_iface".device="$wifi_dev"
    uci set wireless."$wifi_iface".mode='ap'
    uci set wireless."$wifi_iface".encryption='none'
    log_status "INFO" "New wireless interface created: $wifi_iface"
fi

# Configure wireless settings using dynamic section names
check_status "uci set wireless.$wifi_dev.disabled='0'" "WiFi device enabled"
check_status "uci set wireless.$wifi_iface.disabled='0'" "WiFi interface enabled"
check_status "uci set wireless.$wifi_dev.country='ID'" "WiFi country set to Indonesia"
check_status "uci set wireless.$wifi_iface.mode='ap'" "WiFi mode set to Access Point"
check_status "uci set wireless.$wifi_iface.encryption='none'" "WiFi encryption disabled"

if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo; then
    check_status "uci set wireless.$wifi_iface.ssid='XIDZs-WRT_5G'" "5GHz WiFi SSID set to XIDZs-WRT_5G"
    check_status "uci set wireless.$wifi_dev.channel='149'" "5GHz WiFi channel set to 149"
    check_status "uci set wireless.$wifi_dev.htmode='VHT80'" "5GHz WiFi HT mode set to VHT80"
else
    check_status "uci set wireless.$wifi_iface.ssid='XIDZs-WRT'" "WiFi SSID set to XIDZs-WRT"
    check_status "uci set wireless.$wifi_dev.channel='1'" "WiFi channel set to 1"
    check_status "uci set wireless.$wifi_dev.htmode='HT20'" "WiFi HT mode set to HT20"
    log_status "INFO" "Raspberry Pi 3/4 not detected, skipping 5GHz configuration"
fi

check_status "uci commit wireless" "Wireless configuration committed"
check_status "wifi reload && wifi up" "WiFi reloaded and started"

# Check wireless interface
if iw dev | grep -q Interface; then
    log_status "SUCCESS" "Wireless interface detected"
    if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo; then
        if ! grep -q "wifi up" /etc/rc.local; then
            check_status "sed -i '/exit 0/i # remove if you don't use wireless' /etc/rc.local" "Added WiFi comment to rc.local"
            check_status "sed -i '/exit 0/i sleep 10 && wifi up' /etc/rc.local" "Added WiFi startup command to rc.local"
        fi
        if ! grep -q "wifi up" /etc/crontabs/root; then
            if echo "# remove if you don't use wireless" >> /etc/crontabs/root && echo "0 */12 * * * wifi down && sleep 5 && wifi up" >> /etc/crontabs/root; then
                log_status "SUCCESS" "WiFi cron job added"
                check_status "/etc/init.d/cron restart" "Cron service restarted"
            else
                log_status "ERROR" "Failed to add WiFi cron job"
            fi
        fi
    fi
else
    log_status "WARNING" "No wireless device detected"
fi

# Removing Huawei ME909S and DW5821E USB modeswitch
log_status "INFO" "Removing Huawei ME909S and DW5821E USB modeswitch..."
check_status "sed -i -e '/12d1:15c1/,+5d' -e '/413c:81d7/,+5d' /etc/usb-mode.json" "USB modeswitch entries removed"

# Disabling XMM-Modem
log_status "INFO" "Disabling XMM-Modem"
check_status "uci set xmm-modem.@xmm-modem[0].enable='0'" "Disable xmm-modem"
check_status "uci commit xmm-modem" "Disabled xmm-modem committed"

# Disabling OPKG signature check
log_status "INFO" "Disabling OPKG signature check..."
check_status "sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf" "OPKG signature check disabled"

# Adding custom repository
log_status "INFO" "Adding custom repository..."
ARCH=$(grep "OPENWRT_ARCH" /etc/os-release | awk -F '"' '{print $2}')
if echo "src/gz custom_packages https://dl.openwrt.ai/latest/packages/$ARCH/kiddin9" >> /etc/opkg/customfeeds.conf; then
    log_status "SUCCESS" "Custom repository added for architecture: $ARCH"
else
    log_status "ERROR" "Failed to add custom repository"
fi

# Setting up Argon theme as default
log_status "INFO" "Setting up Argon theme as default..."
check_status "uci set luci.main.mediaurlbase='/luci-static/argon'" "Argon theme set as default"
check_status "uci commit luci" "LuCI theme configuration committed"

# Configuring TTYD without login password
log_status "INFO" "Configuring TTYD without login password..."
check_status "uci set ttyd.@ttyd[0].command='/bin/bash --login'" "TTYD login password removed"
check_status "uci commit ttyd" "TTYD configuration committed"

# Creating TinyFM symlink
log_status "INFO" "Creating TinyFM symlink..."
check_status "ln -s / /www/tinyfm/rootfs" "TinyFM rootfs symlink created"

# Checking for Amlogic device configuration
log_status "INFO" "Checking for Amlogic device configuration..."
if opkg list-installed | grep -q luci-app-amlogic; then
    log_status "INFO" "luci-app-amlogic detected"
    check_status "rm -f /etc/profile.d/30-sysinfo.sh" "Removed sysinfo profile script"
    check_status "sed -i '/exit 0/i #sleep 5 && /usr/bin/k5hgled -r' /etc/rc.local" "Added K5 LED command to rc.local (commented)"
    check_status "sed -i '/exit 0/i #sleep 5 && /usr/bin/k6hgled -r' /etc/rc.local" "Added K6 LED command to rc.local (commented)"
else
    log_status "INFO" "luci-app-amlogic not detected"
    check_status "rm -f /usr/bin/k5hgled /usr/bin/k6hgled /usr/bin/k5hgledon /usr/bin/k6hgledon" "Removed LED control binaries"
fi

# setup misc settings
log_status "INFO" "setup misc settings..."
check_status "sed -i -e 's/\\[ -f \\/etc\\/banner \\] && cat \\/etc\\/banner/#&/' -e 's/\\[ -n \"\\$FAILSAFE\" \\] && cat \\/etc\\/banner.failsafe/& || \\/usr\\/bin\\/idz/' /etc/profile" "Profile banner configuration modified"
check_status "chmod -R +x /sbin /usr/bin" "Binary directories permissions set"
check_status "chmod +x /etc/init.d/vnstat_backup" "vnstat_backup permission set"
check_status "chmod +x /usr/lib/ModemManager/connection.d/10-report-down" "ModemManager script permissions set"
check_status "chmod +x /www/cgi-bin/reset-vnstat.sh /www/vnstati/vnstati.sh" "Set permissions for vnstat script"
check_status "chmod 600 /etc/vnstat.conf" "vnstat.conf permission set"
check_status "chmod +x /root/install2.sh && /root/install2.sh" "install2 script executed"

# Add Auto Time Sync and Cache Clean
log_status "INFO" "Adding Auto Time Sync and Cache Clean..."
check_status "sed -i '/exit 0/i #sh /usr/bin/autojam.sh bug.com' /etc/rc.local" "Added Auto Time Sync command to rc.local"
check_status "sed -i '/exit 0/i sleep 15 && /sbin/free.sh' /etc/rc.local" "Added Cache Clean command to rc.local"

# Move jQuery library
log_status "INFO" "Moving jQuery library..."
check_status "mv /usr/share/netdata/web/lib/jquery-3.6.0.min.js /usr/share/netdata/web/lib/jquery-2.2.4.min.js" "jQuery library version changed"

# Create VnStat directory
log_status "INFO" "Creating VnStat directory..."
check_status "mkdir -p /etc/vnstat" "VnStat directory created"

# Restart Netdata and VnStat services
log_status "INFO" "Restarting Netdata and VnStat services..."
check_status "/etc/init.d/netdata restart" "Netdata service restarted"
check_status "/etc/init.d/vnstat restart" "VnStat service restarted"

# Run VnStati script
log_status "INFO" "Running VnStati script..."
check_status "/www/vnstati/vnstati.sh" "VnStati script executed"

# Enable VnStat database backup
log_status "INFO" "Enabling VnStat database backup..."
check_status "/etc/init.d/vnstat_backup enable" "vnstat backup service enabled"

# Adding and running TTL script
log_status "INFO" "Adding and running TTL script..."
if [ -f /root/indowrt.sh ]; then
    check_status "chmod +x /root/indowrt.sh && /root/indowrt.sh" "TTL script executed"
else
    log_status "WARNING" "indowrt.sh not found, skipping TTL configuration"
fi

# Adding port configuration
log_status "INFO" "Adding port configuration..."
if [ -f /root/addport.sh ]; then
    check_status "chmod +x /root/addport.sh && /root/addport.sh" "Port configuration script executed"
else
    log_status "WARNING" "addport.sh not found, skipping port configuration"
fi

# Checking for tunnel applications
log_status "INFO" "Checking for tunnel applications..."
for pkg in luci-app-openclash luci-app-nikki luci-app-passwall; do
    if opkg list-installed | grep -qw "$pkg"; then
        log_status "INFO" "$pkg detected"
        case "$pkg" in
            luci-app-openclash)
                check_status "chmod +x /etc/openclash/core/clash_meta" "OpenClash core permissions set"
                check_status "chmod +x /etc/openclash/Country.mmdb" "OpenClash Country.mmdb permissions set"
                check_status "chmod +x /etc/openclash/Geo* 2>/dev/null || true" "OpenClash Geo files permissions set"

                log_status "INFO" "Patching OpenClash overview..."
                if [ -f /usr/bin/patchoc.sh ]; then
                    check_status "bash /usr/bin/patchoc.sh" "OpenClash overview patched"
                    check_status "sed -i '/exit 0/i #/usr/bin/patchoc.sh' /etc/rc.local 2>/dev/null || true" "OpenClash patch added to rc.local"
                else
                    log_status "WARNING" "patchoc.sh not found"
                fi

                check_status "ln -sf /etc/openclash/history/Quenx.db /etc/openclash/cache.db" "OpenClash cache database symlink created"
                check_status "ln -sf /etc/openclash/core/clash_meta /etc/openclash/clash" "OpenClash binary symlink created"
                check_status "rm -f /etc/config/openclash" "Old OpenClash config removed"
                check_status "rm -rf /etc/openclash/custom /etc/openclash/game_rules" "OpenClash custom and game rules removed"
                check_status "rm -f /usr/share/openclash/openclash_version.sh" "OpenClash version script removed"
                check_status "find /etc/openclash/rule_provider -type f ! -name '*.yaml' -exec rm -f {} \;" "Non-YAML rule files removed"
                check_status "mv /etc/config/openclash1 /etc/config/openclash 2>/dev/null || true" "OpenClash configuration restored"
                ;;
            luci-app-nikki)
                check_status "rm -rf /etc/nikki/run/providers" "Nikki providers directory removed"
                check_status "chmod +x /etc/nikki/run/Geo* 2>/dev/null || true" "Nikki Geo files permissions set"
                log_status "INFO" "Creating symlinks from OpenClash to Nikki..."
                check_status "ln -sf /etc/openclash/proxy_provider /etc/nikki/run" "Nikki proxy provider symlink created"
                check_status "ln -sf /etc/openclash/rule_provider /etc/nikki/run" "Nikki rule provider symlink created"
                check_status "sed -i '64s/Enable/Disable/' /etc/config/alpha" "Alpha config updated for Nikki"
                check_status "sed -i '170s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header updated for Nikki"
                ;;
            luci-app-passwall)
                check_status "sed -i '88s/Enable/Disable/' /etc/config/alpha" "Alpha config updated for Passwall"
                check_status "sed -i '171s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header updated for Passwall"
                ;;
        esac
    else
        log_status "INFO" "$pkg not detected, cleaning up..."
        case "$pkg" in
            luci-app-openclash)
                check_status "rm -f /etc/config/openclash1" "OpenClash backup config removed"
                check_status "rm -rf /etc/openclash /usr/share/openclash /usr/lib/lua/luci/view/openclash" "OpenClash files and directories removed"
                check_status "sed -i '104s/Enable/Disable/' /etc/config/alpha" "Alpha config updated (OpenClash disabled)"
                check_status "sed -i '167s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header line 167 removed"
                check_status "sed -i '187s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header line 187 removed"
                check_status "sed -i '188s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header line 189 removed"
                ;;
            luci-app-nikki)
                check_status "rm -rf /etc/config/nikki /etc/nikki" "Nikki config and directories removed"
                check_status "sed -i '120s/Enable/Disable/' /etc/config/alpha" "Alpha config updated (Nikki disabled)"
                check_status "sed -i '168s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header line 168 removed"
                ;;
            luci-app-passwall)
                check_status "rm -f /etc/config/passwall" "Passwall config removed"
                check_status "sed -i '136s/Enable/Disable/' /etc/config/alpha" "Alpha config updated (Passwall disabled)"
                check_status "sed -i '169s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header line 169 removed"
                ;;
        esac
    fi
done

# Configuring uhttpd and PHP8
log_status "INFO" "Configuring uhttpd and PHP8..."

# uhttpd configuration
check_status "uci set uhttpd.main.ubus_prefix='/ubus'" "uhttpd ubus prefix set"
check_status "uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'" "uhttpd PHP interpreter configured"
check_status "uci set uhttpd.main.index_page='cgi-bin/luci'" "uhttpd index page set to LuCI"
check_status "uci add_list uhttpd.main.index_page='index.html'" "Added index.html to uhttpd index pages"
check_status "uci add_list uhttpd.main.index_page='index.php'" "Added index.php to uhttpd index pages"
check_status "uci commit uhttpd" "uhttpd configuration committed"

# PHP configuration
if [ -f "/etc/php.ini" ]; then
    cp /etc/php.ini /etc/php.ini.bak
    check_status "sed -i 's|^memory_limit = .*|memory_limit = 128M|g' /etc/php.ini" "PHP memory limit set to 128M"
    check_status "sed -i 's|^max_execution_time = .*|max_execution_time = 60|g' /etc/php.ini" "Max execution time set to 60 seconds"
    check_status "sed -i 's|^display_errors = .*|display_errors = Off|g' /etc/php.ini" "PHP display errors disabled"
    check_status "sed -i 's|^;*date\.timezone =.*|date.timezone = Asia/Jakarta|g' /etc/php.ini" "Timezone set to Asia/Jakarta"
    log_status "SUCCESS" "PHP settings configured"
else
    log_status "WARNING" "/etc/php.ini not found, skipping PHP configuration"
fi

if [ -d /usr/lib/php8 ] && [ ! -d /usr/lib/php ]; then
    check_status "ln -sf /usr/lib/php8 /usr/lib/php" "PHP8 library symlink created"
fi

check_status "/etc/init.d/uhttpd restart" "uhttpd service restarted"
log_status "SUCCESS" "uhttpd and PHP8 configuration completed"

log_status "SUCCESS" "All setup completed successfully"
check_status "rm -rf /etc/uci-defaults/$(basename $0)" "Cleanup: removed script from uci-defaults"

log_status "INFO" "========================================="
log_status "INFO" "XIDZs-WRT Setup Script Finished"
log_status "INFO" "Check log file: $LOG_FILE"
log_status "INFO" "========================================="

exit 0