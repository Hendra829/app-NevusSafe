# NevusSafe

NevusSafe is a privacy-first file vault with encrypted local storage. The
repository is split into:

- `mobile/`: Flutter client for the user interface, local file management, and
  encryption.
- `server/`: small HTTP API boundary for policy and health metadata.
- `database/`: PostgreSQL migrations. File bytes never pass through the API.

## Current security boundaries

- Files are encrypted on-device with AES-256-GCM before being stored locally.
- The AES-256 key is stored through Flutter Secure Storage.
- A malformed stored key is rejected instead of silently replaced, preventing
  existing vault files from becoming undecryptable.
- Google Drive access is reserved for the least-privilege
  `https://www.googleapis.com/auth/drive.file` scope.
- OAuth client secrets and refresh tokens are runtime secrets. Copy
  `server/.env.example` to an ignored `.env` file and never commit credentials.
- Cloud synchronization is not enabled in the current mobile build.

## Supported files and limits

The current local vault accepts JPEG, PNG, GIF, WEBP, HEIC, MP4, MOV, RAW,
MPEG4, MKV, VLC, PDF, DOCX, XLSX, PPTX, TXT, CSV, ZIP, MD, and APK files.

A selected file is currently buffered in memory for authenticated encryption.
To avoid excessive Android memory pressure, imports are limited to 64 MiB.
Support for larger files requires a versioned streaming-encryption format and
migration tests; the existing format must not be changed silently.

The mobile and server policy defaults must remain aligned:

- `mobile/lib/core/file_policy.dart`
- `server/.env.example`
- `server/src/server.js`

## Local development

1. Install Flutter 3.24 and Node.js 20 or newer.
2. Run `cd mobile && flutter pub get`.
3. Run `flutter analyze --fatal-infos && flutter test`.
4. Run `cd ../server && npm install --ignore-scripts`.
5. Run `node --check src/server.js && npm start`.
6. Verify `http://localhost:8080/health` returns HTTP 200.

PostgreSQL is required only when database-backed features are implemented.
Apply `database/migrations/001_initial.sql` to a development database before
enabling those features.

## Android builds

`.github/workflows/build-android-release.yml` validates dependencies, static
analysis, tests, APK compilation, checksum generation, and artifact upload.

- Pull requests always produce a debug APK and never receive signing secrets.
- Trusted manual or main-branch runs produce a signed release APK only when all
  Android signing secrets are configured.
- Debug and release artifacts are labelled separately.

## Production release

A version tag such as `v1.0.0`, or a trusted manual dispatch, runs
`.github/workflows/release.yml`. The workflow requires all Android signing
secrets and produces a signed APK, signed AAB, and SHA-256 checksums.

The repository does not currently contain an iOS platform scaffold, so it does
not claim to produce an IPA. Add and validate the iOS project and signing
pipeline separately before advertising iOS release support.

Before publishing, review [docs/privacy-policy.md](docs/privacy-policy.md),
configure accurate store privacy disclosures, and restrict production OAuth
client IDs to the released package and signing certificate.
