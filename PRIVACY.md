# Privacy policy — Docmost for TerraMaster TOS (`docmostdocker`)

**Last updated:** 2026-11-22
**Applies to:** Docmost package version `0.90.0-5` and later, published by
Moechz in the TerraMaster App Center.
**Upstream project:** <https://github.com/docmost/docmost> (Docmost 0.90.0)
**Contact / data requests:** <https://github.com/Moechz/docmost/issues>

This policy explains what the Docmost application package stores, where it is
stored, how long it is kept, when anything leaves your NAS, and how you and the
users of your workspace can access, correct or delete it.

Docmost is a **self-hosted** application. It runs entirely on your TerraMaster
NAS in three Docker containers (application, PostgreSQL, Redis). The packager
does not operate a server for this app, does not receive your pages,
attachments, accounts or logs, and has no way to access your NAS. The "data
controller" for everything you put into Docmost is **you**, the owner or
administrator of the NAS. Docmost, Inc. is the upstream software vendor; its
cloud service and cloud privacy policy do not apply to this self-hosted
instance.

---

## 1. What the application stores

Docmost stores the content you create, the files you upload and the account and
session data needed to run a collaborative wiki. The package adds only one
file of its own: a generated application secret.

### 1.1 PostgreSQL database (system of record)

All structured data lives in the PostgreSQL cluster under
`/Volume1/DockerAppData/docmostdocker/db/pgdata` (container path
`/var/lib/postgresql/data/pgdata`).

| Data | Table(s) | Why |
|---|---|---|
| **Pages** — title, icon, cover, position, nested-page hierarchy, editor JSON, the Yjs collaborative document (`ydoc`), plain-text extraction and full-text index (`tsv`), author/editor ids, timestamps | `pages` | The wiki content itself. |
| **Page history** — prior versions and the user who saved them | `page_history` | Version history and restore. |
| **Comments** — comment text, author, page, timestamps, resolution state | `comments` | Page discussions. |
| **Spaces, groups, memberships, page permissions and access rules** | `spaces`, `space_members`, `groups`, `group_users`, `page_permissions`, `page_access` | Who can see or edit what. |
| **User accounts** — display name, **e-mail address**, **bcrypt password hash (cost 12)**, avatar URL, role, locale, timezone, UI settings, last login / last active, deactivated flag, optional SCIM id | `users` | Login and collaboration. |
| **Login sessions** — session id, user, workspace, device name, **user agent**, **IP address**, last-active time, expiry, revocation time, metadata | `user_sessions` | Keep users signed in and let them review/revoke sessions. The `geo_location` column exists but this build performs **no** IP geolocation lookup. |
| **One-time tokens** — password reset and e-mail verification tokens (hashed/opaque token value, type, expiry, used flag) | `user_tokens` | Password reset and account verification. |
| **Workspace invitations** — invited **e-mail address**, role, invitation token, inviter, groups | `workspace_invitations` | Invite teammates. |
| **Attachments metadata** — file name, storage path, size, extension, MIME type, uploader, page/space, optional extracted **text content** and search vector | `attachments` | Attachment list, preview and full-text search over uploaded documents. |
| **Public share links** — random share key, page, sub-page flag, search-indexing flag, creator | `shares` | "Share to web" links created by an administrator or page owner. |
| **Notifications, favourites, watchers, labels, backlinks, page verifications, templates** | `notifications`, `favorites`, `watchers`, `labels`, `page_labels`, `backlinks`, `page_verifications`, `page_verifiers`, `templates` | In-app features you choose to use. |
| **Audit log** (optional/enterprise feature) — actor, event, resource, IP address, before/after changes | `audit` | Security auditing when the feature is enabled. If it is not enabled the table stays empty. |
| **API keys / SCIM tokens** (optional/enterprise feature) — token hash, name, scopes, last used | `api_keys`, `scim_tokens` | Integrations you configure. |
| **AI chats** (optional/enterprise feature) — prompts, answers, references, model name | `ai_chats`, `ai_chat_messages` | Only populated if you configure an AI provider and use AI features. Empty by default. |

