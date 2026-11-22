# Operations guide — Docmost for TOS 7

This guide covers installation, upgrades, backup/restore, uninstall,
troubleshooting and security for the `docmostdocker` package. For data
practices and user rights see [`../PRIVACY.md`](../PRIVACY.md); for licenses
see [`../NOTICE.md`](../NOTICE.md).

All commands run on the NAS as the administrator. The Compose project name is
`docmostdocker`.

---

## 1. What is installed

| Service | Image | User | Port |
|---|---|---|---|
| `docmostdocker` | `docmost/docmost:0.90.0` | `1000:1000` | host `8087` → container `3000` |
| `docmostdocker-db` | `postgres:16.16-alpine` | `1000:1000` | private only (5432) |
| `docmostdocker-redis` | `redis:8.10.3-alpine` | `1000:1000` | private only (6379) |

Data:

```text
/Volume1/DockerAppData/docmostdocker/
├── storage/   -> /app/data/storage          attachments, avatars, covers, .app_secret
├── db/        -> /var/lib/postgresql/data   PostgreSQL cluster (PGDATA=db/pgdata)
└── redis/     -> /data                      Redis AOF (cache, queues, pub/sub)
```

The official installer chowns the bind-mount sources to the `user:` in the
Compose file (`1000:1000`). If you install manually, do that yourself:

```bash
sudo mkdir -p /Volume1/DockerAppData/docmostdocker/{storage,db,redis}
sudo chown -R 1000:1000 /Volume1/DockerAppData/docmostdocker
```

---

## 2. First install

### Through App Center

1. Install/update **DockerEngine**.
2. Install **Docmost** from App Center.
3. Open `http://<NAS-IP>:8087/` and complete the wizard (workspace name,
   administrator name, e-mail, password). The first account is the workspace
   administrator.
4. Optionally create a space and invite users.

### On a test NAS (official installer)

```bash
sudo ./TOSAppSelfTestingTool -i out/docmostdocker_x86_64.tar.gz
```

or, for a manual Compose run:

```bash
cd /path/to/docmostdocker            # directory containing docker-compose.yml
sudo docker compose -p docmostdocker up -d
```

### What "installation failed" usually means (F1)

The package itself passes the official `-c` check and starts as uid 1000 on a
clean host. If App Center reports that online installation failed, check in
this order:

