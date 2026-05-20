#!/system/bin/sh
# sip-server service — late_start. Supervises sipserver + dial_request
# watcher daemon. sipserver routes user→user SIP calls itself; user→
# real-phone-number INVITEs get translated into a file write at
# /data/local/tmp/callforward/dial_request which this watcher converts
# into an actual cellular call via `am start ACTION_CALL`.

DB=/data/sip-server
LOG="$DB/daemon.log"
DIAL_DIR=/data/local/tmp/callforward
DIAL_REQ="$DIAL_DIR/dial_request"
HANGUP_REQ="$DIAL_DIR/hangup_request"
mkdir -p "$DB" "$DIAL_DIR"

. /data/adb/modules/bin-utils/lib/common.sh

# Binary lives in two possible places — the Magisk overlay path is the
# release default; /data/sip-server/sipserver is the dev-rebuild target
# used when the overlay path was busy. Prefer the dev binary if present
# (so debug rebuilds win without touching the overlay).
if [ -x "$DB/sipserver" ]; then
    BIN="$DB/sipserver"
else
    BIN=/data/adb/modules/sip-server/system/bin/sipserver
fi
USERS=/data/sip-server/sip_users.conf
LISTEN=":5060"
REALM="callforward.local"

if [ ! -x "$BIN" ]; then
    log_line "FATAL: sipserver binary missing (neither $DB/sipserver nor module path)"
    exit 1
fi

# Warm-up: let network come up
sleep 20

# ─── sipserver supervisor ────────────────────────────────────────────────
(
    while true; do
        log_rotate 524288
        log_line "starting sipserver ($LISTEN, realm=$REALM, bin=$BIN)"
        "$BIN" "$LISTEN" "$REALM" "$USERS" >> "$LOG" 2>&1
        log_line "sipserver exited rc=$?, restarting in 10 s"
        sleep 10
    done
) &

# ─── dial_request watcher ────────────────────────────────────────────────
# sipserver writes `target|caller|timestamp` into $DIAL_REQ when a SIP
# INVITE targets a non-SIP-user (i.e. a real phone number) and the
# `server` slot is registered. We pick that up, fire ACTION_CALL via
# `am`, and remove the file so the next call works.
#
# `am start -a android.intent.action.CALL` requires CALL_PHONE
# permission; running as root via Magisk magisk shell context grants
# this implicitly. ACTION_CALL bypasses the dialer confirmation; the
# default dialer (whichever app holds the role) places the call.
(
    while true; do
        if [ -s "$DIAL_REQ" ]; then
            line=$(head -1 "$DIAL_REQ" 2>/dev/null)
            target=$(printf '%s' "$line" | cut -d'|' -f1 | tr -dc '+0-9')
            rm -f "$DIAL_REQ"
            if [ -n "$target" ]; then
                log_line "dial_request: tel:$target"
                am start -a android.intent.action.CALL -d "tel:$target" \
                    --user 0 >/dev/null 2>&1
            else
                log_line "dial_request: empty/invalid line, dropping"
            fi
        fi
        if [ -f "$HANGUP_REQ" ]; then
            rm -f "$HANGUP_REQ"
            log_line "hangup_request received"
            # Best-effort: send KEYCODE_ENDCALL. Works on most ROMs;
            # ZTE/Unisoc may need a vendor-specific path that we'd hook
            # via F50SipBridge's InCallService instead.
            input keyevent KEYCODE_ENDCALL 2>/dev/null
        fi
        sleep 1
    done
) &

# Block on the background jobs so this script (and its 'init' parent)
# stays alive — Magisk's late_start service launcher expects a
# foreground process to track for the module.
wait
