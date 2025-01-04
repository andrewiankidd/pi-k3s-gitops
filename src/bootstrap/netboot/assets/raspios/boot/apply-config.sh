#!/bin/bash
set -e

##############################
#         functions          #
##############################

print_string() {
    local INPUT_STRING="$1"  # Get the first parameter passed to the function
    echo "[apply-config] $INPUT_STRING"
}

#############################
# environment vars / params #
#############################

CONFIG_FILE=${CONFIG_FILE:="/boot/.config"}

##############################
#        script body         #
##############################

# check for config file
if [ -e "$CONFIG_FILE" ]; then
    print_string "!Parsing config file: $CONFIG_FILE"
    set -o allexport
    source $CONFIG_FILE
    printenv
    set +o allexport
elif [ -e "$CONFIG_FILE.example" ]; then
    print_string "!Parsing example config file: $CONFIG_FILE.example"
    set -o allexport
    source "$CONFIG_FILE.example"
    printenv
    set +o allexport
else
    print_string "Config file does not exist: $CONFIG_FILE"
    print_string "Starting system as normal..."
    sleep 10
    exec /sbin/init
    exit 0
fi

# configure hostname
if [ -n "$CONFIG_HOSTNAME" ]; then
    print_string "Actioning CONFIG_HOSTNAME"
    CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
    if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
        /usr/lib/raspberrypi-sys-mods/imager_custom set_hostname $CONFIG_HOSTNAME
    else
        print_string $CONFIG_HOSTNAME >/etc/hostname
        sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$CONFIG_HOSTNAME/g" /etc/hosts
    fi
else
    print_string "CONFIG_HOSTNAME not set, skipping"
fi

# configure credentials
if [ -n "$CONFIG_USER_USERNAME" ] && [ -n "$CONFIG_USER_PASSWORD" ]; then
    print_string "Actioning CONFIG_USER_USERNAME"
    CONFIG_USER_PASSWORD=$(echo $CONFIG_USER_PASSWORD | openssl passwd -6 -stdin)
    if [ -f /usr/lib/userconf-pi/userconf ]; then
        print_string "Calling userconf..."
        /usr/lib/userconf-pi/userconf $CONFIG_USER_USERNAME $CONFIG_USER_PASSWORD
    else
        print_string "Calling usermod..."
        FIRSTUSER=`getent passwd 1000 | cut -d: -f1`
        echo "$FIRSTUSER:$CONFIG_USER_PASSWORD" | chpasswd -e
        if [ "$FIRSTUSER" != "$CONFIG_USER_USERNAME" ]; then
            usermod -l "$CONFIG_USER_USERNAME" "$FIRSTUSER"
            usermod -m -d "/home/$CONFIG_USER_USERNAME" "$CONFIG_USER_USERNAME"
            groupmod -n "$CONFIG_USER_USERNAME" "$FIRSTUSER"
            if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf ; then
                sed /etc/lightdm/lightdm.conf -i -e "s/^autologin-user=.*/autologin-user=$CONFIG_USER_USERNAME/"
            fi
            if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
                sed /etc/systemd/system/getty@tty1.service.d/autologin.conf -i -e "s/$FIRSTUSER/$CONFIG_USER_USERNAME/"
            fi
            if [ -f /etc/sudoers.d/010_pi-nopasswd ]; then
                sed -i "s/^$FIRSTUSER /$CONFIG_USER_USERNAME /" /etc/sudoers.d/010_pi-nopasswd
            fi
        fi
    fi
else
    print_string "CONFIG_USER_USERNAME, CONFIG_USER_PASSWORD not set, skipping"
fi

# configure SSH
if [ -n "$CONFIG_SSH_ENABLED" ]; then
    print_string "Actioning CONFIG_SSH_ENABLED"
    if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
        /usr/lib/raspberrypi-sys-mods/imager_custom enable_ssh
    else
        systemctl enable ssh
    fi
else
    print_string "CONFIG_SSH_ENABLED not set, skipping"
fi

# configure WiFi
if [ -n "$CONFIG_WIFI_SSID" ]; then
    print_string "Actioning CONFIG_WIFI_SSID"

    if [ -n "$CONFIG_WIFI_SSID" ]; then
        CONFIG_WIFI_PASS=$(echo -n "$CONFIG_WIFI_PASS" | sha256sum | cut -d ' ' -f 1)
    fi

    if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
        /usr/lib/raspberrypi-sys-mods/imager_custom set_wlan '$CONFIG_WIFI_SSID' '$CONFIG_WIFI_PASS' '$CONFIG_LOCALE_KEYMAP'
    else
cat >/etc/wpa_supplicant/wpa_supplicant.conf <<'WPAEOF'
country=$CONFIG_LOCALE_KEYMAP
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
ap_scan=1

update_config=1
network={
	ssid="$CONFIG_WIFI_SSID"
	psk=$CONFIG_WIFI_PASS
}

WPAEOF
        chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
        rfkill unblock wifi
        for filename in /var/lib/systemd/rfkill/*:wlan ; do
            echo 0 > $filename
        done
    fi
else
    print_string "CONFIG_WIFI_SSID not set, skipping"
fi

# configure locale
# if [ -n "$CONFIG_LOCALE_KEYMAP" ] && [ -n "$CONFIG_LOCALE_TIMEZONE" ]; then
#     print_string "Actioning CONFIG_LOCALE_KEYMAP"

#     if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
#         /usr/lib/raspberrypi-sys-mods/imager_custom set_keymap '$CONFIG_LOCALE_KEYMAP'
#         /usr/lib/raspberrypi-sys-mods/imager_custom set_timezone '$CONFIG_LOCALE_TIMEZONE'
#     else
#         rm -f /etc/localtime
#         echo "$CONFIG_LOCALE_TIMEZONE" >/etc/timezone
#         dpkg-reconfigure -f noninteractive tzdata
# cat >/etc/default/keyboard <<'KBEOF'
# XKBMODEL="pc105"
# XKBLAYOUT="$CONFIG_LOCALE_KEYMAP"
# XKBVARIANT=""
# XKBOPTIONS=""

# KBEOF
#         dpkg-reconfigure -f noninteractive keyboard-configuration
#     fi
# else
#     print_string "CONFIG_LOCALE_KEYMAP, CONFIG_LOCALE_TIMEZONE not set, skipping"
# fi

# clean up
print_string "Removing: $CONFIG_FILE"
rm -f $CONFIG_FILE
rm -f "$CONFIG_FILE.example"

# reboot
print_string "Done! Starting System..."
sleep 10
exec /sbin/init
exit 0
