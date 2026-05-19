# Changelog

## v1.0.0 — 2026-05-19

- First release. Bundles statically-linked `sipserver-arm64` Go binary (~2.4 MB).
- UDP/5060 listener; MD5 Digest auth for non-localhost REGISTER.
- Default users file at `/data/sip-server/sip_users.conf` (server, android, iphone, laptop).
- Supervised by `service.sh` with crash-restart + 512 KB log rotate.
- Designed to pair with `f50sip-app` (com.f50.sip) on the same device.
