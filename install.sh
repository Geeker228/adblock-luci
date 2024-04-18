#!/bin/sh

FILTERING_PACKAGE="adblock"
UPDATE_SCRIPT="/usr/bin/adblock-update.sh"
AUTO_UPDATE_SCRIPT="/usr/bin/adblock-auto-update.sh"

if [ ! -d "/usr/local" ]; then
    mkdir -p /usr/local/bin
fi

LUA_PACKAGES="lua luci-lib-jsonc"

is_lua_package_installed() {
    local package=$1
    if opkg list-installed | grep -q "^${package}$"; then
        return 0
    else
        return 1
    fi
}

install_lua_packages() {
    for package in $LUA_PACKAGES; do
        if ! is_lua_package_installed "$package"; then
            echo "Installing ${package}..."
            opkg update
            opkg install "${package}"
        else
            echo "${package} is already installed."
        fi
    done
}

install_package() {
 if ! opkg list-installed | grep -q "^${FILTERING_PACKAGE}$"; then
    opkg update
    opkg install "${FILTERING_PACKAGE}"
 fi
}

enable_service() {
 if ! /etc/init.d/"${FILTERING_PACKAGE}" enabled; then
    /etc/init.d/"${FILTERING_PACKAGE}" enable 
 fi
}

configure_package() {
 uci set "${FILTERING_PACKAGE}".config.auto_update=0
 uci set "${FILTERING_PACKAGE}".config.block_malware=0
 uci set "${FILTERING_PACKAGE}".config.block_iploggers=0
 uci set "${FILTERING_PACKAGE}".config.enable_adblock=0
 uci commit "${FILTERING_PACKAGE}"
}

create_update_script() {
 cat > "${UPDATE_SCRIPT}" << EOF
#!/bin/sh
URL="https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/Filters/filter.txt"
MALWARE_URLS="https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareAdGuardHome.txt https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/master/filters/ThirdParty/filter_255_Phishing_URL_Blocklist/filter.txt https://raw.githubusercontent.com/AdguardTeam/FiltersRegistry/master/filters/ThirdParty/filter_256_Scam_Blocklist/filter.txt"
IPLOGGER_URL="https://raw.githubusercontent.com/Konnor88/anti-grabify/master/url_list.txt"
FILE="/etc/adblock/adblock.conf"
. /etc/uci-defaults/40-adblock
update_filter() {
 if [ "\$(uci get ${FILTERING_PACKAGE}.config.auto_update)" = "1" ]; then
    wget -O /tmp/filter.txt "\$URL"
    sed -i '/^!/d' "\$FILE"
    cat /tmp/filter.txt >> "\$FILE"
    if [ "\$(uci get ${FILTERING_PACKAGE}.config.block_malware)" = "1" ]; then
      for url in \$MALWARE_URLS; do
        wget -O - "\$url" >> "\$FILE"
      done
    fi
    if [ "\$(uci get ${FILTERING_PACKAGE}.config.block_iploggers)" = "1" ]; then
      wget -O - "\$IPLOGGER_URL" >> "\$FILE"
    fi
 fi
}
restart_service() {
 /etc/init.d/${FILTERING_PACKAGE} restart
}
update_filter
restart_service
EOF
 chmod +x "${UPDATE_SCRIPT}"
}

create_auto_update_script() {
 if ! /etc/init.d/cron enabled; then
    /etc/init.d/cron enable
    /etc/init.d/cron start
 fi

 cat > "${AUTO_UPDATE_SCRIPT}" << EOF
#!/bin/sh
if [ "\$(uci get ${FILTERING_PACKAGE}.config.auto_update)" = "1" ]; then
    (crontab -l 2>/dev/null; echo "0 0 */5 * * /usr/bin/adblock-update.sh") | crontab -
else
    (crontab -l | grep -v '/usr/bin/adblock-update.sh' || true) | crontab -
fi
EOF
 chmod +x "${AUTO_UPDATE_SCRIPT}"
}

create_luci_interface() {
 cat > "/usr/lib/lua/luci/controller/network_filtering.lua" << EOF
module("luci.controller.network_filtering", package.seeall)
function index()
 entry({"admin", "network", "network_filtering"}, cbi("network_filtering"), _("Network filtering"))  
end
EOF

 cat > "/usr/lib/lua/luci/view/network_filtering/cbi.lua" << EOF
require "luci.util"
m = Map("adblock", translate("Network filtering"))
s = m:section(TypedSection, "adblock")
s.anonymous = true
btn = s:option(Button, "update", translate("Update"))
btn.inputtitle = translate("Update")
btn.inputstyle = "apply"
btn.write = function()
 luci.sys.call("/usr/bin/adblock-update.sh")
 luci.http.redirect(luci.dispatcher.build_url("admin", "network", "network_filtering"))
end
auto_update = s:option(Flag, "auto_update", translate("Auto Update"))
auto_update.default = 0
block_malware = s:option(Flag, "block_malware", translate("Block Malicious Websites"))
block_malware.default = 0
block_iploggers = s:option(Flag, "block_iploggers", translate("Block IP Loggers"))
block_iploggers.default = 0
enable_adblock = s:option(Flag, "enable_adblock", translate("Enable AdBlocking"))
enable_adblock.default = 0
return m
EOF
}

install_lua_packages
install_package
enable_service  
configure_package
create_update_script
create_auto_update_script

/etc/init.d/luci-module load network_filtering
/etc/init.d/luci-mod-admin restart

echo "Installation complete. Please configure the Network filtering settings through the LuCI web interface."
echo "This script is one-time use for installation. Manual updates can be performed through the GUI."

rm -- "$0"

exit 0
