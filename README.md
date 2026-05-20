# sip-server — Embedded SIP Server (call/SMS bridge) for ZTE F50

A tiny static SIP server that runs on the F50 itself, so the on-device
`f50sip-app` and your companion phone/laptop can talk to each other:

```
            ┌──────────────────┐
            │   F50 (MiFi)     │
            │                  │
 SIP MESSAGE│  ┌────────────┐  │ REGISTER /
 ───────────┼──┤  sipserver ├──┼─────────────► companion
   :5060    │  │   :5060    │  │   (android, iphone, laptop)
            │  └─────┬──────┘  │
            │        │ UDP     │
            │  ┌─────┴──────┐  │
            │  │ f50sip-app │◄─┼─ SMS_DELIVER (Android role)
            │  │  (com.f50  │  │
            │  │   .sip)    ├──┼─► SmsManager.sendTextMessage()
            │  └────────────┘  │
            └──────────────────┘
```

## What it does

- Listens on **UDP/5060**.
- Maintains a username → contact registration table.
- `REGISTER`: MD5 Digest auth against `/data/sip-server/sip_users.conf`. Localhost (`127.0.0.1`) registrations skip auth — that's how `f50sip-app` lands as `server`.
- `MESSAGE`: forwards to a specific user, or `*` / `all` to everyone except the sender. This is the SMS-over-SIP path.
- `INVITE` / `ACK` / `CANCEL` / `BYE` / `OPTIONS`: standard call signaling. Calls to a phone-number target (not a registered user) are routed to `server` (the F50) via a `dial_request` file dropped at `/data/local/tmp/callforward/dial_request`.

## Files

| Path | Purpose |
|---|---|
| `system/bin/sipserver` | static aarch64 Go binary (~2.4 MB) |
| `/data/sip-server/sip_users.conf` | `username:password`, one per line |
| `/data/sip-server/daemon.log` | server log, rotates at 512 KB |

## Quick start

1. Install the module + reboot.
2. From any client: `REGISTER sip:android@<F50-LAN-IP>` with password from `sip_users.conf`.
3. Watch registrations land in `daemon.log` every 30 s.

## End-user manual (managed from Telegram via `statusbot`)

If you also have `statusbot` installed (recommended), you never have to
SSH in and edit `sip_users.conf` by hand. The bot exposes the full CRUD
surface plus a Linphone QR helper:

```
/sip                          status — sipserver PID, declared users,
                              active registrations, F50SipBridge state
/sip log                      last 20 lines of /data/sip-server/daemon.log
/sip users                    declared usernames

/sip register <u> <pw>        add a SIP account
                              rules: u ∈ [A-Za-z0-9_.-]{2,32}
                                     pw 6-64 chars, no ':' or whitespace
/sip remove   <u>             delete an account (the 'server' slot is
                              protected — it's where F50SipBridge lives)
/sip passwd   <u> <newpw>     change a password
/sip show     <u>             text settings block for any SIP client
/sip qr       <u>             one-shot Linphone XML provisioning QR
                              (5-minute TTL, served over busybox httpd
                              on a random port; inline keyboard picks
                              Local LAN vs Tailscale endpoint)
/sip restart                  kill sipserver; supervisor relaunches in 10 s
```

Each mutation reloads sipserver via `pkill`, so the supervisor in
`service.sh` relaunches with the new `sip_users.conf` within ~10 s.

### Manual setup on Linphone / Zoiper / MicroSIP / Acrobits

If the QR import path fails (Linphone 6.0+ sometimes rejects plain-HTTP
remote-provisioning URLs and returns "io error"), fall back to manual
entry. Open the client's "Add account" → **Use a SIP account**
(NOT "Linphone account") flow and fill:

```
Username:   <u>            from /sip users
Password:   <pw>           from /sip register or /sip passwd
SIP Domain: 192.168.0.1    when on the F50's own WiFi (br0)
            100.x.x.x      when on Tailscale  (get it from /tailscale ip)
Transport:  UDP
Port:       5060
Realm:      callforward.local      (most clients auto-detect)
```

Login. The client should switch to "Registered" / green within a few
seconds. Verify on the F50 side:

```
$ /sip
👥 Kayıtlı kullanıcılar:
  • server
  • android
  • iphone
  • laptop
  • macos
📡 Aktif kayıtlar:
  android -> 100.112.166.51:47589  (TTL: 3580s)
```

### Calling between SIP clients

User → user just works. From any registered client, dial
`sip:<other-user>@<F50-IP>` — sipserver forwards the INVITE to the other
registered endpoint and sets up the call.

### Calling a real GSM number (the +90... case)

This needs the **F50SipBridge Android app (`com.f50.sip`)** to be
registered to sipserver as the user named `server` — that registration
is what tells sipserver "anything that isn't a SIP user can be routed
to me, I'll place the real cellular call via the F50 modem".

When `server` isn't registered, an INVITE to e.g. `+905079068040`
returns `User not found` in the daemon log — there is no handler for
non-SIP-user destinations:

```
INVITE from android to +905079068040
User +905079068040 not registered and server not available
```

Fix: start the bridge service:

```bash
adb shell su -c "am start-foreground-service com.f50.sip/.SipForegroundService"
# or just reboot — BootReceiver brings it up
```

After that, `/sip` should show:

```
📡 Aktif kayıtlar:
  server  -> 127.0.0.1:5062 (TTL: 3589s)
  android -> 100.112.166.51:47589 (TTL: 3580s)
```

Note: the cellular leg itself is gated by the F50's own modem state.
This pair of modules handles **signaling**; the actual GSM call quality
(and survival across screen-off — see `ims-voice-fix`) is a separate
problem layer.

## Networking gotcha — Tailscale + tun0 coexistence

If your F50 also runs a tun0-owning VPN client (Clash / sing-box /
openclash via the `vpn-gateway` module), the default behaviour without
care is for replies from sipserver to Tailscale peers to leak into the
VPN tunnel — REGISTERs arrive but 401 challenges never reach the
client, and Linphone ends up retrying forever without an Authorization
header (looks exactly like a broken password).

The fix lives in the `vpn-gateway` (F50 fork) module's `service.sh`:

```sh
ip rule add to 100.64.0.0/10 lookup main pref 9990
ip route add 100.64.0.0/10 dev tailscale0 src <ts-ip> metric 50
```

Install `vpn-gateway` (the f50 fork) **before** `sip-server` if you
need Tailscale-side SIP to work.

## Hardening checklist

- `sip_users.conf` is `chmod 600`. Change passwords on first install.
- If you expose 5060/udp to the internet (don't), add a firewall rule that drops everything except known peer IPs.
- The realm string (`callforward.local`) is what shows up in `WWW-Authenticate` challenges — clients see it; it does not need to resolve.

## Dependencies

- `bin-utils` v1.3.0+ (for `lib/common.sh`).

## Companion module

`f50sip-app` (`com.f50.sip`) is the on-device Android app that holds the
default-SMS role and proxies SMS ⇄ SIP MESSAGE. It registers as
`server` via `127.0.0.1:5060` (auth bypassed) — see `f50sip.conf`.
