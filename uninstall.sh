#!/bin/sh

FILTERING_PACKAGE="adblock"
UPDATE_SCRIPT="/usr/bin/adblock-update.sh" # Changed to /usr/bin
AUTO_UPDATE_SCRIPT="/usr/bin/adblock-auto-update.sh" # Changed to /usr/bin

uninstall_package() {
 if opkg list-installed | grep -q "^${FILTERING_PACKAGE}$"; then
    opkg remove "${FILTERING_PACKAGE}"
 fi
}

disable_service() {
 if /etc/init.d/"${FILTERING_PACKAGE}" enabled; then
    /etc/init.d/"${FILTERING_PACKAGE}" disable 
 fi
}

remove_update_script() {
 if [ -f "${UPDATE_SCRIPT}" ]; then
    rm "${UPDATE_SCRIPT}"
 fi
}

remove_auto_update_script() {
 if [ -f "${AUTO_UPDATE_SCRIPT}" ]; then
    rm "${AUTO_UPDATE_SCRIPT}"
 fi
}

remove_luci_interface() {
 rm -f "/usr/lib/lua/luci/controller/network_filtering.lua"
 rm -f "/usr/lib/lua/luci/view/network_filtering/cbi.lua"
}

remove_cron_jobs() {
 crontab -l | grep -v '/usr/bin/adblock-update.sh' | crontab -
}

remove_unused_dependencies() {
 opkg autoremove
}

echo "Starting Network Filtering uninstallation..."

uninstall_package
disable_service
remove_update_script
remove_auto_update_script
remove_luci_interface
remove_cron_jobs
remove_unused_dependencies # Added step to remove unused dependencies

echo "Uninstallation complete. Network Filtering has been removed."

rm -- "$0"

exit 0
