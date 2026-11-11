# Changelog

All notable user-visible changes to the Docmost TOS application package.

## 0.90.0-2 — 2026-11-12

### Changed
- Icon: replaced the letter monogram with a functional vector mark that describes what the app does (the upstream project does not publish a compliant SVG).

## 0.90.0-1 — 2026-11-11

### Added
- First release. Docmost (`docmost/docmost:0.90.0`, Docker Hub official image, unmodified)
  packaged as a TOS 7 Docker application, published on port 8087 and running
  as a non-root user (1000:1000).
- Persistent data is kept under `/Volume1/DockerAppData/docmostdocker/`.