### 1.2 Uploaded files

Files uploaded through Docmost (page attachments, images, avatars stored
locally, page covers/icons, imported files) are written below
`/Volume1/DockerAppData/docmostdocker/storage` (container path
`/app/data/storage`). The `attachments.file_path` column records where each
file is stored. Exported PDFs are generated on demand and are not kept by the
package.

The package also creates **one** file of its own in that directory:

| File | Content | Why |
|---|---|---|
| `/Volume1/DockerAppData/docmostdocker/storage/.app_secret` | 96 random hexadecimal characters, mode `0600` | Signs session JWTs and derives the anonymised telemetry id (telemetry is disabled in this package). Generated on first start; never shipped in the package. |

### 1.3 Redis

`/Volume1/DockerAppData/docmostdocker/redis` (container path `/data`) holds the
Redis AOF (`appendonlydir/` with Redis 8). Redis is a cache and message bus, not
a system of record. It contains:

- cached pages, spaces and permissions (derived from PostgreSQL);
- rate-limit counters and throttling keys;
- background-job queues (for example e-mail delivery and audit events) —
  queue payloads can include recipient addresses and message content;
- WebSocket pub/sub messages that synchronise live editing between app
  instances;
- ephemeral collaboration state (active document sessions, presence).

The AOF is enabled so a restart does not lose queued work. You may clear this
directory while the containers are stopped; Docmost rebuilds its cache and
loses only queued/transient data.

### 1.4 Logs

Docmost writes to **stdout/stderr**, which Docker stores as the container log
(`docker logs docmostdocker`). Those logs can contain:

- HTTP request metadata: client IP address, timestamp, method, URL, status,
  user agent, workspace/user ids;
- application errors and stack traces that may quote a page title or an
  e-mail address;
- **e-mail content when the default `MAIL_DRIVER=log` is active** — invitation
  and password-reset links, recipient address and subject are printed instead
  of being sent. Configure SMTP/Postmark if you do not want this.

PostgreSQL and Redis also log to their container stdout. The package does not
write application log files to the data directories.

### 1.5 Browser storage and sessions

| Item | Where | Purpose / lifetime |
|---|---|---|
| `authToken` | Browser cookie, `HttpOnly`, `SameSite=Lax`, `Path=/` | Signed JWT with user id, workspace id, session id and expiry. Default lifetime **90 days** (`JWT_TOKEN_EXPIRES_IN=90d`); revoked on logout and when an administrator revokes the session. |
| UI preferences | Browser `localStorage` (theme, sidebar state, editor preferences, last workspace) | Convenience only; stays in your browser. |
| In-memory editor state | Browser tab / WebSocket connection | Unsaved edits; discarded when the tab closes unless autosaved. |

The package sets no advertising, analytics or tracking cookies.

### 1.6 WebSocket and real-time collaboration

Docmost uses a WebSocket connection (Socket.IO) and the Redis adapter to
synchronise edits, cursors and presence between users. The WebSocket carries:

- the authenticated user id, workspace id and page/document id;
- page content and incremental edit operations (Yjs updates);
- presence information (who is viewing/editing a document).

WebSocket traffic stays between the browser and your NAS (or your TLS reverse
proxy). It is not sent to the packager. Edits received over the WebSocket are
persisted to `pages.ydoc` and `page_history` in PostgreSQL, and transient
messages pass through Redis pub/sub. Like every HTTP request, the WebSocket
handshake exposes the client IP address to the NAS.

### 1.7 Search, storage and optional services

The package is configured with the **defaults** below. It does not bundle or
enable any external search engine, object storage or AI service.

