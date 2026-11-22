# docmost-for-tos

> TerraMaster TOS 7 App Center — Docker application package for
> [Docmost](https://github.com/docmost/docmost) 0.90.0.

[![upstream](https://img.shields.io/badge/upstream-docmost%2Fdocmost-181717?logo=github)](https://github.com/docmost/docmost)
[![license](https://img.shields.io/badge/upstream%20license-AGPL--3.0-blue)](https://github.com/docmost/docmost/blob/main/LICENSE)

## What this is

A TOS 7 Docker application package (`docmostdocker.tar.gz`) that installs a
complete, self-hosted Docmost wiki on a TerraMaster NAS through App Center:

- **Docmost 0.90.0** — spaces, nested pages, real-time co-editing, comments,
  page permissions, attachments, full-text search, version history and public
  sharing;
- **PostgreSQL 16.16** — the system of record (pages, history, accounts,
  sessions, permissions);
- **Redis 8.10.3** — cache, background queues, rate limits and WebSocket
  pub/sub.

Only Docmost is reachable from the LAN (port **8087** → container port 3000).
The database and cache are private Compose services. Everything runs as the
unprivileged user `1000:1000`.

| | |
|---|---|
| App ID | `docmostdocker` |
| Version | `0.90.0-5` |
| Architectures | `x86_64`, `aarch64` |
| Upstream image | `docmost/docmost:0.90.0` (Docker Hub, unmodified) |
| Open | `http://<NAS-IP>:8087/` |
| Runs as | non-root, `user: "1000:1000"` on all three services |
| Host port | `8087` (not changed during this remediation — port collisions are not defects) |
| Data | `/Volume1/DockerAppData/docmostdocker/` |
| Help / privacy | <https://github.com/Moechz/docmost/blob/main/PRIVACY.md> |

## How it works

```
browser ──HTTP/WebSocket :8087──► docmostdocker (Node 22, uid 1000)
                                      │ private Compose network
                                      ├── docmostdocker-db    postgres:16.16-alpine (uid 1000)
                                      └── docmostdocker-redis redis:8.10.3-alpine   (uid 1000)
```

- **Non-root.** Every service pins `user: "1000:1000"`; there is no
  `privileged`, `network_mode: host`, Docker socket, `cap_add` or host device.
- **One published port.** PostgreSQL and Redis are not published; only the app
  is reachable from the LAN.
- **Healthchecks on every service.** The app checks `GET /api/health` (returns
  `{"status":"ok","info":{"database":{"status":"up"},"redis":{"status":"up"}}}`);
  PostgreSQL uses `pg_isready`; Redis uses `redis-cli ping`.
- **First-start grace.** The app healthcheck has a 180 s `start_period`
  (10 retries × 30 s) and PostgreSQL 120 s, so first-run database migrations on
  a slow NAS do not mark a healthy install as failed.
- **Generated secret.** The wrapper writes a 96-hex-character `APP_SECRET` to
  `/app/data/storage/.app_secret` (mode `0600`) on first start and reuses it
  across restarts and upgrades. It is never shipped in the package or written
  to Compose/logs.
- **Telemetry off.** `DISABLE_TELEMETRY=true` is set explicitly. Upstream's
  daily `tel.docmost.com` telemetry job does not run. See `PRIVACY.md`.
- **Pinned images.** Docmost `0.90.0`, PostgreSQL `16.16-alpine`, Redis
  `8.10.3-alpine`; no `:latest`.
- **Cache persistence.** Redis runs with `--appendonly yes`; cache/queues
  survive a restart, while PostgreSQL remains the source of truth.

## Repository layout

```text
docmost/
├── PRIVACY.md                   # full privacy policy (C3/C4/C5/C7/C8)
├── NOTICE.md                    # licenses, image digests, trademarks (C2)
├── CHANGELOG.md                 # per-version remediation notes
├── LICENSE                      # MIT for this packaging + third-party notice
├── README.md                    # this file
├── docs/
│   └── OPERATIONS.md            # install / upgrade / backup / uninstall / troubleshooting
├── src/
│   ├── config.ini               # TOS metadata (id, version, port, help URL)
│   ├── docmostdocker.lang       # 23-language descriptions (C9)
│   ├── docmostdocker.svg        # icon
│   ├── docker-compose.yml       # three services, healthchecks, volumes
│   └── entrypoint.sh            # generates APP_SECRET, then starts Docmost
├── scripts/
│   ├── build.sh                 # builds one architecture, runs tools/verify.py
│   └── build-dual.sh            # builds aarch64 + x86_64 and runs the official -c
├── tools/
│   └── verify.py                # review-standards self-check (hard gate)
├── test/
│   ├── install-and-verify.sh    # on-device install test (official tool -i; admin)
│   └── compose-resolved/        # last staged Compose file (build artefact)
├── TOSAppSelfTestingTool        # official TerraMaster checker
└── out/                         # built assets (git-ignored)
```

The archive itself contains exactly the four files TOS expects:
`config.ini`, `docmostdocker.lang`, `docmostdocker.svg`,
`docker-compose.yml`.

## Install and first run

1. Install **DockerEngine** from App Center if it is not already installed.
2. Install **Docmost** from App Center (or install the package with the
   official `TOSAppSelfTestingTool -i` on a test NAS).
3. Open `http://<NAS-IP>:8087/` and complete the first-run wizard:
   workspace name, administrator name, e-mail and password.
4. Create a space and a page. Invite users from the workspace member screen.

No account, licence key or registration with the packager is required.
Docmost is ready to use offline; only image pulls need Docker Hub (or your
configured registry mirror).

> App Center's manual install page accepts `.deb` packages only. To test a
> Docker package on a NAS, use the official tool's `-i` mode or
> `docker compose`. See `docs/OPERATIONS.md`.

## Data and uninstall

All persistent data is below one directory:

| Host path | Container path | Contents |
|---|---|---|
| `/Volume1/DockerAppData/docmostdocker/storage` | `/app/data/storage` | Attachments, images, avatars, covers, `.app_secret` |
| `/Volume1/DockerAppData/docmostdocker/db` | `/var/lib/postgresql/data` | PostgreSQL cluster (`PGDATA=db/pgdata`): pages, history, comments, users, sessions, invitations, permissions, shares |
| `/Volume1/DockerAppData/docmostdocker/redis` | `/data` | Redis AOF: cache, queues, rate limits, WebSocket pub/sub |

**Backup** (containers stopped for a consistent copy):

```bash
docker compose -p docmostdocker stop
sudo tar -C /Volume1/DockerAppData -czf docmost-backup-$(date +%F).tar.gz docmostdocker
docker compose -p docmostdocker start
```

For a logical database backup while running:

```bash
docker exec docmostdocker-db pg_dump -U docmost -d docmost -Fc > docmost-$(date +%F).dump
```

**Uninstall and keep data:** uninstall the app in App Center (or
`docker compose -p docmostdocker down`). The data directory is left in place;
reinstalling the same version reuses the workspace.

**Uninstall and delete everything:**

```bash
docker compose -p docmostdocker down -v
rm -rf /Volume1/DockerAppData/docmostdocker
```

This permanently removes pages, history, attachments, accounts, sessions and
the cache. There is no packager-side copy. See `PRIVACY.md` §6 and
`docs/OPERATIONS.md` for the full deletion channel.

## Privacy

The full policy is in **[PRIVACY.md](PRIVACY.md)** and is also the package's
`help` link (`config.ini` → `help`). It covers:

- every stored data type: pages, history, comments, attachments, accounts,
  bcrypt password hashes, sessions with IP/user-agent, invitations, shares,
  audit, optional AI chats;
- the exact host paths and the PostgreSQL/Redis/storage split;
- WebSocket collaboration traffic and what is persisted;
- search (PostgreSQL full-text; optional Typesense, **no Meilisearch**),
  local storage (optional S3/Azure), optional AI/mail/PDF/Draw.io services;
- every outbound endpoint and whether it is on by default;
- retention (default 30-day trash, 90-day sessions), user rights, security
  measures and the deletion channel;
- the fact that **telemetry is disabled** in this package and no data goes to
  the packager.

## Notices

See **[NOTICE.md](NOTICE.md)** for the upstream AGPL-3.0 license, the exact
image tags and digests, PostgreSQL/Redis licenses, Alpine components, the
TerraMaster self-testing tool terms, trademarks and the non-affiliation
statement. The packaging itself is MIT licensed (`LICENSE`).

## Build

Requirements: Python 3, `tar`/`gzip`, and the bundled
`TOSAppSelfTestingTool` executable for the official check. No network access is
needed for the build itself.

```bash
# both architectures, self-check + official -c
bash scripts/build-dual.sh 0.90.0-5

# one architecture
bash scripts/build.sh 0.90.0-5 x86_64
bash scripts/build.sh 0.90.0-5 aarch64
```

The build:

1. stamps `version`/`platform` into `tosapp.json` and `config.ini`;
2. embeds `src/entrypoint.sh` into the Compose `command` block scalar, escaping
   every `$` as `$$`;
3. removes CRLF/BOM/AppleDouble files;
4. runs `tools/verify.py` (archive layout, JSON, 23 languages, version
   consistency, Docker-Hub-only images, fixed tags, non-root user on every
   service, per-service healthcheck/TZ/restart, data paths below the app data
   root, no `/Volume*` wildcard, no comments in sequence blocks, no literal
   secrets, unescaped `$` and `x-app-meta` position);
5. runs `TOSAppSelfTestingTool -c` on both packages;
6. writes `out/docmostdocker_x86_64.tar.gz`, `out/docmostdocker_aarch64.tar.gz`
   and their `.sha256` files.

## Verification

| Gate | Result (2026-11-22) |
|---|---|
| `bash scripts/build-dual.sh 0.90.0-5` | verify OK for both arches; official `-c` prints `check passed` for both |
| `python3 stage.py work/docmost --timeout 300` | `passed 5, failed 0` (3 containers running/healthy, HTTP 200, all three uid 1000) |
| First-run setup (`POST /api/auth/setup`) | 200; workspace + admin account created |
| Login (`POST /api/auth/login`) | 200 |
| `GET /api/health` | 200, `database: up`, `redis: up` |
| Telemetry | `DISABLE_TELEMETRY=true`; no request to `tel.docmost.com` |

`stage.py` is the isolated runtime check used here instead of `tosdocker e2e`
(which deletes `/Volume1/DockerAppData/<appid>`): it rewrites ports to
`127.0.0.1:<random>`, moves volumes to a staging directory, removes
`container_name`, starts the stack with Docker Compose, asserts
running/healthy/HTTP/non-root and then removes everything. It never touches
production data or the production port.

> aarch64 packages are built from the same source and pass the official `-c`
> check. This build host is x86_64 only, so aarch64 was not executed here; the
> arm64 runtime is validated by the store review / real hardware.

## Upgrade notes

- **From `0.90.0-4` to `0.90.0-5`:** same Docmost 0.90.0, same PostgreSQL 16
  data format and the same three mounts. Stop the old app, install the new
  package, start it. The existing `.app_secret`, database and attachments are
  reused; no migration is required.
- **Do not downgrade PostgreSQL.** This package stays on PostgreSQL 16.x so the
  existing `db/` cluster keeps working. Upstream's current Compose file uses
  PostgreSQL 18, but switching major versions requires `pg_upgrade`; do not
  change the image tag on an existing data directory.
- **Port 8087 is intentionally unchanged.** TOS has thousands of apps and port
  collisions are normal; the platform does not require unique host ports. If
  8087 is already used on your NAS, install only one of the conflicting apps.
- **Redis 8.10.3** can read cache/queue data from a `0.90.0-4` install; the AOF
  is transient and is safe to rebuild.

## Limitations and security notes

- **Plain HTTP on the LAN.** Put a TLS reverse proxy in front before exposing
  the app to the internet. Without TLS, page content, cookies and WebSocket
  traffic are visible on the network.
- **`APP_URL` is `http://localhost:8087`.** The NAS LAN address is not known at
  install time. If you use e-mail invitations or SSO, change it to
  `http://<NAS-IP>:8087` in `docker-compose.yml` and recreate the app container.
- **No mail server by default.** `MAIL_DRIVER=log` prints invitation/reset
  links (including the recipient address) to the container log instead of
  sending them. Configure SMTP/Postmark for real delivery.
- **Advanced features are opt-in.** S3/Azure storage, Typesense search, AI
  providers and Gotenberg PDF export are supported by upstream but not
  configured here; enabling them sends data to the endpoint you choose.
- **CVE/T1.** Docmost 0.90.0 is the current upstream release; the image bundles
  Node.js 22.22.3 and application dependencies that can only be patched by an
  upstream rebuild. PostgreSQL 16.16 and Redis 8.10.3 are pinned to current
  patch releases. Keep the app non-root, behind a TLS proxy and update when
  upstream publishes.
- **No automatic update.** Install App Center updates yourself; back up first.
- **Data at rest is not encrypted by the app.** Use NAS volume encryption and
  encrypted backups if the content is sensitive.

## Troubleshooting

See [`docs/OPERATIONS.md`](docs/OPERATIONS.md) for:

- `docker compose ps` / `docker logs` commands;
- what to check when the app is unhealthy (database, Redis, permissions,
  `APP_SECRET`);
- why a first install can fail if the NAS port is occupied or the data
  directories are not owned by uid 1000, and how to fix it;
- how to reset the admin password / sessions safely;
- how to move the installation to another NAS.

Quick checks:

```bash
docker compose -p docmostdocker ps
docker logs --tail 100 docmostdocker
docker exec docmostdocker-db pg_isready -U docmost -d docmost
docker exec docmostdocker-redis redis-cli ping
curl -s http://127.0.0.1:8087/api/health
```

## Support

- Package issues / privacy requests:
  <https://github.com/Moechz/docmost/issues>
- Upstream documentation: <https://docmost.com/docs/>
- Upstream releases: <https://github.com/docmost/docmost/releases>

---

Packaged for TOS 7 by **Moechz**. Docmost is © Docmost, Inc. and contributors,
licensed AGPL-3.0. This is an independent community package, not affiliated
with Docmost, Inc. or TerraMaster.
