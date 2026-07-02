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

This project's release build type is not signed yet — `android/app/build.gradle.kts` currently
falls back to the debug key for local `flutter run --release` builds. Before the workflow can
build a real release, add these four **repository secrets** under
**Settings → Secrets and variables → Actions**:

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
