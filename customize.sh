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

# Soft dependency: ims-voice-fix. SIP bridge observes cellular calls via
# TelephonyCallback; if the F50's IMS apk tears them down on screen-off,
# the bridge sees a 20-second blip instead of an actual call. Warn loudly
# but allow install — the user may have a different mitigation.
if [ ! -d /data/adb/modules/ims-voice-fix ] \
   && [ ! -d /data/adb/modules_update/ims-voice-fix ]; then
    ui_print "  ⚠ ims-voice-fix not installed."
    ui_print "    Cellular calls on this F50 SKU may drop after ~20 s"
    ui_print "    (screen-off → IMS handler → call teardown)."
    ui_print "    Install ims-voice-fix first if you want calls observed"
    ui_print "    by this SIP bridge to last beyond the screen timeout."
    ui_print "    /install_module ims-voice-fix  (status: under_development)"
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
