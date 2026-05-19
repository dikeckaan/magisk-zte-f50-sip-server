#!/system/bin/sh
ui_print " "
ui_print "  Embedded SIP Server v1.0.0"
ui_print "  =========================="
ui_print " "
ui_print "  Static UDP/5060 SIP server (~2.4 MB) for F50SipBridge."
ui_print "  Users live in /data/sip-server/sip_users.conf."
ui_print " "

if [ ! -r /data/adb/modules/bin-utils/lib/common.sh ] \
   && [ ! -r /data/adb/modules_update/bin-utils/lib/common.sh ]; then
    abort "  ❌ bin-utils v1.3.0+ required (lib/common.sh missing)."
fi

mkdir -p /data/sip-server
chmod 755 /data/sip-server

if [ ! -f /data/sip-server/sip_users.conf ]; then
    ui_print "  Seeding default /data/sip-server/sip_users.conf"
    cat > /data/sip-server/sip_users.conf <<'EOF'
# username:password — one per line. Used for non-localhost REGISTER auth.
# F50SipBridge (running on this device) registers from 127.0.0.1
# and bypasses auth, but it still needs a username slot to land in:
server:cf_server_2026
# Companion devices (phone, laptop). Change these passwords!
android:android123
iphone:iphone123
laptop:laptop123
EOF
    chmod 600 /data/sip-server/sip_users.conf
    ui_print " "
    ui_print "  ⚠️ EDIT /data/sip-server/sip_users.conf to change passwords."
else
    ui_print "  Keeping existing /data/sip-server/sip_users.conf"
fi

set_perm "$MODPATH/service.sh"            0 0 0755
set_perm "$MODPATH/system/bin/sipserver"  0 0 0755

ui_print "  [OK] Installed. Reboot to start the SIP server on UDP/5060."
ui_print " "