| Subsystem | Default in this package | What it means for data |
|---|---|---|
| Search | `SEARCH_DRIVER=database` — PostgreSQL full-text search (`tsv` columns on `pages` and `attachments`) | Search runs entirely inside your PostgreSQL container. **No Meilisearch is used.** Upstream also supports Typesense; if you set `SEARCH_DRIVER=typesense`, page and attachment text plus metadata are indexed in the Typesense server you configure. |
| File storage | `STORAGE_DRIVER=local` — `/app/data/storage` on the NAS | Uploads stay on your NAS. Upstream also supports S3-compatible storage and Azure Blob; if you set `STORAGE_DRIVER=s3`/`azure`, new files are written to the bucket/account you configure. |
| E-mail | `MAIL_DRIVER=log` — no e-mail is sent; messages go to the container log | Configure `MAIL_DRIVER=smtp` or `postmark` to send invitations and password resets. |
| AI | No `AI_DRIVER`, no `OPENAI_API_KEY`, no `GEMINI_API_KEY`, no `OLLAMA_API_URL` | AI chat/summaries/embeddings are disabled. If you enable them, the page text and attachments you select are sent to the provider you configure. |
| PDF export | No `GOTENBERG_URL` | PDF export via Gotenberg is disabled. |
| Draw.io | No `DRAWIO_URL`; the client may use the public `embed.diagrams.net` when a user opens a draw.io diagram | Only when that feature is used; the diagram content is handled by the configured Draw.io host. |
| Telemetry | `DISABLE_TELEMETRY=true` | The upstream telemetry client exits without sending anything, so no data goes to `tel.docmost.com`. |

Anything you enable beyond these defaults is **your** configuration and your
choice of processor. The disclosure table in §3 lists the endpoints.

---

## 2. Where the data is stored

Everything persistent lives below one directory on the NAS:

```text
/Volume1/DockerAppData/docmostdocker/
├── storage/   -> /app/data/storage          attachments, images, avatars, covers,
│                                            .app_secret
├── db/        -> /var/lib/postgresql/data   PostgreSQL cluster; PGDATA = db/pgdata
│                                            pages, history, comments, users,
│                                            sessions, invitations, permissions,
│                                            shares, audit, optional AI chats
└── redis/     -> /data                      appendonlydir/ (AOF): cache, queues,
                                             rate limits, WebSocket pub/sub
```

Inside the containers these appear as `/app/data/storage`,
`/var/lib/postgresql/data/pgdata` and `/data`. The containers themselves are
disposable; their writable layers (except the declared mounts) are discarded
when a container is recreated.

**Who can read it on the NAS:** the files are owned by uid/gid `1000`, the
unprivileged user the containers run as. The NAS administrator (`root`) can
always read them, and so can anyone with access to the NAS volumes or their
backups. The packager cannot.

---

## 3. When data leaves the NAS

**Nothing about your pages, attachments, accounts or sessions is sent to the
packager — ever.** There is no packager account, no licence check, no usage
statistics and no "phone home" in this package.

Outbound connections happen only in the situations below. The first is part of
installing the app; the others are either administrator-configured or triggered
by content a user opens.

1. **Installing / updating the images** — Docker pulls
   `docmost/docmost:0.90.0`, `postgres:16.16-alpine` and
   `redis:8.10.3-alpine` from Docker Hub (or the registry mirror configured on
   your NAS). Docker Hub sees the NAS's IP address, the image names and tags.
2. **Version check in the admin area** — Docmost can ask
   `https://api.github.com/repos/docmost/docmost/releases/latest` for the
   latest release. The request carries the NAS's IP address and HTTP metadata;
   no content, account data or identifiers are sent.
3. **Telemetry — disabled in this package.** Upstream Docmost contains a daily
   telemetry job that would POST an HMAC of the workspace id, the Docmost
   version and counts of users/pages/spaces/workspaces to
   `https://tel.docmost.com/api/event`. This package sets
   `DISABLE_TELEMETRY=true`, so the job deletes its interval and sends nothing.
4. **Product analytics — inactive.** Upstream client code can initialise
   PostHog if `POSTHOG_KEY` is provided. The package provides no key, so no
   PostHog request is made.