1. **Host port 8087 is already in use** by another app or a leftover container:

   ```bash
   ss -tlnp | grep ':8087 '
   docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -i docmost
   ```

   TOS does not require unique host ports, but two apps cannot bind the same
   port at the same time. Stop/uninstall the other app or install only one of
   the conflicting apps. Do **not** change the package port just because it
   collides (see the repository's RUNBOOK §12).

2. **Stale containers from an earlier version** (same `container_name`):

   ```bash
   docker ps -a --filter label=com.docker.compose.project=docmostdocker
   docker rm -f docmostdocker docmostdocker-db docmostdocker-redis
   ```

   Then retry the install. Data in `/Volume1/DockerAppData/docmostdocker/` is
   not removed by `docker rm -f`.

3. **Data directories are not writable by uid 1000** (manual install, restored
   backup, or a copied data folder):

   ```bash
   ls -ld /Volume1/DockerAppData/docmostdocker /Volume1/DockerAppData/docmostdocker/*
   sudo chown -R 1000:1000 /Volume1/DockerAppData/docmostdocker
   ```

   The app's wrapper prints a clear `FATAL: /app/data/storage is not writable`
   message if this is the cause; PostgreSQL logs `Permission denied` or
   `could not create directory` in the same situation.

4. **Images cannot be pulled** (Docker Hub unreachable / rate limit):

   ```bash
   docker pull docmost/docmost:0.90.0
   docker pull postgres:16.16-alpine
   docker pull redis:8.10.3-alpine
   ```

   Configure a registry mirror in DockerEngine, or pre-pull the images before
   installing.

5. **Not enough memory.** The stack needs roughly 1 GB free (Node + PostgreSQL
   + Redis). Check `free -m` and the container logs for OOM kills
   (`docker inspect <name> --format '{{.State.OOMKilled}}'`).

If none of these apply, collect `docker compose -p docmostdocker ps`, the logs
of all three containers, `ss -tlnp | grep 8087`, and the App Center error text.

---

## 3. Health checks

```bash
docker compose -p docmostdocker ps
curl -s http://127.0.0.1:8087/api/health
```

Expected:

```json
{"status":"ok","info":{"database":{"status":"up"},"redis":{"status":"up"}},"error":{},"details":{"database":{"status":"up"},"redis":{"status":"up"}}}
```

Per service:

```bash
docker exec docmostdocker-db pg_isready -U docmost -d docmost
docker exec docmostdocker-redis redis-cli ping          # PONG
docker inspect docmostdocker --format '{{.State.Health.Status}}'
```

If the app is unhealthy, read the logs in this order:

```bash
docker logs --tail 150 docmostdocker-db
docker logs --tail 150 docmostdocker-redis
docker logs --tail 150 docmostdocker
```

Common causes:

| Symptom | Check / fix |
|---|---|
| App restarts, log says `database connection` | PostgreSQL not healthy yet or wrong `DATABASE_URL`; wait for `pg_isready`, then restart the app. |
| App restarts, log says `Redis connection` | Redis not healthy; check `redis-cli ping` and the Redis logs. |
| App exits with `APP_SECRET` error | `.app_secret` missing/empty/too short; stop the container, delete `storage/.app_secret`, start again (this invalidates existing sessions). |
| `FATAL: /app/data/storage is not writable` | `chown -R 1000:1000 /Volume1/DockerAppData/docmostdocker`. |
| PostgreSQL: `data directory has wrong ownership` | The `db/` tree is not owned by 1000; fix ownership (never run `initdb` as root). |
| `port is already allocated` | Another app/container uses 8087; see §2.1. |
| App healthy but browser gets 502/connection refused | Reverse proxy points at the wrong port/host; it must target `127.0.0.1:8087`. |

---

## 4. Upgrade

### From 0.90.0-4 to 0.90.0-5

The Docmost version is unchanged (0.90.0), the PostgreSQL major version is
unchanged (16), and the three mount points are unchanged. The upgrade is a
normal package replacement:

```bash
# 1. back up first
docker compose -p docmostdocker stop
sudo tar -C /Volume1/DockerAppData -czf /Volume1/backup/docmost-$(date +%F).tar.gz docmostdocker
docker compose -p docmostdocker start

# 2. install the new package from App Center (or the official tool on a test NAS)
# 3. open the app and verify /api/health and the page list
```

The existing `.app_secret`, database and attachments are reused. No migration
command is needed; Docmost runs its own schema migrations at startup.

### Upgrading Docmost in the future

1. Read the upstream release notes for breaking changes and database
   requirements.
2. Change `image: docmost/docmost:<new-tag>` in `src/docker-compose.yml` **and**
   in `tosapp.json` (the build gate requires they match), plus `version`.
3. Rebuild both architectures, run `stage.py`, then publish/submit.
4. Back up before installing the update.

**Never change the PostgreSQL major version on an existing `db/` directory.**
PostgreSQL 18 cannot open a PostgreSQL 16 data directory; that requires
`pg_upgrade` or a dump/restore. This package deliberately stays on 16.x for
in-place upgrades.

### Redis

Redis 8.10.3 reads the cache/queue data from 7.x. The AOF is transient; if a
future Redis upgrade refuses the old AOF, stop the stack and remove
`redis/appendonlydir/` (cache and queued jobs are rebuilt; the wiki database is
unaffected).

---

## 5. Backup and restore

### Full backup (recommended)

```bash
docker compose -p docmostdocker stop
sudo tar -C /Volume1/DockerAppData -czf /Volume1/backup/docmost-$(date +%F).tar.gz docmostdocker
docker compose -p docmostdocker start
```

This captures PostgreSQL, uploaded files, Redis and the secret. Keep the
backup encrypted if the wiki contains sensitive data (the archive includes
password hashes and session rows).

### Logical database backup (online)

```bash
docker exec docmostdocker-db pg_dump -U docmost -d docmost -Fc \
  > /Volume1/backup/docmost-$(date +%F).dump
# plus the files:
sudo tar -C /Volume1/DockerAppData/docmostdocker -czf /Volume1/backup/docmost-files-$(date +%F).tar.gz storage
```

### Restore

```bash
docker compose -p docmostdocker down
sudo rm -rf /Volume1/DockerAppData/docmostdocker
sudo tar -C /Volume1/DockerAppData -xzf /Volume1/backup/docmost-YYYY-MM-DD.tar.gz
sudo chown -R 1000:1000 /Volume1/DockerAppData/docmostdocker
# reinstall the same package version and start it
```

Restoring a backup from a different Docmost version may require running the
matching package version first, then upgrading through the normal path.

---

## 6. Uninstall

**Keep data (reinstall later):**

- App Center → uninstall Docmost (keep the data directory), or
  `docker compose -p docmostdocker down`.
- `/Volume1/DockerAppData/docmostdocker/` remains.

**Delete everything:**

```bash
docker compose -p docmostdocker down -v
sudo rm -rf /Volume1/DockerAppData/docmostdocker
```

This permanently removes pages, history, attachments, accounts, sessions,
Redis data and `.app_secret`. App Center's "uninstall and delete data" option
does the same. There is no packager-side copy.

If you only need to clear the cache/queues:

```bash
docker compose -p docmostdocker stop
sudo rm -rf /Volume1/DockerAppData/docmostdocker/redis/appendonlydir
docker compose -p docmostdocker start
```

---

## 7. Accounts, passwords and sessions

- **Create the first administrator:** the first-run wizard
  (`http://<NAS-IP>:8087/`) creates the workspace and the admin account.
- **Invite users:** workspace settings → members → invite. With the default
  `MAIL_DRIVER=log`, the invitation link is printed to
  `docker logs docmostdocker` instead of being e-mailed. Configure SMTP to send
  real mail:

  ```yaml
  MAIL_DRIVER: "smtp"
  SMTP_HOST: "smtp.example.com"
  SMTP_PORT: "587"
  SMTP_SECURE: "false"
  SMTP_USERNAME: "docmost@example.com"
  SMTP_PASSWORD: "<app-password>"
  MAIL_FROM_ADDRESS: "docmost@example.com"
  MAIL_FROM_NAME: "Docmost"
  ```

  Put secrets in a local override file, not in the repository. Never commit
  them.
- **Forgot the admin password:** use the "Forgot password" link. With
  `MAIL_DRIVER=log`, the reset link appears in
  `docker logs docmostdocker`. If e-mail is unavailable and there is only one
  admin, reset the password directly in PostgreSQL (take a backup first):

  ```bash
  # generate a bcrypt hash with the container's Node runtime (cost 12)
  docker exec -it docmostdocker node -e \
    "require('bcrypt').hash(process.argv[1],12).then(console.log)" 'NewStrongPassword!'
  # update the row (replace <hash> and the e-mail)
  docker exec -it docmostdocker-db psql -U docmost -d docmost -c \
    "UPDATE users SET password='<hash>' WHERE email='admin@example.com';"
  ```

  This bypasses the app's password policy and audit trail; prefer the reset
  e-mail when possible.
- **Revoke sessions:** account/session settings in the UI, or
  `DELETE FROM user_sessions WHERE user_id = '<uuid>';` (log the user out).
- **Delete a user:** workspace members → delete (soft delete; content remains
  attributed) or remove the row in PostgreSQL for a hard purge. Removing
  `storage/` files is a separate step.

---

## 8. Security hardening

- **TLS reverse proxy** for any access beyond a trusted LAN. Proxy
  `https://wiki.example.com` → `http://127.0.0.1:8087`, forward
  `Host`, `X-Forwarded-For`, `X-Forwarded-Proto`, and enable WebSocket
  upgrade for Socket.IO.
- **Do not publish PostgreSQL or Redis.** They are private by design; adding
  `ports:` for them exposes the database/cache to the LAN.
- **Keep `user: "1000:1000"`.** Do not add `privileged`, `network_mode: host`,
  `cap_add` or the Docker socket.
- **Change `APP_URL`** to the external URL when using a reverse proxy or
  e-mail invitations (for example `https://wiki.example.com`), otherwise
  invitation/e-mail links point at `localhost`. Restart the app after changing
  it.
- **Configure SMTP** if you invite users; otherwise invitation links land in
  the container log.
- **Restrict who can reach the NAS port.** Use the TOS firewall or your reverse
  proxy's access rules.
- **Back up and encrypt backups.** The data directory contains password hashes
  and session records.
- **Update.** Install new App Center versions when published; the package does
  not auto-update. Read `CHANGELOG.md` before upgrading.

---

## 9. Moving to another NAS

1. Back up the whole `/Volume1/DockerAppData/docmostdocker/` directory.
2. On the new NAS, install the same package version (so the schema matches).
3. Stop the app, restore the directory, fix ownership
   (`chown -R 1000:1000`), start the app.
4. If the NAS IP/hostname changes, update `APP_URL` and any reverse proxy
   configuration.

---

## 10. Support

- Package repository / issues: <https://github.com/Moechz/docmost/issues>
- Privacy policy: [`../PRIVACY.md`](../PRIVACY.md)
- Upstream docs: <https://docmost.com/docs/>
- Include the app version, architecture, `docker compose ps`, relevant logs and
  the exact error text. Never post passwords, cookies, `.app_secret` or private
  page content.
