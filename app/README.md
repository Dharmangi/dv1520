# dv1520_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## CI/CD: Android release pipeline

Defined in [`.github/workflows/release.yml`](../.github/workflows/release.yml). Every push to `main` builds a
release APK and publishes it as a GitHub Release.

### How it works

1. Checks out the repo and reads the version from `pubspec.yaml` (e.g. `1.0.0+1`).
2. Sets up Flutter 3.44.4 (stable) and JDK 17, with Flutter and Gradle caching enabled.
3. Fails immediately with a clear error if any of the four Android signing secrets are missing
   (see below) — it will never silently ship a debug-signed APK.
4. Reconstructs the release keystore and `android/key.properties` from secrets, builds
   `app-release.apk` stamped with the `pubspec.yaml` version, then deletes the keystore
   from the runner.
5. Creates a GitHub Release tagged `v<version>` (e.g. `v1.0.0`) — derived from `pubspec.yaml`,
   not the workflow run number — and uploads `app-release.apk` as a release asset. If a release
   for that tag already exists, its assets are updated in place rather than failing.

### Android release signing setup (required)

`android/app/build.gradle.kts` reads `android/key.properties` to sign release builds, falling
back to the debug key only when that file is absent (e.g. plain local `flutter run --release`
without signing set up). In CI, `key.properties` is generated from secrets before every build.
Add these four **repository secrets** under **Settings → Secrets and variables → Actions**:

| Secret | Where it comes from |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 of your `.jks` keystore file: `base64 -w0 release.jks` (Linux/macOS) or `[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.jks"))` (PowerShell) |
| `ANDROID_KEYSTORE_PASSWORD` | The password you set when creating the keystore (`-storepass`) |
| `ANDROID_KEY_ALIAS` | The alias you set when creating the keystore (`-alias`) |
| `ANDROID_KEY_PASSWORD` | The key password you set when creating the keystore (`-keypass`) |

To generate a new keystore locally (do this once, keep the `.jks` file safe — it is git-ignored):

```sh
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

For local release builds, create `app/android/key.properties` (git-ignored, never commit it):

```properties
storeFile=/absolute/path/to/release.jks
storePassword=yourStorePassword
keyAlias=upload
keyPassword=yourKeyPassword
```

### Bumping the version / creating a new release

1. Edit `version:` in `app/pubspec.yaml`, e.g. `1.0.0+1` → `1.0.1+2`.
2. Commit and push to `main`.
3. The workflow builds the APK and publishes/updates GitHub Release `v1.0.1` automatically —
   no manual tagging needed.

### Troubleshooting

- **"Android release signing is not configured"** — one or more of the four secrets above is
  missing or empty. Add it in repo Settings → Secrets and variables → Actions.
- **Release created but tag/version didn't change** — you pushed without bumping `version:` in
  `pubspec.yaml`; the workflow will just update the existing release for that tag.
- **Gradle build fails after a Flutter/AGP upgrade** — check `app/android/gradle/wrapper/gradle-wrapper.properties`
  and `app/android/settings.gradle.kts` for version mismatches; the workflow uses whatever Gradle
  version the wrapper specifies.
- **Build succeeds locally but fails in CI on signing** — verify the base64 in
  `ANDROID_KEYSTORE_BASE64` has no line breaks (`base64 -w0`), and that alias/passwords match
  exactly what was used with `keytool`.

## Automatic in-app update system

Since this app isn't published on the Play Store, users install the APK manually. To give them a
Play-Store-like experience, the app checks a backend endpoint on startup and prompts to update if
a newer version is available — with no manual step required after a release ships.

### How a release reaches users

1. You bump `version:` in `pubspec.yaml` and push to `main` (same as above).
2. The workflow builds and signs the APK, creates/updates the GitHub Release, and (new) also
   generates GitHub's auto-summarized release notes (`generate_release_notes: true`) from the
   commits/PRs since the last release.
3. A new workflow step, **"Sync version to backend"**, calls
   `POST <BACKEND_URL>/internal/update-version` with the new version, the GitHub Releases
   download URL for `app-release.apk`, `forceUpdate` (see below), and the release notes text from
   step 2 — the same text used for both the GitHub Releases page and the in-app "What's new"
   dialog.
4. The backend persists this in a single `AppVersion` document in MongoDB (source of truth —
   no redeploy needed to pick up a new version, unlike an env-var-only approach).
5. The next time the app launches, it calls `GET /api/version`, compares versions, and — if
   newer — shows the update dialog.

### Backend version storage

- `server/src/models/AppVersion.js` — a singleton Mongo document (fixed `_id: "latest"`).
- `server/src/services/appVersionService.js` — `getLatestVersion()` reads the Mongo doc, falling
  back to the `APP_LATEST_VERSION`/`APP_APK_URL`/`APP_FORCE_UPDATE`/`APP_RELEASE_NOTES` env vars
  only if no doc exists yet (e.g. a fresh database before the first CI sync has run).
  `upsertLatestVersion(...)` writes the doc.
- `GET /api/version` (public, no API key) returns `{version, apkUrl, forceUpdate, releaseNotes}`
  from the service above.
- `POST /internal/update-version` (called only by CI) writes the new version. It is protected by
  its own bearer token — **not** the app's `x-api-key` — via
  `server/src/middleware/internalAuth.js`, checked against the `INTERNAL_UPDATE_TOKEN` env var.

**Required secrets for the sync step**, alongside the four signing secrets:

| Secret | Value |
| --- | --- |
| `BACKEND_URL` | e.g. `https://dv1520.onrender.com` (no `/api` suffix, no trailing slash) |
| `INTERNAL_UPDATE_TOKEN` | A long random value — must be set identically as a Render/backend env var of the same name |

Generate a token with `openssl rand -hex 32` (or any long random string) and set it in both
places; it never ships inside the app or the APK.

### Force update vs. optional update

- `forceUpdate` is **never** set to `true` automatically by a normal push-to-main release — it
  always syncs as `false`, so shipping a routine update never locks anyone out by accident.
- To force all users onto a specific release (e.g. a critical fix), manually run the workflow via
  **Actions → Build and Release Android APK → Run workflow**, and set the `force_update` input to
  `true`. This re-runs the same pipeline (rebuild + re-sync) with `forceUpdate: true`.
- In the app, `forceUpdate: true` makes the update dialog non-dismissible — no back button, no
  tap-outside, no "Later" or "Cancel" button. The user must download and install before
  continuing. `forceUpdate: false` shows "Later" (dismiss) and, mid-download, "Cancel".

### Flutter update module (`app/lib/update/`)

| Folder | Purpose |
| --- | --- |
| `models/` | `AppVersionInfo` — parses the `/version` response; `releaseNotesLines` splits it into bullet points for display. |
| `repositories/` | `UpdateRepository` — the one network call (`GET /version`), isolated from business logic. |
| `services/` | `UpdateService` — version comparison, APK download (with cancellation support), and launching the Android installer. |
| `providers/` | Riverpod providers: `latestVersionProvider`, `updateAvailableProvider`, and `updateDownloadProvider` (drives the download/install state machine, including cancel). |
| `widgets/` | `UpdateDialog` — the Material 3 dialog shown from `RootShell` on startup (`app/lib/app.dart`). |

There's no dedicated update **screen** — the whole experience is a modal dialog shown over
whatever screen the app opened to, matching the existing UX.