5. **E-mail you configure** — if an administrator sets `MAIL_DRIVER=smtp` or
   `postmark`, invitation e-mails, password-reset e-mails and notifications are
   sent through that SMTP server or Postmark. They contain the recipient
   address, the sender, the subject and the invitation/reset link. With the
   default `log` driver nothing is sent.
6. **Storage/AI/search services you configure** — S3/Azure, Typesense, OpenAI,
   Gemini, Ollama, Gotenberg or a custom Draw.io URL are contacted only if you
   set the corresponding environment variables and use the feature. The data
   sent is the content needed for that feature (see the table).
7. **Content that embeds remote resources** — a page can embed a YouTube or
   Vimeo video, a draw.io diagram, an Excalidraw drawing/library, an external
   image or a link. Then the **reader's browser** contacts that host, which sees
   the reader's IP address and usually the page URL as `Referer`. The server
   does not proxy those requests. You control this by what you put on pages.
8. **Your own backups, monitoring or reverse proxy** — if you back up the data
   directory or expose the app through a proxy, those systems process the data
   under your own policies.

### Third-party endpoint disclosure (C8)

| Endpoint | Data sent | Destination | Trigger / default | Can it be disabled? |
|---|---|---|---|---|
| `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com` (Docker Hub) or your configured registry mirror | Image names/tags, NAS IP address | Docker Hub / your mirror | App install and image updates | Unavoidable for install; pre-pull images or use a local mirror |
| `https://api.github.com/repos/docmost/docmost/releases/latest` | NAS IP address, HTTP User-Agent; no content or identifiers | GitHub, Inc. (USA) | Administrator opens the version/update check | Yes — block the host or ignore the check |
| `https://tel.docmost.com/api/event` | Workspace HMAC, Docmost version, counts of users/pages/spaces/workspaces | Docmost, Inc. (USA) | Would run every 24 h | **Disabled in this package** (`DISABLE_TELEMETRY=true`); can also be blocked at the firewall |
| `https://us.i.posthog.com`, `https://app.posthog.com` | Product-analytics events (if a key were configured) | PostHog (USA) | Inactive: no `POSTHOG_KEY` is set | Yes — do not set a key; block the host |
| `https://embed.diagrams.net` (or your `DRAWIO_URL`) | Diagram XML and page context needed to edit the diagram | diagrams.net / your Draw.io host | User opens or edits a draw.io diagram | Yes — do not use draw.io diagrams, set a self-hosted `DRAWIO_URL`, or block the host |
| `https://json.excalidraw.com` | Drawing JSON when a user chooses "share" to excalidraw.com | Excalidraw (USA) | Explicit share action | Yes — do not use the share action |
| `https://libraries.excalidraw.com`, `https://plus.excalidraw.com` | Library requests / upgrade prompts from the Excalidraw UI | Excalidraw (USA) | User opens the library or upgrade UI | Yes — block the host or avoid the feature |
| `https://www.youtube.com`, `https://www.youtube-nocookie.com`, `https://player.vimeo.com` | Embed request, reader IP, page URL as Referer | Google / Vimeo | Page contains an embedded video and is viewed | Yes — remove the embed or block the hosts |
| `https://cdn.jsdelivr.net` | Static JavaScript/CSS for optional editor features | jsDelivr (CDN) | Only when a feature that loads a remote library is used | Yes — block the host; the core UI is served locally |
| `https://github.com`, `https://docmost.com` | Normal web request (IP, User-Agent) | GitHub / Docmost, Inc. | User clicks a help, release or sales link | Yes — do not click; no automatic request except the version check above |
| Your SMTP server or `https://api.postmarkapp.com` | Recipient address, sender, subject, invitation/reset link and message body | Your mail provider | Administrator configures `MAIL_DRIVER` and sends mail | Yes — keep the default `log` driver |
| Your S3-compatible endpoint or Azure Blob endpoint | Uploaded files, avatars, covers, attachment metadata | Your storage provider | Administrator sets `STORAGE_DRIVER=s3`/`azure` | Yes — keep `STORAGE_DRIVER=local` |
| `https://api.openai.com`, Google Gemini API, your Ollama URL, or an OpenAI-compatible URL | Page text, selected attachment text and prompts | The AI provider you configure | Administrator sets `AI_DRIVER` and API keys and a user invokes AI | Yes — no AI provider is configured by default |
| Your Typesense server (`TYPESENSE_URL`) | Page/attachment text and metadata | Your Typesense instance | Administrator sets `SEARCH_DRIVER=typesense` | Yes — keep `SEARCH_DRIVER=database` |
| Your Gotenberg server (`GOTENBERG_URL`) | Page HTML rendered for PDF export | Your Gotenberg instance | Administrator sets `GOTENBERG_URL` and a user exports PDF | Yes — leave `GOTENBERG_URL` unset |
| Any host referenced by page content (images, links, embeds) | The request for that resource, reader IP, Referer | That host | A reader views a page containing it | Yes — remove the resource or block the host |

