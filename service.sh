#!/system/bin/sh
# sip-server service — late_start. Supervises sipserver on UDP/5060.

DB=/data/sip-server
LOG="$DB/daemon.log"
mkdir -p "$DB"

. /data/adb/modules/bin-utils/lib/common.sh

BIN=/data/adb/modules/sip-server/system/bin/sipserver
USERS=/data/sip-server/sip_users.conf
LISTEN=":5060"
REALM="callforward.local"

if [ ! -x "$BIN" ]; then
    log_line "FATAL: sipserver binary missing at $BIN"
    exit 1
fi

# Warm-up: let network come up
sleep 20

(
    while true; do
        log_rotate 524288
        log_line "starting sipserver ($LISTEN, realm=$REALM)"
        "$BIN" "$LISTEN" "$REALM" "$USERS" >> "$LOG" 2>&1
        log_line "sipserver exited rc=$?, restarting in 10 s"
        sleep 10
    done
) &
