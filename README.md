# NevusSafe

NevusSafe is a privacy-first file vault with encrypted local storage and an
optional Google Drive backup. The repository is split into:

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

The initial policy allows JPEG, PNG, GIF, WEBP, HEIC, MP4, MOV, PDF, DOCX,
XLSX, PPTX, TXT, CSV and ZIP files. A single file is limited to 10 GiB;
uploads are streamed in 8 MiB chunks. The policy can be tightened by changing
`mobile/lib/core/file_policy.dart` and the matching server environment values.

## Local development

1. Install Flutter and PostgreSQL.
2. Run `cd mobile && flutter pub get && flutter test`.
3. Apply `database/migrations/001_initial.sql` to a development database.
4. Run `cd server && npm install && npm run dev` after creating `.env`.

The client foundation intentionally keeps platform credentials out of source
control. Add Google OAuth client IDs through native platform configuration
(`google-services.json`/`GoogleService-Info.plist`) outside this repository.