There is no other outbound traffic: no advertising, no crash reporting, no
third-party JavaScript required by the core UI, no CDN-loaded fonts.

---

## 4. Retention period

- **Pages, page history, comments, attachments, spaces, groups and accounts do
  not expire automatically.** They stay on the NAS until deleted (§6) or until
  the data directory is removed.
- **Trash:** deleting a page moves it to the workspace trash. The default
  retention is **30 days** (`trashRetentionDays` can be changed by a workspace
  administrator); a scheduled cleanup permanently removes items whose retention
  has expired. "Delete permanently" removes a page immediately.
- **Page history** keeps prior versions for as long as the page exists (and, for
  trashed pages, until the page is purged). There is no separate automatic
  expiry.
- **Attachments** remain until deleted from the page/attachment UI or until
  their page is purged. Extracted attachment text and its search vector are
  removed with the attachment row.
- **User accounts** remain until deleted. Deletion is soft (`users.deleted_at`)
  so that authorship of existing pages/comments stays attributable; the row can
  be purged from PostgreSQL by the administrator. Deactivating a user blocks
  login without deleting the account.
- **Login sessions** expire after **90 days** by default, are deleted/revoked on
  logout, and can be revoked earlier from the account's session list. Expired
  rows are cleaned up by the application/database maintenance.
- **Password-reset and verification tokens** carry an expiry and are consumed on
  use; **workspace invitations** remain until accepted or deleted by an
  administrator.
- **Audit log** (if enabled) is retained until the workspace is deleted or an
  administrator removes rows; the package adds no automatic purge.
- **Redis** is rebuilt from PostgreSQL after a flush. The AOF keeps cache,
  queues and transient collaboration state across restarts; clear
  `redis/appendonlydir/` (containers stopped) to remove it.
- **Container logs** are kept in Docker's log store according to your Docker
  daemon's log driver and rotation settings. The package sets no log rotation;
  configure one if the NAS is short on space. `docker logs` content, including
  any `MAIL_DRIVER=log` e-mail, disappears when the container is removed.
- **Backups:** if you back up `/Volume1/DockerAppData/docmostdocker/`, copies of
  all the data above — including password hashes and session rows — may exist in
  those backups under your backup tool's retention rules. The package creates no
  backups itself.
- **Deleted workspace / uninstall:** removing the data directory permanently
  deletes pages, history, attachments, accounts, sessions and the Redis AOF.
  There is no packager-side copy to delete.

---

## 5. Your rights and how to exercise them

Because the data is on your own NAS and the packager never receives it, rights
are exercised directly on the NAS.

