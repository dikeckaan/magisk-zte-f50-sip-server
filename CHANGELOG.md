# Changelog

## v0.1.0-dev — 2026-05-20 (UNDER DEVELOPMENT)

- First exploratory release. End-to-end cellular-call observation through
  this bridge **not yet verified**; you can register clients and forward
  SMS, but cellular calls picked up by `f50sip-app`'s TelephonyCallback
  watcher have not been time-tested across screen-off.
- Bundles statically-linked `sipserver-arm64` Go binary (~2.4 MB).
- UDP/5060 listener; MD5 Digest auth for non-localhost REGISTER.
- Default users file at `/data/sip-server/sip_users.conf` (server, android, iphone, laptop).
- Supervised by `service.sh` with crash-restart + 512 KB log rotate.
- Designed to pair with the `com.f50.sip` F50SipBridge Android app.
- **Soft dep on `ims-voice-fix`** — without it, calls observed by the
  bridge are torn down at the F50's screen-off timeout (~20 s). The
  installer warns if `ims-voice-fix` isn't present but does not abort.
