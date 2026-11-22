# Notices — Docmost for TerraMaster TOS (`docmostdocker`)

**Package version:** `0.90.0-5`
**Packager:** Moechz (independent community package)
**Upstream application:** Docmost 0.90.0, <https://github.com/docmost/docmost>
**App Center:** <https://developer.terra-master.com>

This file records the licenses, image provenance and trademark attributions for
the Docmost TOS package. It is not the license of the upstream application; the
upstream license text and source are available at the links below.

---

## 1. Upstream application — Docmost 0.90.0

| Item | Value |
|---|---|
| Project | Docmost — open-source collaborative wiki and documentation software |
| Upstream source | <https://github.com/docmost/docmost> (tag `v0.90.0`) |
| License | **GNU Affero General Public License v3.0 (AGPL-3.0)** |
| License text | <https://github.com/docmost/docmost/blob/main/LICENSE> |
| Copyright | Copyright Docmost, Inc. and contributors |
| Container image | `docmost/docmost:0.90.0` (official image on Docker Hub) |
| Image digest | `docmost/docmost@sha256:3be8d60d9d5fb84738d2eca5616646e4ee8fd3df8c3524c74ed1050089391afc` |
| Image build date | 2026-05-21 |
| Base runtime | Alpine Linux with Node.js 22.22.3 |

The TOS package **does not contain or modify Docmost source code**. It contains
a Compose file that pulls the official image unmodified from Docker Hub, plus
TOS metadata and a small wrapper script that generates the required
`APP_SECRET` on first start. Because the image is pulled by the user's Docker
daemon, the image itself is distributed by Docmost, Inc. under the terms above;
the AGPL-3.0 source is available at the upstream repository.

## 2. Database — PostgreSQL 16.16

| Item | Value |
|---|---|
| Image | `postgres:16.16-alpine` (official Docker Hub image) |
| Image digest | `postgres@sha256:f2f98726820d0342055351c6e9d36e705f5bfffb3dd53ff556325114b08afb6d` |
| License | **PostgreSQL License** (a permissive, BSD-style license) |
| License text | <https://www.postgresql.org/about/licence/> |
| Copyright | Copyright The PostgreSQL Global Development Group |
| Project | <https://www.postgresql.org/> |

The package runs the unmodified official PostgreSQL image as a private,
non-root service. No PostgreSQL source code or binaries are redistributed in
this repository.

## 3. Cache / queue — Redis 8.10.3

| Item | Value |
|---|---|
| Image | `redis:8.10.3-alpine` (official Docker Hub image) |
| Image digest | `redis@sha256:7958cfbb9d152f87dadfbc89f1b0b15938f0b81ff8982feb327476f4911935c3` |
| License | **AGPL-3.0** (Redis 8 is also offered by Redis Ltd. under RSALv2 / SSPLv1) |
| License text | <https://github.com/redis/redis/blob/8.10.3/LICENSE.txt> |
| Copyright | Copyright Redis Ltd. and contributors |
| Project | <https://redis.io/> |

The package runs the unmodified official Redis image as a private, non-root
service with AOF enabled. No Redis source code or binaries are redistributed in
this repository.

## 4. Base operating-system components

The three images above are Alpine Linux based. Alpine and the packages inside
the images are distributed under their own open-source licenses (Alpine's
`apk-tools` is GPL-2.0; the image contains MIT, BSD, Apache-2.0, GPL and other
licensed components). The exact package set and license files are part of each
image and can be inspected with:

```bash
docker run --rm docmost/docmost:0.90.0  cat /etc/alpine-release
docker run --rm docmost/docmost:0.90.0  ls /usr/share/licenses 2>/dev/null
```

No Alpine binaries are redistributed in this repository.

## 5. Package tooling

| Component | License / terms |
|---|---|
| `TOSAppSelfTestingTool` | Official TerraMaster utility, redistributed in this repository **unmodified** for local package validation. Copyright TerraMaster. It is **not** covered by the MIT license of this repository; use is subject to TerraMaster's terms. |
| Package scripts, Compose file, `config.ini`, `.lang`, SVG icon, documentation | **MIT License**, Copyright (c) 2026 Moechz — see `LICENSE`. |

The generated `docmostdocker.svg` icon is an original functional vector mark
created for this package. Docmost's upstream project publishes PNG/ICO brand
assets but no compliant SVG; this package does not claim the upstream logo.

## 6. Trademarks and affiliation

- **Docmost** is a trademark of Docmost, Inc. This package is an independent
  community submission by Moechz and is **not** affiliated with, endorsed by or
  sponsored by Docmost, Inc.
- **TerraMaster**, **TOS** and **App Center** are trademarks of TerraMaster.
  This package is not an official TerraMaster product.
- **PostgreSQL** is a trademark of the PostgreSQL Community Association of
  Canada. **Redis** is a trademark of Redis Ltd. **Docker** and **Docker Hub**
  are trademarks of Docker, Inc.
- All other trademarks are the property of their respective owners.

The use of these names is descriptive (to identify the software being packaged
and the platform it runs on) and does not imply endorsement.

## 7. No warranty

The package is provided "as is", without warranty of any kind, as stated in
`LICENSE`. The packager is not responsible for data loss, security incidents or
damage caused by the upstream application or by the Docker images. Back up
`/Volume1/DockerAppData/docmostdocker/` before upgrading or uninstalling.

## 8. Source and corresponding source

- This package's source (Compose file, wrapper, metadata, documentation):
  <https://github.com/Moechz/docmost>
- Docmost source (AGPL-3.0):
  <https://github.com/docmost/docmost/tree/v0.90.0>
- PostgreSQL source:
  <https://github.com/postgres/postgres/tree/REL_16_16>
- Redis source:
  <https://github.com/redis/redis/tree/8.10.3>

If you redistribute the Docmost image or a modified version of it, you are
responsible for complying with the AGPL-3.0 (including offering the
corresponding source to network users). This package only references the
official image by tag/digest.