- **Access / portability** — use the Docmost UI (page export to Markdown/HTML,
  PDF export if configured, attachment download), the documented API, or read
  the files/database directly:
  - pages and history: `pages`, `page_history` tables, or the UI;
  - accounts, roles, groups, permissions: `users`, `groups`, `group_users`,
    `spaces`, `space_members`, `page_permissions`, `page_access`;
  - sessions: `user_sessions` (device, user agent, IP, last active, expiry);
  - attachments: the files below
    `/Volume1/DockerAppData/docmostdocker/storage/` plus the `attachments` table;
  - a complete logical backup: `pg_dump` inside the PostgreSQL container plus a
    copy of the `storage/` directory.
- **Rectification** — edit pages/comments in the UI (every save is a new
  revision); correct names, e-mail addresses, roles, passwords and group
  membership in the workspace member settings (or the `users`/`groups` tables
  while the app is stopped); correct permissions in the space/page permission
  UI.
- **Erasure** — see §6. A workspace administrator can delete pages,
  attachments, comments, invitations and users; the NAS owner can delete the
  whole data directory.
- **Restriction / objection** — deactivate a user, revoke sessions, stop the
  containers, block the app at the firewall, disable optional integrations
  (§3), or uninstall the app. There is no packager-side processing to object
  to.
- **Withdraw consent** — the packager processes nothing and asks for no
  consent. Optional integrations you enable are under your control; disable
  them by removing the corresponding environment variables.
- **Automated decisions / profiling** — none in this package. Docmost does not
  profile users, score them or make automated decisions about them, and
  telemetry is disabled.
- **Complaint** — contact the packager through
  <https://github.com/Moechz/docmost/issues>. You also have the right to
  contact your local data-protection authority.

**Rights of workspace users (not the NAS owner).** Accounts in Docmost are
created by the workspace administrator. A user who wants their account data
(name, e-mail, password, sessions, group membership) or their contributions
exported, corrected or deleted should contact **their workspace administrator**
— that is the only party with access. The packager cannot read, change or
delete anything in your workspace. If the administrator does not respond, the
NAS owner can always act directly on the files/database (§6).

**Role of the upstream vendor.** Docmost, Inc. publishes the software and the
container image but does not operate this instance and does not receive its
data. Its cloud privacy policy applies only to its own hosted service, not to
this package.

---

## 6. Deletion channel

All deletion is performed by you, on the NAS. Supported ways:

1. **From the Docmost UI (workspace administrator or page owner):**
   - page menu → **Move to trash**, then **Delete permanently** (or empty the
     trash); trash is purged automatically after the configured retention
     (default 30 days);
   - page history → delete old versions if the UI offers it, or purge
     `page_history` rows for that page;
   - attachment/file → delete from the page or the attachment manager;
   - workspace members → **Deactivate** or **Delete** a user; remove
     invitations; revoke sessions from the account/session screen;
   - space/page permissions → remove members or access rules;
   - share links → delete the share;
   - workspace settings → delete the workspace (removes its rows).
2. **Directly in PostgreSQL (containers running; take a backup first):**

   ```bash
   docker exec -it docmostdocker-db psql -U docmost -d docmost
   -- inspect first, then delete the specific rows, for example:
   -- DELETE FROM pages WHERE id = '<page-uuid>';
   -- DELETE FROM users WHERE id = '<user-uuid>';   -- also removes sessions/tokens
   ```

   Prefer the UI for normal deletion; direct SQL bypasses application cleanup
   (files in `storage/` are not removed automatically) and cannot be undone.
3. **Files on the host (stop the app first):**

   ```bash
   docker compose -p docmostdocker stop
   # delete one attachment or all uploaded files
   rm -f /Volume1/DockerAppData/docmostdocker/storage/<path>
   # or clear the disposable cache/queues
   rm -rf /Volume1/DockerAppData/docmostdocker/redis/appendonlydir
   ```

4. **Complete removal (uninstall with data):**

   ```bash
   docker compose -p docmostdocker down -v
   rm -rf /Volume1/DockerAppData/docmostdocker
   ```

   This removes pages, history, attachments, accounts, sessions, the Redis AOF
   and the generated secret. It cannot be undone. App Center's "uninstall and
   delete data" option performs the same removal. If you keep the data
   directory, reinstalling the same version reuses the existing workspace.

