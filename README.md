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

## Companion config

For a typical Linphone / MicroSIP / Acrobits setup:

```
Username:    android
Password:    android123          # change in sip_users.conf!
Domain:      192.168.0.1          # or your Tailscale IP of the F50
Transport:   UDP
Port:        5060
```

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
