# NevusSafe

NevusSafe is a privacy-first file vault with encrypted local storage. The
repository is split into:

- `mobile/`: Flutter client (UI, local file management, encryption and sync).
- `server/`: small HTTP API boundary for authentication metadata and sync jobs.
- `database/`: PostgreSQL migrations. File bytes never pass through the API.

## Security boundaries

- Google Drive access is limited to `https://www.googleapis.com/auth/drive.file`.
- OAuth client secrets and refresh tokens are runtime secrets; copy
  `server/.env.example` to an ignored `.env` file and never commit credentials.
- Files are encrypted on the device with AES-256-GCM before local/cloud storage.
- The API stores metadata only. Resumable Drive uploads use short-lived,
  authenticated sessions and do not expose encryption keys.

## Supported files and limits

The initial policy allows JPEG, PNG, GIF, WEBP, HEIC, MP4, MOV, RAW, MPEG4, MKV
and VLC files. It also supports PDF, DOCX, XLSX, PPTX, TXT, CSV, ZIP, MD and
APK files. A single file is limited to 10 GiB;
uploads are streamed in 8 MiB chunks. The policy can be tightened by changing
`mobile/lib/core/file_policy.dart` and the matching server environment values.

The current mobile build implements the encrypted local vault. Google Drive
configuration is kept separate from the client so cloud synchronization can be
enabled only after production OAuth credentials and authenticated sync
endpoints are configured.

## Local development

1. Install Flutter and PostgreSQL.
2. Run `cd mobile && flutter pub get && flutter test`.
3. Apply `database/migrations/001_initial.sql` to a development database.
4. Run `cd server && npm install && npm run dev` after creating `.env`.

The client foundation intentionally keeps platform credentials out of source
control. Add Google OAuth client IDs through native platform configuration
(`google-services.json`/`GoogleService-Info.plist`) outside this repository.

## Production deployment

Tag a release (`vX.Y.Z`) to run `.github/workflows/release.yml`. The workflow
produces Android APK/AAB artifacts and an unsigned iOS IPA archive for signing
and submission. Android signing values and App Store credentials must be
configured as repository secrets; no signing material belongs in Git.

Before publishing, review [docs/privacy-policy.md](docs/privacy-policy.md),
configure the store privacy disclosures for Google Drive access, and verify
that production OAuth client IDs are restricted to the released package/bundle
identifiers. The API exposes `/health` for liveness checks and `/metrics` for
basic uptime and memory monitoring; put it behind authenticated infrastructure
monitoring and alert on failures or abnormal memory growth.