5. **Container logs:** `docker rm -f docmostdocker docmostdocker-db
   docmostdocker-redis` removes the log stream (and the containers). Docker's
   log files for removed containers are cleaned up by Docker; check your Docker
   log driver settings if you need a guaranteed wipe.

**Backups are outside the app's control.** Delete the relevant backup snapshots
with your backup tool if you need a copy removed there as well.

---

## 7. Security measures

- **Non-root containers.** All three services run as `user: "1000:1000"`.
  There is no `privileged`, no `network_mode: host`, no Docker socket, no
  `cap_add`, no `pid`/`ipc` host namespace and no host device.
- **Network isolation.** Only Docmost publishes a host port (`8087` → `3000`).
  PostgreSQL (`5432`) and Redis (`6379`) are on the private Compose network and
  are not published to the LAN. PostgreSQL uses `trust` authentication **inside
  that private network only**; do not attach unrelated containers to it.
- **Secret handling.** `APP_SECRET` is generated on the NAS from
  `/dev/urandom`, stored in `.app_secret` with mode `0600`, never shipped in the
  package and never written to the Compose file or logs. Passwords are hashed
  with **bcrypt cost 12**; the hash is never returned by the API.
- **Sessions.** The `authToken` cookie is `HttpOnly`, `SameSite=Lax`, `Path=/`
  and expires after 90 days by default. Sessions are recorded server-side
  (`user_sessions`) and can be revoked; logout revokes the current session.
- **Transport.** The app serves plain HTTP on the LAN. Before exposing it to
  the internet, put a TLS reverse proxy (HTTPS/WSS) in front of it and restrict
  access. Without TLS, page content, cookies and WebSocket traffic are visible
  to anyone who can sniff the LAN.
- **Data at rest.** The application does not encrypt its database or files.
  Use NAS volume encryption, encrypted backups and restrictive share
  permissions if the data is sensitive.
- **Least data.** Telemetry and product analytics are disabled; no advertising
  or tracking code is active; optional integrations are off unless you configure
  them.
- **Updates.** The images are pinned (`docmost/docmost:0.90.0`,
  `postgres:16.16-alpine`, `redis:8.10.3-alpine`). Install App Center updates
  when they are published; the package does not auto-update.
- **Administrator power.** Workspace administrators can read all content in
  their workspace and export it. The NAS `root` user and anyone with access to
  the data directory or its backups can read everything. This is inherent to a
  self-hosted wiki and is not a defect of the package.

**Known residual risk (T1).** Docmost 0.90.0 is the current upstream release
and its container image bundles Node.js 22.22.3 and application dependencies;
CVEs in those bundles can only be fixed by an upstream rebuild. This package
pins the current PostgreSQL 16.16 and Redis 8.10.3 patch releases, runs
everything non-root, publishes only the web port and disables telemetry. Do not
expose the app directly to the internet; keep it behind a TLS reverse proxy and
apply App Center updates when upstream publishes them.

---

## 8. International transfers, children, changes

- **International transfers.** The packager transfers nothing. Third-party
  services in §3 may process data in other countries under their own policies;
  they are used only if you configure them or open content that contacts them.
- **Children.** Docmost is a workplace documentation tool, not directed at
  children. The workspace administrator decides who may use the workspace.
- **Changes.** Material changes to this policy are published in the repository
  with a new `Last updated` date and a CHANGELOG entry. The policy shipped with
  the installed version is the one that applies to that version.

---

## 9. Contact

- **Packager / data requests:** <https://github.com/Moechz/docmost/issues>
- **Upstream software:** <https://github.com/docmost/docmost>
- **TerraMaster App Center:** <https://developer.terra-master.com>

Please include the app version (`0.90.0-5`), the architecture (`x86_64` or
`aarch64`) and enough detail to locate the data (page id, user e-mail, table or
file path). Never post passwords, session cookies, `.app_secret` or production
data in a public issue.
