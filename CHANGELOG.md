# Changelog

All notable user-visible changes to the Docmost TOS application package.

## 0.90.0-5 — 2026-11-22

Remediation of the App Center review findings (x86_64 on-hold
`C10 C3 C4 C5 C9` plus the blocking `F1`; aarch64 conditional
`C10 C3 C4 C5 C7 C9 T1` plus `F5`). Both architectures are rebuilt and
resubmitted together.

### Privacy and compliance

- **C3 / C4 / C5 / C7 / C8** — added `PRIVACY.md`: what is stored (pages,
  history, comments, attachments, accounts, bcrypt hashes, sessions, IP/user
  agent, invitations, shares, audit, optional AI chats), the exact PostgreSQL /
  Redis / storage paths, WebSocket collaboration traffic, retention (30-day
  trash, 90-day sessions), user rights (access, correction, erasure,
  portability, objection), security measures, the full third-party endpoint
  table and the deletion channel.
- `config.ini.help` and `tosapp.json.help` now point to the public policy:
  <https://github.com/Moechz/docmost/blob/main/PRIVACY.md> (C5).
- **Telemetry disabled** with `DISABLE_TELEMETRY=true`. Upstream's daily
  `tel.docmost.com` telemetry job no longer runs; this is documented in
  `PRIVACY.md` together with what it would have sent (C4/C6/C8).
- **C2** — added `NOTICE.md` with the real upstream license (AGPL-3.0), image
  tags/digests, PostgreSQL/Redis licenses, trademark attribution and the
  non-affiliation statement.

### Descriptions and repository

- **C9 / F5** — rewrote the English description and the `zh-cn` / `zh-hk`
  translations. They previously described a habit tracker
  (beaverhabits) with streak statistics. All 23 language sections now describe
  the delivered Docmost features (spaces, nested pages, real-time co-editing,
  comments, permissions, attachments, full-text search, history, sharing).
- **C10** — rewrote `README.md` with features, three-service architecture,
  repository layout, first-run instructions, data/backup/uninstall, privacy,
  notices, build, verification, upgrade notes and limitations. Added
  `docs/OPERATIONS.md` (install/upgrade/backup/restore/uninstall/
  troubleshooting/security). The repository is public and the layout matches
  the actual files.
- Removed the stale `probe` block copied from beaverhabits (`daya0576`,
  `start.sh prd`, port 8080) and the stale `entrypoint_file` path; `probe` now
  records the real Docmost image, digest, entrypoint, command and verification.

### Runtime / installation (F1)

- Every service keeps `user: "1000:1000"`; `shm_size: "256mb"` added to
  PostgreSQL for stable shared-memory use.
- App healthcheck now probes the application health endpoint
  `GET /api/health` (database + Redis) instead of `/`, with a **180 s**
  `start_period` and 10 retries; PostgreSQL has a 120 s start period. This
  prevents a slow first-run migration from being reported as a failed install.
- Images pinned to immutable patch releases: `postgres:16.16-alpine`,
  `redis:8.10.3-alpine`; Docmost remains `docmost/docmost:0.90.0`.
- Redis runs with `--appendonly yes` and `--maxmemory-policy noeviction`
  (upstream default), so queued work and WebSocket pub/sub survive a restart.
- The entrypoint validates that `/app/data/storage` is writable and prints a
  clear `FATAL` message with the required `chown` if it is not, writes the
  secret atomically, enforces mode `0600` and rejects a truncated
  `.app_secret` instead of booting with an invalid secret.
- **Port 8087 unchanged** — port collisions are not treated as a package
  defect (repository RUNBOOK §12).

### T1 / CVE

- Docmost `0.90.0` is the current upstream release (image built 2026-05-21)
  and is kept. PostgreSQL `16.16` and Redis `8.10.3` are the current patch
  releases (2026-11-18 / 2026-11-05) and replace the floating `16-alpine` /
  `7-alpine` tags.
- Residual CVEs in Docmost's bundled Node.js 22.22.3/application dependencies
  require an upstream rebuild; this is stated in `NOTICE.md`, `PRIVACY.md` and
  `README.md`, together with the compensating controls (non-root, no
  privileged/host networking, private database/cache, no internet exposure
  without TLS).

### Verified

- `bash scripts/build-dual.sh 0.90.0-5` — verify OK for both architectures;
  official `TOSAppSelfTestingTool -c` prints `check passed` for both packages.
- `python3 stage.py work/docmost --timeout 300` — 3 containers running/healthy,
  HTTP 200, all three `user=1000:1000`, `passed 5, failed 0`.
- First-run setup (`POST /api/auth/setup`) and login
  (`POST /api/auth/login`) return 200; `/api/health` reports database and Redis
  up.

## 0.90.0-4 — 2026-11-15

### Changed

- Package-only rebuild submitted for review; no user-visible code change.
  The version was published for aarch64 and put on hold for x86_64 because of
  the review findings fixed in 0.90.0-5.

## 0.90.0-3 — 2026-11-12

### Changed

- Icon: replaced the letter monogram with a functional vector mark that
  describes what the app does (the upstream project does not publish a
  compliant SVG).

## 0.90.0-2 — 2026-11-12

### Changed

- Icon: replaced the letter monogram with a functional vector mark that
  describes what the app does (the upstream project does not publish a
  compliant SVG).

## 0.90.0-1 — 2026-11-11

### Added

- First release. Docmost (`docmost/docmost:0.90.0`, Docker Hub official image,
  unmodified) packaged as a TOS 7 Docker application, published on port 8087
  and running as a non-root user (1000:1000).
- Persistent data is kept under `/Volume1/DockerAppData/docmostdocker/`.
